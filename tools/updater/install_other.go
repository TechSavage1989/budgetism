//go:build !windows

package main

import "errors"

func installStaged(stage, target, launchName string, pid int, version string) error {
	return errors.New("installation is available only on Windows; verify-only works on this host")
}
