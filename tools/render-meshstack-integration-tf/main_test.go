package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRenderAddsAliasedProvidersFromConfigurationAliases(t *testing.T) {
	input := `terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.meshcloud, aws.automation]
    }
    meshstack = {
      source = "meshcloud/meshstack"
    }
  }
}
`

	output := renderFromString(t, input)

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
	input := `terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    meshstack = {
      source = "meshcloud/meshstack"
    }
  }
}
`

	output := renderFromString(t, input)

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
	input := `terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.meshcloud]
    }
    meshstack = {
      source = "meshcloud/meshstack"
    }
  }
}
`

	output := renderFromString(t, input)

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
	input := `terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.meshcloud]
    }
  }
}

provider "aws" {
  alias = "management"
}
`

	output := renderFromString(t, input)

	if got, want := strings.Count(output, `alias = "management"`), 1; got != want {
		t.Fatalf("management alias block duplicated: got %d want %d\n%s", got, want, output)
	}
	if !strings.Contains(output, `alias = "meshcloud"`) {
		t.Fatalf("expected meshcloud alias block to be rendered\n%s", output)
	}
}

func TestRenderDeduplicatesConfigurationAliases(t *testing.T) {
	input := `terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.management]
    }
  }
}
`

	output := renderFromString(t, input)

	if got, want := strings.Count(output, `alias = "management"`), 1; got != want {
		t.Fatalf("management alias block duplicated: got %d want %d\n%s", got, want, output)
	}
	if got, want := strings.Count(output, `provider "aws"`), 2; got != want {
		t.Fatalf("unexpected number of aws provider blocks: got %d want %d\n%s", got, want, output)
	}
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
