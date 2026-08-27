package main

import (
	"embed"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

//go:embed testdata/*.tf
var testdataFiles embed.FS

func TestRenderAddsAliasedProvidersFromConfigurationAliases(t *testing.T) {
	output := renderFromFixture(t, "aliases_multiple.tf")

	if got, want := strings.Count(output, `provider "aws"`), 4; got != want {
		t.Fatalf("unexpected number of aws provider blocks: got %d want %d\n%s", got, want, output)
	}
	for _, alias := range []string{"management", "meshcloud", "automation"} {
		if !strings.Contains(output, `alias = "`+alias+`"`) {
			t.Fatalf("expected alias provider block for %q\n%s", alias, output)
		}
	}
}

func TestRenderDoesNotRenderAliasesWhenNoneConfigured(t *testing.T) {
	output := renderFromFixture(t, "no_aliases.tf")

	if strings.Contains(output, `alias = "`) {
		t.Fatalf("did not expect any aliased provider blocks\n%s", output)
	}
	if got, want := strings.Count(output, `provider "aws"`), 1; got != want {
		t.Fatalf("unexpected number of aws provider blocks: got %d want %d\n%s", got, want, output)
	}
	if got, want := strings.Count(output, `provider "meshstack"`), 1; got != want {
		t.Fatalf("unexpected number of meshstack provider blocks: got %d want %d\n%s", got, want, output)
	}
}

func TestRenderMixedProvidersWithAndWithoutAliases(t *testing.T) {
	output := renderFromFixture(t, "mixed_aliases.tf")

	if got, want := strings.Count(output, `provider "aws"`), 3; got != want {
		t.Fatalf("unexpected number of aws provider blocks: got %d want %d\n%s", got, want, output)
	}
	if got, want := strings.Count(output, `provider "meshstack"`), 1; got != want {
		t.Fatalf("unexpected number of meshstack provider blocks: got %d want %d\n%s", got, want, output)
	}
	if got, want := strings.Count(output, `alias = "`), 2; got != want {
		t.Fatalf("unexpected number of aliased provider blocks: got %d want %d\n%s", got, want, output)
	}
	for _, alias := range []string{"management", "meshcloud"} {
		if !strings.Contains(output, `alias = "`+alias+`"`) {
			t.Fatalf("expected alias provider block for %q\n%s", alias, output)
		}
	}
}

func TestRenderSkipsExistingAliasedProvider(t *testing.T) {
	output := renderFromFixture(t, "existing_alias_provider.tf")

	if got, want := strings.Count(output, `alias = "management"`), 1; got != want {
		t.Fatalf("management alias block duplicated: got %d want %d\n%s", got, want, output)
	}
	if !strings.Contains(output, `alias = "meshcloud"`) {
		t.Fatalf("expected meshcloud alias block to be rendered\n%s", output)
	}
}

func TestRenderDeduplicatesConfigurationAliases(t *testing.T) {
	output := renderFromFixture(t, "duplicate_aliases.tf")

	if got, want := strings.Count(output, `alias = "management"`), 1; got != want {
		t.Fatalf("management alias block duplicated: got %d want %d\n%s", got, want, output)
	}
	if got, want := strings.Count(output, `provider "aws"`), 2; got != want {
		t.Fatalf("unexpected number of aws provider blocks: got %d want %d\n%s", got, want, output)
	}
}

func renderFromFixture(t *testing.T, fixture string) string {
	t.Helper()

	input, err := testdataFiles.ReadFile(filepath.Join("testdata", fixture))
	if err != nil {
		t.Fatalf("read fixture %q: %v", fixture, err)
	}

	return renderFromString(t, string(input))
}

func renderFromString(t *testing.T, input string) string {
	t.Helper()

	tempDir := t.TempDir()
	path := filepath.Join(tempDir, "meshstack_integration.tf")
	if err := os.WriteFile(path, []byte(input), 0o600); err != nil {
		t.Fatalf("write input file: %v", err)
	}

	var output strings.Builder
	if err := render(path, &output); err != nil {
		t.Fatalf("render failed: %v", err)
	}
	return output.String()
}
