package main

import (
	"bytes"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"maps"
	"os"
	"slices"
	"strings"
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
	var err error
	switch {
	case len(os.Args) == 2:
		err = render(os.Args[1], os.Stdout)
	case len(os.Args) == 3 && os.Args[1] == "--sections":
		err = renderSections(os.Args[2], os.Stdout)
	default:
		log.Println("Usage: render-meshstack-integration-tf [--sections] <file>")
		os.Exit(1)
	}
	if err != nil {
		log.Fatal(err)
	}
}

type snippet struct {
	Code     string    `json:"code"`
	Sections []section `json:"sections"`
}

type section struct {
	Title     string `json:"title"`
	Collapsed bool   `json:"collapsed"`
	Code      string `json:"code"`
}

// The website shows the snippet in the order a reader declares an integration, and collapses the
// boilerplate around the building block definition so a reader sees what matters first.
var sectionKinds = []section{
	{Title: "Provider Setup", Collapsed: true},
	{Title: "Variables", Collapsed: true},
	{Title: "Locals", Collapsed: true},
	{Title: "Building Block Definition"},
	{Title: "Backplane"},
	{Title: "Resources"},
	{Title: "Outputs", Collapsed: true},
}

func renderSections(filename string, w io.Writer) error {
	var code bytes.Buffer
	if err := render(filename, &code); err != nil {
		return err
	}
	return json.NewEncoder(w).Encode(snippetOf(code.Bytes(), filename))
}

// The copied code follows the section order, so it matches what the reader sees.
func snippetOf(code []byte, filename string) snippet {
	file, diags := hclwrite.ParseConfig(code, filename, hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() || !onlyBlocksWithTheirComments(file.Body()) {
		log.Println("Show a single section, the file has content outside of blocks")
		return snippet{Code: string(code), Sections: []section{{Title: "Integration", Code: string(code)}}}
	}

	sections := slices.Clone(sectionKinds)
	for _, block := range file.Body().Blocks() {
		kind := &sections[slices.IndexFunc(sections, func(s section) bool { return s.Title == sectionTitleOf(block) })]
		blockCode := strings.TrimSpace(string(block.BuildTokens(nil).Bytes()))
		if kind.Code != "" {
			kind.Code += "\n\n"
		}
		kind.Code += blockCode
	}
	sections = slices.DeleteFunc(sections, func(s section) bool { return s.Code == "" })

	sectionCodes := make([]string, 0, len(sections))
	for _, s := range sections {
		sectionCodes = append(sectionCodes, s.Code)
	}
	return snippet{Code: strings.Join(sectionCodes, "\n\n") + "\n", Sections: sections}
}

// hclwrite keeps the comment lines directly above a block with the block. Anything else, like a
// comment separated from the next block by a blank line, would be lost when splitting by block.
func onlyBlocksWithTheirComments(body *hclwrite.Body) bool {
	commentsInBlocks := 0
	for _, block := range body.Blocks() {
		commentsInBlocks += countComments(block.BuildTokens(nil))
	}
	return len(body.Attributes()) == 0 && commentsInBlocks == countComments(body.BuildTokens(nil))
}

func countComments(tokens hclwrite.Tokens) int {
	count := 0
	for _, token := range tokens {
		if token.Type == hclsyntax.TokenComment {
			count++
		}
	}
	return count
}

func sectionTitleOf(block *hclwrite.Block) string {
	switch block.Type() {
	case "variable":
		return "Variables"
	case "output":
		return "Outputs"
	case "locals":
		return "Locals"
	case "terraform", "provider":
		return "Provider Setup"
	case "module":
		if block.Labels()[0] == "backplane" {
			return "Backplane"
		}
	case "resource":
		if block.Labels()[0] == "meshstack_building_block_definition" {
			return "Building Block Definition"
		}
	}
	return "Resources"
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
