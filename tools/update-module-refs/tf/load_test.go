package tf_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/tf"
)

func TestLoad(t *testing.T) {
	fsys := os.DirFS("testdata/simple")
	files, err := tf.Load(fsys)
	require.NoError(t, err)

	// Collect all modules across files.
	type moduleInfo struct {
		path   string
		source string
	}
	found := map[string]moduleInfo{}
	for _, f := range files {
		for _, m := range f.Modules {
			found[m.Name] = moduleInfo{path: f.Path, source: m.Source()}
		}
	}

	assert.Len(t, found, 3)

	assert.Equal(t, moduleInfo{
		path:   "main.tf",
		source: "github.com/meshcloud/meshstack-hub//modules/github/repository?ref=main",
	}, found["github_repo_bbd"])

	assert.Equal(t, moduleInfo{
		path:   "main.tf",
		source: "./backplane",
	}, found["backplane"])

	assert.Equal(t, moduleInfo{
		path:   "main.tf",
		source: "github.com/meshcloud/meshstack-hub//modules/azure/postgresql?ref=v1.0.0",
	}, found["postgresql_bbd"])

	// Verify HCL file is present for serialization.
	for _, f := range files {
		assert.NotNil(t, f.HCL, "file %q: HCL should not be nil", f.Path)
	}
}
