package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
)

type installOptions struct {
	RequestID, AdmissionFile, ResultFile, ReadyFile, CancelFile string
	Protocol, APIContract                                       int
}

var options installOptions

func validateOptions(o installOptions) error {
	if !regexp.MustCompile(`^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$`).MatchString(o.RequestID) {
		return errors.New("invalid update request identity")
	}
	dir := filepath.Dir(o.AdmissionFile)
	if !filepath.IsAbs(dir) || filepath.Base(dir) != o.RequestID || filepath.Dir(o.ResultFile) != dir || filepath.Dir(o.ReadyFile) != dir || filepath.Dir(o.CancelFile) != dir || filepath.Base(o.CancelFile) != "cancel.json" || filepath.Base(o.AdmissionFile) != "admitted.json" || filepath.Base(o.ResultFile) != "result.json" || filepath.Base(o.ReadyFile) != "ready.json" {
		return errors.New("invalid attempt file paths")
	}
	for p := dir; ; p = filepath.Dir(p) {
		st, err := os.Lstat(p)
		if err != nil {
			return err
		}
		if st.Mode()&os.ModeSymlink != 0 {
			return errors.New("linked attempt path refused")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	for _, p := range []string{o.AdmissionFile, o.ResultFile, o.ReadyFile, o.CancelFile} {
		if _, err := os.Lstat(p); !os.IsNotExist(err) {
			return errors.New("attempt must use fresh files")
		}
	}
	return nil
}
func writeStatus(path, request, version, status, message string) error {
	data, err := json.Marshal(map[string]string{"requestId": request, "version": version, "status": status, "message": message})
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".update-status-")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}
func validateReady(data []byte, version, nonce string, pid int) bool {
	if len(data) > 4096 {
		return false
	}
	var r struct {
		Version string `json:"version"`
		Nonce   string `json:"nonce"`
		PID     int    `json:"pid"`
	}
	return json.Unmarshal(data, &r) == nil && r.Version == version && r.Nonce == nonce && r.PID == pid
}
func validateProtocol(stage string, protocol, api int) error {
	data, err := os.ReadFile(filepath.Join(stage, "app-release.json"))
	if err != nil {
		return err
	}
	var m struct {
		Protocol int `json:"updateProtocol"`
		API      int `json:"clientApiContract"`
	}
	if err = json.Unmarshal(data, &m); err != nil {
		return err
	}
	if protocol != 0 && m.Protocol != protocol || api != 0 && m.API != api {
		return errors.New("unsupported client update protocol or API contract")
	}
	return nil
}

// Budgetism's supported channel uses stable SemVer or numeric dev.N builds.
// Refuse unfamiliar pre-release grammars rather than guessing their order.
func newerVersion(next, current string) bool {
	parse := func(s string) ([5]int, bool) {
		var out [5]int
		m := regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-dev\.(0|[1-9][0-9]*))?$`).FindStringSubmatch(s)
		if m == nil {
			return out, false
		}
		for i := 1; i < 4; i++ {
			n, e := strconv.Atoi(m[i])
			if e != nil {
				return out, false
			}
			out[i-1] = n
		}
		if m[4] == "" {
			out[3] = 1
		} else {
			n, e := strconv.Atoi(m[4])
			if e != nil {
				return out, false
			}
			out[4] = n
		}
		return out, true
	}
	n, ok := parse(next)
	if !ok {
		return false
	}
	c, ok := parse(current)
	if !ok {
		return false
	}
	for i := range n {
		if n[i] != c[i] {
			return n[i] > c[i]
		}
	}
	return false
}
func validateInstalledVersion(target, version string) error {
	data, err := os.ReadFile(filepath.Join(target, "app-release.json"))
	if err != nil {
		return err
	}
	var marker releaseMarker
	if err = json.Unmarshal(data, &marker); err != nil {
		return err
	}
	if err := validateProtocol(target, 1, 1); err != nil {
		return err
	}
	if marker.AppID != appIdentity || marker.Platform != "windows-x64" || !newerVersion(version, marker.Version) {
		return errors.New("update is not a newer compatible Budgetism version")
	}
	return nil
}

func cancelled() bool { _, err := os.Lstat(options.CancelFile); return !os.IsNotExist(err) }

var errRolledBack = errors.New("update failed; old app restored and startup readiness verified")
