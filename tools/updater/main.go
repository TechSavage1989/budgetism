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
	flag.StringVar(&options.RequestID, "request-id", "", "unique startup attempt")
	flag.StringVar(&options.AdmissionFile, "admission-file", "", "startup admission receipt")
	flag.StringVar(&options.ResultFile, "result-file", "", "startup result receipt")
	flag.StringVar(&options.CancelFile, "cancel-file", "", "startup cancellation receipt")
	flag.StringVar(&options.ReadyFile, "ready-file", "", "new app readiness receipt")
	flag.IntVar(&options.Protocol, "require-update-protocol", 0, "required update protocol")
	flag.IntVar(&options.APIContract, "require-client-api-contract", 0, "required client API contract")
	flag.Parse()
	if options.ReadyFile == "" && options.AdmissionFile != "" {
		options.ReadyFile = filepath.Join(filepath.Dir(options.AdmissionFile), "ready.json")
	}
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
	if err := validateProtocol(stage, options.Protocol, options.APIContract); err != nil {
		os.RemoveAll(stage)
		return err
	}
	if verifyOnly {
		defer os.RemoveAll(stage)
		fmt.Printf("Verified Budgetism %s package identity, archive integrity and Windows x64 executable.\n", version)
		return nil
	}
	defer os.RemoveAll(stage)
	if options.Protocol != 1 || options.APIContract != 1 {
		return errors.New("installation requires update protocol and API contract 1")
	}
	if err := validateOptions(options); err != nil {
		return err
	}
	err = installStaged(stage, target, exe, pid, version)
	status, message := "installed", "Update installed and ready"
	if err != nil {
		status, message = "failed", "Update did not complete; inspect local updater log before retrying"
	}
	if errors.Is(err, errRolledBack) {
		status, message = "rolledBack", "Update failed; prior application restored and startup readiness verified"
	}
	if receiptErr := writeStatus(options.ResultFile, options.RequestID, version, status, message); receiptErr != nil && err == nil {
		return receiptErr
	}
	return err
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
