//go:build windows

package main

import (
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
	kernel32                 = syscall.NewLazyDLL("kernel32.dll")
	user32                   = syscall.NewLazyDLL("user32.dll")
	openProcess              = kernel32.NewProc("OpenProcess")
	waitForSingleObject      = kernel32.NewProc("WaitForSingleObject")
	closeHandle              = kernel32.NewProc("CloseHandle")
	enumWindows              = user32.NewProc("EnumWindows")
	getWindowThreadProcessId = user32.NewProc("GetWindowThreadProcessId")
	isWindowVisible          = user32.NewProc("IsWindowVisible")
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
	result, _, err := waitForSingleObject.Call(handle, 60_000)
	if result != 0 {
		return fmt.Errorf("parent app did not exit cleanly (wait result %d, %v)", result, err)
	}
	return nil
}

func visibleWindow(pid uint32) bool {
	found := false
	cb := syscall.NewCallback(func(hWnd uintptr, param uintptr) uintptr {
		var winPID uint32
		getWindowThreadProcessId.Call(hWnd, uintptr(unsafe.Pointer(&winPID)))
		shown, _, _ := isWindowVisible.Call(hWnd)
		if shown != 0 && winPID == pid {
			found = true
			return 0
		}
		return 1
	})
	enumWindows.Call(cb, 0)
	return found
}

func launchAndWait(target string) (*exec.Cmd, error) {
	proc := exec.Command(target)
	proc.Dir = filepath.Dir(target)
	if err := proc.Start(); err != nil {
		return nil, err
	}
	deadline := time.Now().Add(45 * time.Second)
	var firstVisible time.Time
	for time.Now().Before(deadline) {
		if visibleWindow(uint32(proc.Process.Pid)) {
			if firstVisible.IsZero() {
				firstVisible = time.Now()
			}
			if time.Since(firstVisible) >= 2*time.Second {
				return proc, nil
			}
		} else {
			firstVisible = time.Time{}
		}
		time.Sleep(250 * time.Millisecond)
	}
	_ = proc.Process.Kill()
	_, _ = proc.Process.Wait()
	return nil, errors.New("updated app did not show a healthy visible window within 45 seconds")
}

func installStaged(stage, target, launchName string, pid int) error {
	helper, err := os.Executable()
	if err != nil {
		return err
	}
	relative, err := filepath.Rel(target, helper)
	if err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return errors.New("updater must be copied to per-user staging before installation")
	}
	if err := waitForParentExit(pid); err != nil {
		return err
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
	hadBackup := false
	if _, err := os.Stat(previous); err == nil {
		if err := os.Rename(previous, saved); err != nil {
			return err
		}
		hadBackup = true
	}
	if err := os.Rename(target, previous); err != nil {
		if hadBackup {
			_ = os.Rename(saved, previous)
		}
		return err
	}
	if err := os.Rename(stage, target); err != nil {
		_ = os.Rename(previous, target)
		if hadBackup {
			_ = os.Rename(saved, previous)
		}
		return err
	}
	_, err = launchAndWait(filepath.Join(target, launchName))
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
			_ = os.Rename(saved, previous)
		}
		_ = os.RemoveAll(failed)
		_, _ = launchAndWait(filepath.Join(target, launchName))
		return fmt.Errorf("update failed and old app was restored: %w", err)
	}
	// Keep exactly one prior working folder after the new window appeared.
	if hadBackup {
		_ = os.RemoveAll(saved)
	}
	logUpdate("SUCCESS: new app displayed its main window; one rollback folder retained")
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
