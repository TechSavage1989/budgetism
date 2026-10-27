package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

func main() {
	archive := flag.String("archive", "", "path to verified portable ZIP")
	sha := flag.String("sha256", "", "expected GitHub release asset digest")
	version := flag.String("version", "", "expected release version without v prefix")
	target := flag.String("install-dir", "", "current Budgetism folder")
	exe := flag.String("launch-name", "Budgetism.exe", "actual stable launch filename")
	parentPID := flag.Int("parent-pid", 0, "current application process ID")
	verify := flag.Bool("verify-only", false, "validate archive and identity without installing")
	flag.Parse()
	if err := run(*archive, *sha, *version, *target, *exe, *parentPID, *verify); err != nil {
		logUpdate("ERROR: " + err.Error())
		fmt.Fprintln(os.Stderr, "Budgetism update error:", err)
		os.Exit(1)
	}
}

func run(archive, digest, version, target, exe string, pid int, verifyOnly bool) error {
	if archive == "" || digest == "" || version == "" {
		return errors.New("archive, sha256 and version are required")
	}
	if err := validatedLaunchName(exe); err != nil {
		return err
	}
	var parent string
	if verifyOnly {
		parent = os.TempDir()
	} else {
		if target == "" || pid <= 0 {
			return errors.New("install-dir and parent-pid required for installation")
		}
		absolute, err := filepath.Abs(target)
		if err != nil {
			return err
		}
		if absolute == filepath.Dir(absolute) {
			return errors.New("cannot replace a volume root")
		}
		info, err := os.Stat(absolute)
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return errors.New("install directory is not a folder")
		}
		target = absolute
		parent = filepath.Dir(target)
	}
	stage, err := stageVerifiedArchive(archive, digest, version, parent)
	if err != nil {
		return err
	}
	if verifyOnly {
		defer os.RemoveAll(stage)
		fmt.Printf("Verified Budgetism %s package identity, archive integrity and Windows x64 executable.\n", version)
		return nil
	}
	return installStaged(stage, target, exe, pid)
}

// Logging is entirely local. No tokens, passwords or financial data are logged.
func logUpdate(message string) {
	root := os.Getenv("LOCALAPPDATA")
	if root == "" {
		root, _ = os.UserCacheDir()
	}
	if root == "" {
		return
	}
	dir := filepath.Join(root, "Budgetism", "logs")
	if err := os.MkdirAll(dir, 0700); err != nil {
		return
	}
	f, err := os.OpenFile(filepath.Join(dir, "updater.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s %s\n", time.Now().Format(time.RFC3339), message)
}
