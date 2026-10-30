//go:build windows

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNativeInstallMutex(t *testing.T) {
	dir := t.TempDir()
	unlock, err := lockInstallation(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer unlock()
	second, err := lockInstallation(dir)
	if err == nil {
		second()
		t.Fatal("duplicate installation lock admitted")
	}
}
func TestNativeProcessIdentity(t *testing.T) {
	path, err := processPath(uint32(os.Getpid()))
	if err != nil {
		t.Fatal(err)
	}
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	if !stringsEqualFold(filepath.Clean(path), filepath.Clean(exe)) {
		t.Fatal("process identity mismatch")
	}
}
func TestNativeCancelledParentWait(t *testing.T) {
	old := options
	defer func() { options = old }()
	options.CancelFile = filepath.Join(t.TempDir(), "cancel.json")
	os.WriteFile(options.CancelFile, []byte("cancel"), 0600)
	if waitForParentExit(os.Getpid()) == nil {
		t.Fatal("cancelled parent wait succeeded")
	}
}
