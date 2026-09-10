package server

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadExistingCatalogManifest(t *testing.T) {
	c, err := LoadCatalog([]string{"../../../content/manifests/siege_brumosis.json"})
	if err != nil {
		t.Fatal(err)
	}
	item := c.cases["siege.brumosis"]
	if item.InitialAxes["trust"] != 40 || item.ManifestChecksum == "" {
		t.Fatalf("catalog state: %+v", item)
	}
	body, err := os.ReadFile("../../../content/manifests/siege_brumosis.json")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "tampered.json")
	if err := os.WriteFile(path, []byte(strings.Replace(string(body), `"trust": 40`, `"trust": 99`, 1)), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadCatalog([]string{path}); err == nil {
		t.Fatal("tampered catalog accepted")
	}
}
