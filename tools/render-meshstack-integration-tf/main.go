package main

import (
	"bytes"
	"embed"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"maps"
	"os"
	"slices"
	"text/template"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclwrite"
)

//go:embed templates
var templateFiles embed.FS

func main() {
	if len(os.Args) != 2 {
		log.Println("Usage: render-meshstack-integration-tf <file>")
		os.Exit(1)
	}
	if err := render(os.Args[1], os.Stdout); err != nil {
		log.Fatal(err)
	}
}

func render(filename string, w io.Writer) error {
	content, err := os.ReadFile(filename)
	if err != nil {
		return err
	}
	file, diags := hclwrite.ParseConfig(content, filename, hcl.Pos{Line: 1, Column: 1})
	if file == nil || diags.HasErrors() {
		return diags
	}

	// search for the Terraform and provider blocks
	var existingProviders []string
	var requiredProviders []string
	for _, block := range file.Body().Blocks() {
		switch block.Type() {
		case "terraform":
			for _, terraformBlock := range block.Body().Blocks() {
				if terraformBlock.Type() == "required_providers" {
					if len(requiredProviders) > 0 {
						return fmt.Errorf("multiple terraform/required_providers blocks found, already have %s", requiredProviders)
					}
					requiredProviders = slices.Collect(maps.Keys(terraformBlock.Body().Attributes()))
				}
			}
		case "provider":
			providerName := block.Labels()[0]
			log.Printf("Found provider '%s'\n", providerName)
			existingProviders = append(existingProviders, providerName)
		}
	}
	log.Printf("Found existing providers: %s\n", existingProviders)
	log.Printf("Found required providers: %s\n", requiredProviders)

	for _, providerName := range requiredProviders {
		if slices.Contains(existingProviders, providerName) {
			log.Printf("Skip rendering provider '%s', already defined in input\n", providerName)
			continue
		}
		providerFile, err := renderProviderBlockFromTemplate(providerName)
		if err != nil {
			return err
		}
		file.Body().AppendNewline()
		file.Body().AppendUnstructuredTokens(providerFile.Body().BuildTokens(nil))
	}

	_, err = file.WriteTo(w)
	return err
}

func renderProviderBlockFromTemplate(providerName string) (*hclwrite.File, error) {
	tmpl, err := loadProviderTemplate(providerName)
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	renderContext := struct {
		Name string
	}{providerName}
	if err := tmpl.Execute(&buf, renderContext); err != nil {
		return nil, err
	}
	file, diags := hclwrite.ParseConfig(buf.Bytes(), fmt.Sprintf("%s.tmpl.tf", providerName), hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		return nil, diags
	}
	return file, nil
}

func loadProviderTemplate(providerName string) (tmpl *template.Template, err error) {
	var tmplContent []byte
	tmplContent, err = templateFiles.ReadFile(fmt.Sprintf("templates/provider.%s.tmpl.tf", providerName))
	if err == nil {
		log.Printf("Using provider-specific template for provider '%s'\n", providerName)
	} else if errors.Is(err, fs.ErrNotExist) {
		tmplContent, err = templateFiles.ReadFile("templates/provider.tmpl.tf")
		if err != nil {
			return nil, err
		}
	} else {
		return nil, err
	}
	return template.New(providerName).Parse(string(tmplContent))
}
