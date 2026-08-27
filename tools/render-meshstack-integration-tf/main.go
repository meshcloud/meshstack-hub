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
	"github.com/hashicorp/hcl/v2/hclsyntax"
	"github.com/hashicorp/hcl/v2/hclwrite"
	"github.com/zclconf/go-cty/cty"
)

//go:embed templates
var templateFiles embed.FS

type providerConfig struct {
	Name  string
	Alias string
}

func (p providerConfig) Key() string {
	if p.Alias == "" {
		return p.Name
	}
	return fmt.Sprintf("%s.%s", p.Name, p.Alias)
}

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

	requiredProviders, err := findRequiredProviders(file, filename)
	if err != nil {
		return err
	}
	existingProviders := findExistingProviders(file, filename)

	log.Printf("Found existing providers: %v\n", existingProviderKeys(existingProviders))
	log.Printf("Found required providers: %v\n", providerConfigKeys(requiredProviders))

	for _, provider := range requiredProviders {
		if existingProviders[provider.Key()] {
			log.Printf("Skip rendering provider '%s', already defined in input\n", provider.Key())
			continue
		}
		providerFile, err := renderProviderBlockFromTemplate(provider)
		if err != nil {
			return err
		}
		file.Body().AppendNewline()
		file.Body().AppendUnstructuredTokens(providerFile.Body().BuildTokens(nil))
		existingProviders[provider.Key()] = true
	}

	_, err = file.WriteTo(w)
	return err
}

func findRequiredProviders(file *hclwrite.File, filename string) ([]providerConfig, error) {
	var requiredProviders []providerConfig
	for _, block := range file.Body().Blocks() {
		if block.Type() != "terraform" {
			continue
		}
		for _, terraformBlock := range block.Body().Blocks() {
			if terraformBlock.Type() != "required_providers" {
				continue
			}
			if len(requiredProviders) > 0 {
				return nil, fmt.Errorf("multiple terraform/required_providers blocks found, already have %s", providerConfigKeys(requiredProviders))
			}
			parsedRequiredProviders, err := parseRequiredProviders(terraformBlock, filename)
			if err != nil {
				return nil, err
			}
			requiredProviders = parsedRequiredProviders
		}
	}
	return requiredProviders, nil
}

func parseRequiredProviders(requiredProvidersBlock *hclwrite.Block, filename string) ([]providerConfig, error) {
	attrs := requiredProvidersBlock.Body().Attributes()
	providerNames := slices.Collect(maps.Keys(attrs))
	slices.Sort(providerNames)

	providers := make([]providerConfig, 0, len(providerNames))
	for _, providerName := range providerNames {
		providers = append(providers, providerConfig{Name: providerName})

		providerAliases, err := parseProviderAliases(attrs[providerName], providerName, filename)
		if err != nil {
			return nil, err
		}
		for _, providerAlias := range providerAliases {
			providers = append(providers, providerConfig{Name: providerName, Alias: providerAlias})
		}
	}
	return providers, nil
}

func parseProviderAliases(attribute *hclwrite.Attribute, providerName string, filename string) ([]string, error) {
	expr, diags := hclsyntax.ParseExpression(attribute.Expr().BuildTokens(nil).Bytes(), filename, hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		return nil, diags
	}

	objectExpr, ok := expr.(*hclsyntax.ObjectConsExpr)
	if !ok {
		return nil, nil
	}

	for _, item := range objectExpr.Items {
		key, ok := expressionAsString(item.KeyExpr)
		if !ok || key != "configuration_aliases" {
			continue
		}
		tupleExpr, ok := item.ValueExpr.(*hclsyntax.TupleConsExpr)
		if !ok {
			return nil, fmt.Errorf("provider %q has non-list configuration_aliases", providerName)
		}

		aliases := make([]string, 0, len(tupleExpr.Exprs))
		for _, aliasExpr := range tupleExpr.Exprs {
			alias, ok := parseProviderAliasExpression(aliasExpr, providerName)
			if !ok {
				log.Printf("Skipping unsupported configuration_aliases entry for provider '%s': %T\n", providerName, aliasExpr)
				continue
			}
			aliases = append(aliases, alias)
		}
		return aliases, nil
	}

	return nil, nil
}

func parseProviderAliasExpression(expr hclsyntax.Expression, providerName string) (string, bool) {
	scopeTraversalExpr, ok := expr.(*hclsyntax.ScopeTraversalExpr)
	if !ok {
		return "", false
	}
	traversal := scopeTraversalExpr.Traversal
	if len(traversal) != 2 {
		return "", false
	}

	root, ok := traversal[0].(hcl.TraverseRoot)
	if !ok || root.Name != providerName {
		return "", false
	}
	alias, ok := traversal[1].(hcl.TraverseAttr)
	if !ok {
		return "", false
	}
	return alias.Name, true
}

func expressionAsString(expr hclsyntax.Expression) (string, bool) {
	if keyword := hcl.ExprAsKeyword(expr); keyword != "" {
		return keyword, true
	}
	value, diags := expr.Value(nil)
	if diags.HasErrors() || value.Type() != cty.String {
		return "", false
	}
	return value.AsString(), true
}

func findExistingProviders(file *hclwrite.File, filename string) map[string]bool {
	existingProviders := map[string]bool{}
	for _, block := range file.Body().Blocks() {
		if block.Type() != "provider" {
			continue
		}

		providerName := block.Labels()[0]
		providerAlias := ""
		if aliasAttribute := block.Body().GetAttribute("alias"); aliasAttribute != nil {
			if alias, ok := parseStringAttribute(aliasAttribute, filename); ok {
				providerAlias = alias
			}
		}

		provider := providerConfig{Name: providerName, Alias: providerAlias}
		log.Printf("Found provider '%s'\n", provider.Key())
		existingProviders[provider.Key()] = true
	}
	return existingProviders
}

func parseStringAttribute(attribute *hclwrite.Attribute, filename string) (string, bool) {
	expr, diags := hclsyntax.ParseExpression(attribute.Expr().BuildTokens(nil).Bytes(), filename, hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		return "", false
	}
	value, diags := expr.Value(nil)
	if diags.HasErrors() || value.Type() != cty.String {
		return "", false
	}
	return value.AsString(), true
}

func providerConfigKeys(providers []providerConfig) []string {
	keys := make([]string, 0, len(providers))
	for _, provider := range providers {
		keys = append(keys, provider.Key())
	}
	slices.Sort(keys)
	return keys
}

func existingProviderKeys(providers map[string]bool) []string {
	keys := slices.Collect(maps.Keys(providers))
	slices.Sort(keys)
	return keys
}

func renderProviderBlockFromTemplate(provider providerConfig) (*hclwrite.File, error) {
	tmpl, err := loadProviderTemplate(provider.Name)
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, provider); err != nil {
		return nil, err
	}
	file, diags := hclwrite.ParseConfig(buf.Bytes(), fmt.Sprintf("%s.tmpl.tf", provider.Name), hcl.Pos{Line: 1, Column: 1})
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
