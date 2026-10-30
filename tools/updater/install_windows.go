//go:build windows

package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

var (
	kernel32                  = syscall.NewLazyDLL("kernel32.dll")
	openProcess               = kernel32.NewProc("OpenProcess")
	waitForSingleObject       = kernel32.NewProc("WaitForSingleObject")
	closeHandle               = kernel32.NewProc("CloseHandle")
	queryFullProcessImageName = kernel32.NewProc("QueryFullProcessImageNameW")
	createMutex               = kernel32.NewProc("CreateMutexW")
	releaseMutex              = kernel32.NewProc("ReleaseMutex")
)

func waitForParentExit(pid int) error {
	handle, _, errno := openProcess.Call(0x00100000, 0, uintptr(pid)) // SYNCHRONIZE
	if handle == 0 {
		// ERROR_INVALID_PARAMETER means the process is already gone.
		if errno == syscall.Errno(87) {
			return nil
		}
		return fmt.Errorf("cannot observe parent process (error %v)", errno)
	}
	defer closeHandle.Call(handle)
	deadline := time.Now().Add(60 * time.Second)
	for time.Now().Before(deadline) {
		if cancelled() {
			return errors.New("startup update cancelled")
		}
		result, _, err := waitForSingleObject.Call(handle, 100)
		if result == 0 {
			return nil
		}
		if result != 258 {
			return fmt.Errorf("cannot observe parent exit: %v", err)
		}
	}
	return errors.New("parent app did not exit within startup deadline")
}

func launchAndWait(target, version string, rollback bool) (*exec.Cmd, error) {
	random := make([]byte, 32)
	if _, err := rand.Read(random); err != nil {
		return nil, err
	}
	nonce := hex.EncodeToString(random)
	proc := exec.Command(target)
	proc.Dir = filepath.Dir(target)
	proc.Env = updateEnvironment(options.ReadyFile, nonce, version)
	if rollback {
		proc.Env = append(proc.Env, "BUDGETISM_UPDATE_ROLLBACK=1")
	}
	if err := proc.Start(); err != nil {
		return nil, err
	}
	done := make(chan error, 1)
	go func() { done <- proc.Wait() }()
	deadline := time.NewTimer(45 * time.Second)
	defer deadline.Stop()
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			return nil, errors.New("updated app exited before readiness")
		case <-deadline.C:
			_ = proc.Process.Kill()
			<-done
			return nil, errors.New("updated app did not acknowledge expected version and startup readiness")
		case <-ticker.C:
			data, err := os.ReadFile(options.ReadyFile)
			if err == nil && validateReady(data, version, nonce, proc.Process.Pid) {
				select {
				case <-done:
					return nil, errors.New("updated app exited during readiness")
				case <-time.After(2 * time.Second):
				}
				return proc, nil
			}
		}
	}
}
func updateEnvironment(ready, nonce, version string) []string {
	env := []string{}
	for _, v := range os.Environ() {
		key := strings.ToUpper(strings.SplitN(v, "=", 2)[0])
		if !strings.HasPrefix(key, "BUDGETISM_UPDATE_") {
			env = append(env, v)
		}
	}
	env = append(env, "BUDGETISM_UPDATE_SKIP_ONCE=1")
	if ready != "" {
		env = append(env, "BUDGETISM_UPDATE_READY_PATH="+ready, "BUDGETISM_UPDATE_READY_NONCE="+nonce, "BUDGETISM_UPDATE_VERSION="+version)
	}
	return env
}
func launchRollback(target string) error {
	data, err := os.ReadFile(filepath.Join(filepath.Dir(target), "app-release.json"))
	if err != nil {
		return err
	}
	var marker releaseMarker
	if err = json.Unmarshal(data, &marker); err != nil {
		return err
	}
	if err = os.Remove(options.ReadyFile); err != nil && !os.IsNotExist(err) {
		return err
	}
	_, err = launchAndWait(target, marker.Version, true)
	return err
}
func processPath(pid uint32) (string, error) {
	h, _, err := openProcess.Call(0x1000, 0, uintptr(pid))
	if h == 0 {
		return "", err
	}
	defer closeHandle.Call(h)
	buf := make([]uint16, 32768)
	n := uint32(len(buf))
	ok, _, err := queryFullProcessImageName.Call(h, 0, uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&n)))
	if ok == 0 {
		return "", err
	}
	return syscall.UTF16ToString(buf[:n]), nil
}
func refuseOtherInstances(target, launchName string, exclude int) error {
	snapshot, err := syscall.CreateToolhelp32Snapshot(syscall.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return err
	}
	defer syscall.CloseHandle(snapshot)
	var entry syscall.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))
	err = syscall.Process32First(snapshot, &entry)
	for err == nil {
		if int(entry.ProcessID) != exclude && entry.ProcessID != 0 && int(entry.ProcessID) != os.Getpid() {
			path, e := processPath(entry.ProcessID)
			if e == nil && strings.EqualFold(filepath.Clean(filepath.Dir(path)), filepath.Clean(target)) {
				return errors.New("another application process is running from this installation")
			}
			if e != nil && strings.EqualFold(syscall.UTF16ToString(entry.ExeFile[:]), launchName) {
				return errors.New("cannot establish whether another application instance is using this installation")
			}
		}
		err = syscall.Process32Next(snapshot, &entry)
	}
	if err != syscall.ERROR_NO_MORE_FILES {
		return err
	}
	return nil
}
func lockInstallation(target string) (func(), error) {
	sum := sha256.Sum256([]byte(strings.ToLower(filepath.Clean(target))))
	name, _ := syscall.UTF16PtrFromString("Global\\Budgetism.Update." + hex.EncodeToString(sum[:]))
	h, _, err := createMutex.Call(0, 1, uintptr(unsafe.Pointer(name)))
	if h == 0 {
		return nil, fmt.Errorf("cannot lock installation: %v", err)
	}
	if err == syscall.Errno(183) {
		closeHandle.Call(h)
		return nil, errors.New("another updater already owns this installation")
	}
	return func() { releaseMutex.Call(h); closeHandle.Call(h) }, nil
}
func installStaged(stage, target, launchName string, pid int, version string) (resultErr error) {
	unlock, err := lockInstallation(target)
	if err != nil {
		return err
	}
	defer unlock()
	for p := target; ; p = filepath.Dir(p) {
		st, e := os.Lstat(p)
		if e != nil {
			return e
		}
		if st.Mode()&os.ModeSymlink != 0 {
			return errors.New("linked install path refused")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	parentPath, err := processPath(uint32(pid))
	if err != nil || !strings.EqualFold(filepath.Clean(parentPath), filepath.Join(target, launchName)) {
		return errors.New("parent is not the installed application")
	}
	if err := refuseOtherInstances(target, launchName, pid); err != nil {
		return err
	}

	helper, err := os.Executable()
	if err != nil {
		return err
	}
	relative, err := filepath.Rel(target, helper)
	if err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return errors.New("updater must be copied to per-user staging before installation")
	}
	base := filepath.Base(target)
	previous := filepath.Join(filepath.Dir(target), "."+base+".previous")
	saved := previous + ".saved"
	failed := previous + ".failed"
	if _, err := os.Stat(saved); err == nil {
		return errors.New("unresolved previous update found; manual recovery required")
	}
	if _, err := os.Stat(failed); err == nil {
		return errors.New("unresolved failed-update folder found; manual recovery required")
	}
	if !stringsEqualFold(launchName, "Budgetism.exe") {
		if err := os.Rename(filepath.Join(stage, "Budgetism.exe"), filepath.Join(stage, launchName)); err != nil {
			return err
		}
	}
	if _, err := os.Stat(filepath.Join(target, launchName)); err != nil {
		return errors.New("current application executable not found; refusing replacement")
	}
	if err := validateInstalledVersion(target, version); err != nil {
		return err
	}
	if cancelled() {
		return errors.New("startup update cancelled")
	}
	if err := writeStatus(options.AdmissionFile, options.RequestID, version, "admitted", ""); err != nil {
		return err
	}
	if err := waitForParentExit(pid); err != nil {
		return err
	}
	candidateStarted := false
	// Once admission has closed the bootstrap, recover the old UI on a safe
	// pre-candidate filesystem failure. Never compete with another live instance,
	// launch an unknown folder, or hide an unresolved restoration failure.
	defer func() {
		if resultErr == nil || candidateStarted {
			return
		}
		if validateInstalledVersion(target, version) != nil {
			return
		}
		if refuseOtherInstances(target, launchName, 0) != nil {
			return
		}
		originalError := resultErr
		if recoveryErr := launchRollback(filepath.Join(target, launchName)); recoveryErr != nil {
			resultErr = fmt.Errorf("startup update failed and old app could not acknowledge recovery: %v; %w", originalError, recoveryErr)
		} else {
			resultErr = fmt.Errorf("%w: %v", errRolledBack, originalError)
		}
	}()
	if err := refuseOtherInstances(target, launchName, 0); err != nil {
		return err
	}
	if cancelled() {
		return errors.New("startup update cancelled")
	}
	hadBackup := false
	if _, err := os.Stat(previous); err == nil {
		if err := os.Rename(previous, saved); err != nil {
			return err
		}
		hadBackup = true
	}
	if err := os.Rename(target, previous); err != nil {
		if hadBackup {
			if restoreErr := os.Rename(saved, previous); restoreErr != nil {
				return fmt.Errorf("update failed; previous backup restore requires manual recovery: %w", restoreErr)
			}
		}
		return err
	}
	if err := os.Rename(stage, target); err != nil {
		if restoreErr := os.Rename(previous, target); restoreErr != nil {
			return fmt.Errorf("stage swap failed; installation restore requires manual recovery: %w", restoreErr)
		}
		if hadBackup {
			if restoreErr := os.Rename(saved, previous); restoreErr != nil {
				return fmt.Errorf("update failed; previous backup restore requires manual recovery: %w", restoreErr)
			}
		}
		return err
	}
	candidateStarted = true
	_, err = launchAndWait(filepath.Join(target, launchName), version, false)
	if err != nil {
		// Preserve the broken installation if cleanup fails, rather than touching
		// arbitrary data. The original app folder is restored first.
		if moveErr := os.Rename(target, failed); moveErr != nil {
			return fmt.Errorf("health check failed: %v; cannot quarantine new folder: %v", err, moveErr)
		}
		if moveErr := os.Rename(previous, target); moveErr != nil {
			return fmt.Errorf("health check failed: %v; cannot restore prior installation: %v", err, moveErr)
		}
		if hadBackup {
			if restoreErr := os.Rename(saved, previous); restoreErr != nil {
				return fmt.Errorf("update failed; previous backup restore requires manual recovery: %w", restoreErr)
			}
		}
		_ = os.RemoveAll(failed)
		if launchErr := launchRollback(filepath.Join(target, launchName)); launchErr != nil {
			return fmt.Errorf("old installation restored but relaunch failed: %w", launchErr)
		}
		return fmt.Errorf("%w: %v", errRolledBack, err)
	}
	// Keep one prior working folder after exact version readiness succeeds.
	if hadBackup {
		if cleanupErr := os.RemoveAll(saved); cleanupErr != nil {
			return fmt.Errorf("new app is ready but older backup cleanup requires manual recovery: %w", cleanupErr)
		}
	}
	logUpdate("SUCCESS: new app acknowledged exact version and startup readiness; one rollback folder retained")
	return nil
}

func stringsEqualFold(a, b string) bool {
	return len(a) == len(b) && syscallStringFold(a, b)
}

func syscallStringFold(a, b string) bool {
	// Executable filenames are case insensitive on regular Windows volumes.
	for i := range a {
		x, y := a[i], b[i]
		if x >= 'A' && x <= 'Z' {
			x += 'a' - 'A'
		}
		if y >= 'A' && y <= 'Z' {
			y += 'a' - 'A'
		}
		if x != y {
			return false
		}
	}
	return true
}
