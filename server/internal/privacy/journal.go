package privacy

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sort"

	"psychosims.dev/server/internal/schemas"
)

// Intent is deliberately separate from database backups. It contains only the
// pseudonymous account fence and deterministic operation ID, never identities,
// tokens, key material, gameplay payloads or an asserted legal basis.
type Intent struct {
	SchemaVersion string `json:"schema_version"`
	AccountID     string `json:"account_id"`
	ErasureID     string `json:"erasure_id"`
}

func (i Intent) Validate() error {
	if i.SchemaVersion != "1.0.0" || !schemas.ValidIdentifier(i.AccountID) || i.ErasureID != erasureID(i.AccountID) {
		return errors.New("invalid erasure intent")
	}
	return nil
}
func privateDirectory(dir string) error {
	info, err := os.Lstat(dir)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode().Perm()&0077 != 0 {
		return errors.New("journal directory must be private and regular")
	}
	return nil
}
func readIntent(path string) (Intent, error) {
	var intent Intent
	info, err := os.Lstat(path)
	if err != nil {
		return intent, err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm()&0077 != 0 || info.Size() > 4096 {
		return intent, errors.New("invalid journal file")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return intent, err
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	first, err := dec.Token()
	if err != nil || first != json.Delim('{') {
		return intent, errors.New("journal record must be an object")
	}
	fields := make(map[string]string, 3)
	for dec.More() {
		token, tokenErr := dec.Token()
		if tokenErr != nil {
			return intent, tokenErr
		}
		key, ok := token.(string)
		if !ok || (key != "schema_version" && key != "account_id" && key != "erasure_id") {
			return intent, errors.New("unexpected journal field")
		}
		if _, exists := fields[key]; exists {
			return intent, errors.New("duplicate journal field")
		}
		var value string
		if err = dec.Decode(&value); err != nil {
			return intent, err
		}
		fields[key] = value
	}
	if last, err := dec.Token(); err != nil || last != json.Delim('}') || len(fields) != 3 {
		return intent, errors.New("incomplete journal record")
	}
	intent = Intent{SchemaVersion: fields["schema_version"], AccountID: fields["account_id"], ErasureID: fields["erasure_id"]}
	var extra any
	if err = dec.Decode(&extra); err != io.EOF {
		return intent, errors.New("trailing journal data")
	}
	if err = intent.Validate(); err != nil {
		return intent, err
	}
	if filepath.Base(path) != "erasure-"+intent.ErasureID+".json" {
		return intent, errors.New("journal name mismatch")
	}
	return intent, nil
}

// WriteIntent fsyncs both the record and its directory before database erasure.
// Existing records are verified and reused; they are never overwritten.
func WriteIntent(dir, account string) (Intent, error) {
	return writeIntent(dir, account, syncDirectory)
}

func writeIntent(dir, account string, syncDir func(string) error) (Intent, error) {
	intent := Intent{SchemaVersion: "1.0.0", AccountID: account, ErasureID: erasureID(account)}
	if err := intent.Validate(); err != nil {
		return Intent{}, err
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return Intent{}, err
	}
	if err := privateDirectory(dir); err != nil {
		return Intent{}, err
	}
	path := filepath.Join(dir, "erasure-"+intent.ErasureID+".json")
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if errors.Is(err, os.ErrExist) {
		existing, readErr := readIntent(path)
		if readErr != nil {
			return Intent{}, readErr
		}
		// Another invocation may have written a complete record but not yet
		// synced it. Reuse still needs the same durability barrier before SQL.
		f, err = os.Open(path)
		if err != nil {
			return Intent{}, err
		}
		err = f.Sync()
		closeErr := f.Close()
		if err == nil {
			err = closeErr
		}
		if err == nil {
			err = syncDirectoryAncestors(dir, syncDir)
		}
		return existing, err
	}
	if err != nil {
		return Intent{}, err
	}
	data, err := json.Marshal(intent)
	if err == nil {
		_, err = f.Write(append(data, '\n'))
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return Intent{}, err
	}
	return intent, syncDirectoryAncestors(dir, syncDir)
}

// Sync every directory entry back to the root, including reused records. Merely
// syncing the leaf does not persist a newly created leaf's entry in its parent.
// A failed barrier must never allow the caller to apply database erasure.
func syncDirectoryAncestors(dir string, syncDir func(string) error) error {
	path, err := filepath.Abs(dir)
	if err != nil {
		return err
	}
	for depth := 0; depth < 64; depth++ {
		if err = syncDir(path); err != nil {
			return err
		}
		parent := filepath.Dir(path)
		if parent == path {
			return nil
		}
		path = parent
	}
	return errors.New("journal directory depth exceeded")
}

func syncDirectory(dir string) error {
	directory, err := os.Open(dir)
	if err != nil {
		return err
	}
	err = directory.Sync()
	closeErr := directory.Close()
	if err == nil {
		err = closeErr
	}
	return err
}

func ReadIntents(dir string, limit int) ([]Intent, error) {
	if limit < 1 || limit > 1000 {
		return nil, errors.New("invalid journal batch bound")
	}
	if err := privateDirectory(dir); err != nil {
		return nil, err
	}
	d, err := os.Open(dir)
	if err != nil {
		return nil, err
	}
	defer d.Close()
	entries, err := d.ReadDir(limit + 1)
	if err != nil && err != io.EOF {
		return nil, err
	}
	if len(entries) > limit {
		return nil, errors.New("journal batch bound exceeded")
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	intents := make([]Intent, 0, len(entries))
	for _, entry := range entries {
		intent, err := readIntent(filepath.Join(dir, entry.Name()))
		if err != nil {
			return nil, err
		}
		intents = append(intents, intent)
	}
	return intents, nil
}
