package tf

import (
	"io/fs"
	"strings"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclwrite"
	"github.com/zclconf/go-cty/cty"
)

// File represents a parsed .tf file containing module blocks.
type File struct {
	// Path is the file path relative to the walked fs.FS root.
	Path string
	// HCL is the underlying hclwrite file for serialization.
	HCL *hclwrite.File
	// Modules are the module blocks found in this file.
	Modules []ModuleSource
}

// ModuleSource represents a module block found in a .tf file.
type ModuleSource struct {
	// Name is the module block label (e.g. "github_repo_bbd").
	Name string
	// Body is the hclwrite body of the module block.
	Body *hclwrite.Body
}

// Source returns the raw value of the source attribute.
func (m ModuleSource) Source() string {
	srcAttr := m.Body.GetAttribute("source")
	if srcAttr == nil {
		return ""
	}

	src := strings.TrimSpace(string(srcAttr.Expr().BuildTokens(nil).Bytes()))
	src = strings.Trim(src, `"`)
	return src
}

// SetSource updates the source attribute value.
func (m ModuleSource) SetSource(source string) {
	m.Body.SetAttributeValue("source", cty.StringVal(source))
}

// Load reads all *.tf files in the directory represented by fsys, parses them
// with hclwrite, and extracts module blocks with their source attributes.
func Load(fsys fs.FS) ([]File, error) {
	entries, err := fs.ReadDir(fsys, ".")
	if err != nil {
		return nil, err
	}

	var results []File

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".tf") {
			continue
		}

		content, err := fs.ReadFile(fsys, entry.Name())
		if err != nil {
			return nil, err
		}

		file, diags := hclwrite.ParseConfig(content, entry.Name(), hcl.InitialPos)
		if diags.HasErrors() {
			continue
		}

		var modules []ModuleSource
		for _, block := range file.Body().Blocks() {
			if block.Type() != "module" {
				continue
			}
			labels := block.Labels()
			if len(labels) == 0 {
				continue
			}
			if block.Body().GetAttribute("source") == nil {
				continue
			}

			modules = append(modules, ModuleSource{
				Name: labels[0],
				Body: block.Body(),
			})
		}

		if len(modules) > 0 {
			results = append(results, File{
				Path:    entry.Name(),
				HCL:     file,
				Modules: modules,
			})
		}
	}

	return results, nil
}
