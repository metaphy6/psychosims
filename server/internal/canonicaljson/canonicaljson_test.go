package canonicaljson

import (
	"math"
	"testing"
)

func TestEncodeBasic(t *testing.T) {
	v := map[string]any{
		"name":  "test",
		"value": 42,
		"ok":    true,
	}
	got, err := Encode(v)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	want := `{"name":"test","ok":true,"value":42}`
	if string(got) != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestEncodeNested(t *testing.T) {
	v := map[string]any{
		"z": []any{map[string]any{"b": 2, "a": 1}},
		"a": "top",
	}
	got, err := Encode(v)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	want := `{"a":"top","z":[{"a":1,"b":2}]}`
	if string(got) != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestMarshalStruct(t *testing.T) {
	type item struct {
		Z int    `json:"z"`
		A string `json:"a"`
	}
	got, err := Marshal(item{Z: 2, A: "x"})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	want := `{"a":"x","z":2}`
	if string(got) != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestEncodeFloat(t *testing.T) {
	got, err := Encode(map[string]any{"v": 1.5})
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	want := `{"v":1.5}`
	if string(got) != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestEncodeRejectsNaN(t *testing.T) {
	_, err := Encode(map[string]any{"v": math.NaN()})
	if err == nil {
		t.Fatal("expected error for NaN")
	}
}
