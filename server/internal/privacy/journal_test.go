package privacy

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestJournalRejectsDuplicateAndCaseAliasFields(t *testing.T) {
	for _, variant := range []string{"duplicate", "case_alias"} {
		t.Run(variant, func(t *testing.T) {
			dir := filepath.Join(t.TempDir(), "journal")
			intent, err := WriteIntent(dir, "account_a")
			if err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(dir, "erasure-"+intent.ErasureID+".json")
			body := `{"schema_version":"1.0.0","account_id":"wrong","account_id":"account_a","erasure_id":"` + intent.ErasureID + `"}`
			if variant == "case_alias" {
				body = `{"SCHEMA_VERSION":"1.0.0","ACCOUNT_ID":"account_a","ERASURE_ID":"` + intent.ErasureID + `"}`
			}
			if err := os.WriteFile(path, []byte(body), 0600); err != nil {
				t.Fatal(err)
			}
			if _, err := ReadIntents(dir, 10); err == nil {
				t.Fatal("ambiguous intent accepted")
			}
		})
	}
}

func TestJournalParentSyncFailureRefusesNewAndReusedIntent(t *testing.T) {
	base := t.TempDir()
	parent := filepath.Join(base, "fresh-parent")
	dir := filepath.Join(parent, "journal")
	sentinel := errors.New("injected parent fsync failure")
	syncFailure := func(path string) error {
		if path == parent {
			return sentinel
		}
		return syncDirectory(path)
	}
	for attempt := 0; attempt < 2; attempt++ {
		if _, err := writeIntent(dir, "account_a", syncFailure); !errors.Is(err, sentinel) {
			t.Fatalf("parent durability failure accepted on attempt%d: %v", attempt, err)
		}
	}
	if _, err := WriteIntent(dir, "account_a"); err != nil {
		t.Fatal(err)
	}
}

func TestJournalNestedDirectoryDurabilityTrace(t *testing.T) {
	base := t.TempDir()
	dir := filepath.Join(base, "fresh-parent", "journal")
	if _, err := WriteIntent(dir, "account_a"); err != nil {
		t.Fatal(err)
	}
	t.Log("TRACE_JOURNAL_BASE=" + base)
}

func TestJournalIsDurablePrivateIdempotentAndStrict(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "erasures")
	first, err := WriteIntent(dir, "account_a")
	if err != nil {
		t.Fatal(err)
	}
	second, err := WriteIntent(dir, "account_a")
	if err != nil || first != second {
		t.Fatalf("retry: %v", err)
	}
	entries, err := ReadIntents(dir, 10)
	if err != nil || len(entries) != 1 || entries[0] != first {
		t.Fatalf("read: %v %v", entries, err)
	}
	files, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, files[0].Name())
	info, _ := os.Stat(path)
	if info.Mode().Perm() != 0600 {
		t.Fatal("journal not private")
	}
	if _, err = WriteIntent(dir, "raw account dialogue"); err == nil {
		t.Fatal("invalid identifier accepted")
	}
	if err = os.WriteFile(path, []byte(`{"schema_version":"1.0.0","account_id":"account_a","dialogue":"raw"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = ReadIntents(dir, 10); err == nil {
		t.Fatal("unknown journal fields accepted")
	}
}

func TestJournalRejectsSymlinksPermissionsAndOverflow(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "erasures")
	if _, err := WriteIntent(dir, "a"); err != nil {
		t.Fatal(err)
	}
	if _, err := WriteIntent(dir, "b"); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadIntents(dir, 1); err == nil {
		t.Fatal("unbounded journal loaded")
	}
	files, _ := os.ReadDir(dir)
	path := filepath.Join(dir, files[0].Name())
	if err := os.Chmod(path, 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadIntents(dir, 10); err == nil {
		t.Fatal("world-readable journal accepted")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(dir, files[1].Name()), path); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadIntents(dir, 10); err == nil {
		t.Fatal("journal symlink followed")
	}
}
