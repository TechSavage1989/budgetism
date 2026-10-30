package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadinessIdentity(t *testing.T) {
	good := []byte(`{"version":"0.1.0-dev.28","nonce":"abc","pid":123}`)
	if !validateReady(good, "0.1.0-dev.28", "abc", 123) {
		t.Fatal("valid readiness rejected")
	}
	for _, test := range []struct {
		v, n string
		p    int
	}{{"0.1.0-dev.27", "abc", 123}, {"0.1.0-dev.28", "other", 123}, {"0.1.0-dev.28", "abc", 456}} {
		if validateReady(good, test.v, test.n, test.p) {
			t.Fatal("mismatched readiness accepted")
		}
	}
	if validateReady([]byte(`{broken`), "", "", 0) {
		t.Fatal("invalid json accepted")
	}
}
func TestUpgradeOrdering(t *testing.T) {
	for _, v := range []struct {
		n, c string
		want bool
	}{{"0.1.0-dev.28", "0.1.0-dev.27", true}, {"0.1.0-dev.27", "0.1.0-dev.27", false}, {"0.1.0-dev.9", "0.1.0-dev.27", false}, {"0.1.0", "0.1.0-dev.27", true}, {"0.1.0-dev.28", "0.1.0", false}, {"0.2.0-dev.1", "0.1.0", true}, {"bad", "0.1.0", false}, {"0.1.0-rc.1", "0.1.0-dev.27", false}} {
		if newerVersion(v.n, v.c) != v.want {
			t.Fatalf("ordering %s %s", v.n, v.c)
		}
	}
}
func TestAttemptPathsAndReplay(t *testing.T) {
	id := "11111111-2222-4333-8444-555555555555"
	dir := filepath.Join(t.TempDir(), id)
	if err := os.Mkdir(dir, 0700); err != nil {
		t.Fatal(err)
	}
	o := installOptions{RequestID: id, AdmissionFile: filepath.Join(dir, "admitted.json"), ResultFile: filepath.Join(dir, "result.json"), ReadyFile: filepath.Join(dir, "ready.json"), CancelFile: filepath.Join(dir, "cancel.json")}
	if err := validateOptions(o); err != nil {
		t.Fatal(err)
	}
	if err := writeStatus(o.AdmissionFile, id, "0.1.0-dev.28", "admitted", ""); err != nil {
		t.Fatal(err)
	}
	if validateOptions(o) == nil {
		t.Fatal("replayed attempt accepted")
	}
	o.RequestID = "not-a-uuid"
	if validateOptions(o) == nil {
		t.Fatal("invalid attempt accepted")
	}
}
func TestRequiredUpdateProtocol(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "app-release.json")
	for _, s := range []string{`{}`, `{"updateProtocol":2,"clientApiContract":1}`, `{"updateProtocol":1,"clientApiContract":2}`, `{"updateProtocol":"1","clientApiContract":1}`} {
		os.WriteFile(p, []byte(s), 0600)
		if validateProtocol(dir, 1, 1) == nil {
			t.Fatal("incompatible protocol accepted")
		}
	}
	os.WriteFile(p, []byte(`{"updateProtocol":1,"clientApiContract":1}`), 0600)
	if err := validateProtocol(dir, 1, 1); err != nil {
		t.Fatal(err)
	}
}
