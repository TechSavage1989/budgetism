package main

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fakePE(machine uint16) []byte {
	b := make([]byte, 512)
	copy(b[:2], "MZ")
	binary.LittleEndian.PutUint32(b[0x3c:0x40], 128)
	copy(b[128:132], "PE\x00\x00")
	binary.LittleEndian.PutUint16(b[132:134], machine)
	return b
}

func samplePackage(t *testing.T, files map[string][]byte) (string, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "release.zip")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	for name, content := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write(content); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(data)
	return path, hex.EncodeToString(hash[:])
}

func normalFiles() map[string][]byte {
	return map[string][]byte{
		"Budgetism/Budgetism.exe":                         fakePE(0x8664),
		"Budgetism/app-release.json":                      []byte(`{"appId":"TechSavage1989.Budgetism","version":"0.1.0-dev.1","platform":"windows-x64","executable":"Budgetism.exe"}`),
		"Budgetism/data/flutter_assets/AssetManifest.bin": []byte("unit-test-fixture"),
		"Budgetism/data/":                                 []byte{},
	}
}

func TestVerifyGoodArchive(t *testing.T) {
	files := normalFiles()
	delete(files, "Budgetism/data/")
	path, hash := samplePackage(t, files)
	stage, err := stageVerifiedArchive(path, hash, "0.1.0-dev.1", t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(stage)
	if _, err := os.Stat(filepath.Join(stage, "Budgetism.exe")); err != nil {
		t.Fatal(err)
	}
}

func TestRejectWrongHash(t *testing.T) {
	path, _ := samplePackage(t, normalFiles())
	if _, err := stageVerifiedArchive(path, strings.Repeat("0", 64), "0.1.0-dev.1", t.TempDir()); err == nil {
		t.Fatal("wrong digest must fail")
	}
}

func TestRejectWrongVersion(t *testing.T) {
	path, hash := samplePackage(t, normalFiles())
	if _, err := stageVerifiedArchive(path, hash, "9.9.9", t.TempDir()); err == nil {
		t.Fatal("version mismatch must fail")
	}
}

func TestRejectTraversal(t *testing.T) {
	files := normalFiles()
	files["Budgetism/../outside.txt"] = []byte("unsafe")
	path, hash := samplePackage(t, files)
	if _, err := stageVerifiedArchive(path, hash, "0.1.0-dev.1", t.TempDir()); err == nil {
		t.Fatal("traversal must fail")
	}
}

func TestRejectAdditionalExecutable(t *testing.T) {
	files := normalFiles()
	files["Budgetism/payload.exe"] = fakePE(0x8664)
	path, hash := samplePackage(t, files)
	if _, err := stageVerifiedArchive(path, hash, "0.1.0-dev.1", t.TempDir()); err == nil {
		t.Fatal("unknown executable must fail")
	}
}

func TestRejectWrongArchitecture(t *testing.T) {
	files := normalFiles()
	files["Budgetism/Budgetism.exe"] = fakePE(0x14c)
	path, hash := samplePackage(t, files)
	if _, err := stageVerifiedArchive(path, hash, "0.1.0-dev.1", t.TempDir()); err == nil {
		t.Fatal("32 bit Windows binary must fail")
	}
}

func TestRejectBadCustomLaunchName(t *testing.T) {
	for _, name := range []string{"../other.exe", "x/../other.exe", "C:\\test.exe", "", "other.bat", ".exe"} {
		if err := validatedLaunchName(name); err == nil {
			t.Errorf("accepted %q", name)
		}
	}
	if err := validatedLaunchName("My Budgetism.exe"); err != nil {
		t.Fatal(err)
	}
}
