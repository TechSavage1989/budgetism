package main

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const appIdentity = "TechSavage1989.Budgetism"
const archiveRoot = "Budgetism/"
const maxArchiveBytes int64 = 700 * 1024 * 1024
const maxUnpackedBytes int64 = 1_400 * 1024 * 1024
const maxFileBytes int64 = 500 * 1024 * 1024
const maxArchiveEntries = 4000

type releaseMarker struct {
	AppID      string `json:"appId"`
	Version    string `json:"version"`
	Platform   string `json:"platform"`
	Executable string `json:"executable"`
}

func validateDigest(path, expected string) error {
	if len(expected) != 64 {
		return errors.New("expected SHA-256 must contain exactly 64 hex characters")
	}
	raw, err := hex.DecodeString(expected)
	if err != nil || len(raw) != sha256.Size {
		return errors.New("invalid SHA-256 hex")
	}
	stat, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !stat.Mode().IsRegular() || stat.Size() <= 0 || stat.Size() > maxArchiveBytes {
		return errors.New("archive size outside allowed bounds")
	}
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	h := sha256.New()
	if _, err = io.Copy(h, io.LimitReader(f, maxArchiveBytes+1)); err != nil {
		return err
	}
	if !equalBytes(h.Sum(nil), raw) {
		return errors.New("release SHA-256 mismatch")
	}
	return nil
}

func equalBytes(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var diff byte
	for i := range a {
		diff |= a[i] ^ b[i]
	}
	return diff == 0
}

func safeZipEntry(f *zip.File) (string, error) {
	name := f.Name
	if len(name) > 320 || strings.ContainsAny(name, "\\\x00") || strings.HasPrefix(name, "/") ||
		!strings.HasPrefix(name, archiveRoot) || strings.Contains(name, ":") {
		return "", fmt.Errorf("unsafe archive path %q", name)
	}
	relative := strings.TrimPrefix(name, archiveRoot)
	if f.FileInfo().IsDir() && strings.HasSuffix(relative, "/") {
		relative = strings.TrimSuffix(relative, "/")
	}
	if relative == "" && f.FileInfo().IsDir() {
		return "", nil
	}
	if relative == "" {
		return "", errors.New("file at archive root instead of within folder")
	}
	if filepath.IsAbs(relative) {
		return "", errors.New("absolute path rejected")
	}
	for _, part := range strings.Split(relative, "/") {
		base := strings.ToUpper(strings.SplitN(part, ".", 2)[0])
		reserved := base == "CON" || base == "PRN" || base == "AUX" || base == "NUL" || len(base) == 4 && (strings.HasPrefix(base, "COM") || strings.HasPrefix(base, "LPT")) && base[3] >= '1' && base[3] <= '9'
		if reserved || strings.TrimRight(part, " .") != part || strings.ContainsAny(part, `<>"|?*`) {
			return "", errors.New("ambiguous Windows archive component")
		}
		if part == ".." || part == "." || part == "" {
			return "", fmt.Errorf("traversal or empty component %q", name)
		}
	}
	if f.Mode()&os.ModeSymlink != 0 || f.Mode()&os.ModeType != 0 && !f.FileInfo().IsDir() {
		return "", errors.New("nonregular archive entry rejected")
	}
	if f.UncompressedSize64 > uint64(maxFileBytes) {
		return "", errors.New("file too large")
	}
	if f.UncompressedSize64 > 10*1024*1024 && f.CompressedSize64 < f.UncompressedSize64/500 {
		return "", errors.New("suspicious compression ratio")
	}
	normalized := strings.ToLower(relative)
	if strings.HasSuffix(normalized, ".exe") && normalized != "budgetism.exe" && normalized != "budgetism-updater.exe" {
		return "", fmt.Errorf("unexpected executable %q", relative)
	}
	if strings.HasSuffix(normalized, ".ps1") || strings.HasSuffix(normalized, ".bat") ||
		strings.HasSuffix(normalized, ".cmd") || strings.HasSuffix(normalized, ".vbs") ||
		strings.HasSuffix(normalized, ".msi") || strings.HasSuffix(normalized, ".lnk") {
		return "", fmt.Errorf("unexpected installer/script file %q", relative)
	}
	return filepath.FromSlash(relative), nil
}

func stageVerifiedArchive(zipPath, digest, expectedVersion, parent string) (string, error) {
	// Verify and extract the same private snapshot, never reopen the caller's mutable path.
	snapshot, err := os.CreateTemp("", "budgetism-archive-*.zip")
	if err != nil {
		return "", err
	}
	defer os.Remove(snapshot.Name())
	source, err := os.Open(zipPath)
	if err != nil {
		snapshot.Close()
		return "", err
	}
	info, statErr := source.Stat()
	if statErr != nil || !info.Mode().IsRegular() || info.Size() <= 0 || info.Size() > maxArchiveBytes {
		source.Close()
		snapshot.Close()
		return "", errors.New("archive must be a bounded regular file")
	}
	n, copyErr := io.Copy(snapshot, io.LimitReader(source, maxArchiveBytes+1))
	source.Close()
	closeErr := snapshot.Close()
	if copyErr != nil {
		return "", copyErr
	}
	if closeErr != nil {
		return "", closeErr
	}
	if n > maxArchiveBytes {
		return "", errors.New("archive too large")
	}
	zipPath = snapshot.Name()
	if err := validateDigest(zipPath, digest); err != nil {
		return "", err
	}
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return "", err
	}
	defer zr.Close()
	if len(zr.File) == 0 || len(zr.File) > maxArchiveEntries {
		return "", errors.New("unexpected ZIP entry count")
	}
	var total int64
	foundExe, foundMarker := false, false
	seen := map[string]bool{}
	for _, f := range zr.File {
		rel, err := safeZipEntry(f)
		if err != nil {
			return "", err
		}
		if rel == "" {
			continue
		}
		key := strings.ToLower(rel)
		if seen[key] {
			return "", fmt.Errorf("duplicate case-insensitive entry %q", rel)
		}
		seen[key] = true
		if rel == "Budgetism.exe" {
			foundExe = true
		}
		if rel == "app-release.json" {
			foundMarker = true
		}
		total += int64(f.UncompressedSize64)
		if total > maxUnpackedBytes {
			return "", errors.New("archive unpacked size too large")
		}
	}
	if !foundExe || !foundMarker {
		return "", errors.New("missing Budgetism.exe or app-release.json")
	}
	stage, err := os.MkdirTemp(parent, ".budgetism-stage-")
	if err != nil {
		return "", err
	}
	okay := false
	defer func() {
		if !okay {
			_ = os.RemoveAll(stage)
		}
	}()
	for _, f := range zr.File {
		rel, err := safeZipEntry(f)
		if err != nil {
			return "", err
		}
		if rel == "" {
			continue
		}
		target := filepath.Join(stage, rel)
		// The preflight rejects traversal and links; this check is defense-in-depth.
		r, err := filepath.Rel(stage, target)
		if err != nil || r == ".." || strings.HasPrefix(r, ".."+string(filepath.Separator)) {
			return "", errors.New("path escaped staging directory")
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0700); err != nil {
				return "", err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0700); err != nil {
			return "", err
		}
		src, err := f.Open()
		if err != nil {
			return "", err
		}
		dst, err := os.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			src.Close()
			return "", err
		}
		n, copyErr := io.Copy(dst, io.LimitReader(src, maxFileBytes+1))
		syncErr := dst.Sync()
		closeErr := dst.Close()
		srcErr := src.Close()
		if copyErr != nil {
			return "", copyErr
		}
		if syncErr != nil {
			return "", syncErr
		}
		if closeErr != nil {
			return "", closeErr
		}
		if srcErr != nil {
			return "", srcErr
		}
		if n != int64(f.UncompressedSize64) {
			return "", errors.New("ZIP file size mismatch")
		}
	}
	meta, err := os.ReadFile(filepath.Join(stage, "app-release.json"))
	if err != nil {
		return "", err
	}
	var marker releaseMarker
	if err := json.Unmarshal(meta, &marker); err != nil {
		return "", fmt.Errorf("invalid release identity manifest: %w", err)
	}
	if marker.AppID != appIdentity || marker.Version != expectedVersion ||
		marker.Platform != "windows-x64" || marker.Executable != "Budgetism.exe" {
		return "", errors.New("release package identity, platform or version mismatch")
	}
	if err := checkPE(filepath.Join(stage, "Budgetism.exe")); err != nil {
		return "", err
	}
	okay = true
	return stage, nil
}

func checkPE(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	header := make([]byte, 64)
	if _, err := io.ReadFull(f, header); err != nil {
		return fmt.Errorf("invalid PE header: %w", err)
	}
	if string(header[:2]) != "MZ" {
		return errors.New("expected Windows executable MZ header")
	}
	offset := int64(binary.LittleEndian.Uint32(header[0x3c:0x40]))
	if offset < 64 || offset > 1024*1024 {
		return errors.New("invalid PE offset")
	}
	sig := make([]byte, 6)
	if _, err := f.ReadAt(sig, offset); err != nil {
		return err
	}
	if string(sig[:4]) != "PE\x00\x00" {
		return errors.New("invalid PE signature")
	}
	if binary.LittleEndian.Uint16(sig[4:]) != 0x8664 {
		return errors.New("executable is not Windows x64")
	}
	return nil
}

func validatedLaunchName(name string) error {
	if name == "" || len(name) > 140 || strings.TrimSpace(name) != name ||
		filepath.Base(name) != name || strings.ContainsAny(name, "/\\:\x00") ||
		!strings.EqualFold(filepath.Ext(name), ".exe") || strings.HasPrefix(name, ".") {
		return errors.New("invalid launch executable name")
	}
	return nil
}
