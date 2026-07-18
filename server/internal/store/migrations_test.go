package store

import (
	"testing"
)

func TestMigrationsAreOrdered(t *testing.T) {
	migs := Migrations()
	if len(migs) == 0 {
		t.Fatal("expected migrations")
	}
	for i, m := range migs {
		if i > 0 && m.Version <= migs[i-1].Version {
			t.Errorf("migrations not ordered at index %d", i)
		}
		if m.Up == "" {
			t.Errorf("migration %d has no up script", m.Version)
		}
		if m.Down == "" {
			t.Errorf("migration %d has no down script", m.Version)
		}
	}
}

func TestMigrationsUniqueVersions(t *testing.T) {
	seen := make(map[int]bool)
	for _, m := range Migrations() {
		if seen[m.Version] {
			t.Errorf("duplicate migration version %d", m.Version)
		}
		seen[m.Version] = true
	}
}
