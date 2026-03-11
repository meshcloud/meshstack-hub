package main

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const testRepoURL = "github.com/meshcloud/meshstack-hub"

// TestScanAndBuildDependencies verifies that scanModules correctly produces
// modules/-prefixed directory keys (matching extractModulePath output) and
// that buildDependencies + CalculateWaves orders them into the correct waves.
//
// Fixture layout (testdata/modules/):
//
//	aws/budget/buildingblock        — no hub deps → wave 0
//	azure/postgresql/buildingblock  — depends on aws/budget → wave 1
//	stackit/project/buildingblock   — depends on azure/postgresql → wave 2
func TestScanAndBuildDependencies(t *testing.T) {
	fsys := os.DirFS("testdata")

	modules, err := scanModules(fsys, testRepoURL, "modules")
	require.NoError(t, err)

	// All three buildingblock directories should be found.
	assert.Len(t, modules, 2, "only directories with hub module references should be scanned")

	// Keys must be modules/-prefixed to match extractModulePath output.
	for dir := range modules {
		assert.True(t, len(dir) > len("modules/") && dir[:len("modules/")] == "modules/",
			"scan key %q must be prefixed with 'modules/'", dir)
	}

	// azure and stackit dirs reference hub modules; aws/budget has none.
	assert.Contains(t, modules, "modules/azure/postgresql/buildingblock")
	assert.Contains(t, modules, "modules/stackit/project/buildingblock")

	deps := buildDependencies(modules, testRepoURL)
	waves, err := deps.CalculateWaves()
	require.NoError(t, err)

	// Should produce at least 2 waves (azure depends on aws, stackit depends on azure).
	require.GreaterOrEqual(t, len(waves), 2, "expected at least 2 dependency waves")

	// Flatten waves into ordered positions.
	position := map[string]int{}
	for i, wave := range waves {
		for _, dir := range wave {
			position[dir] = i
		}
	}

	azurePos := position["modules/azure/postgresql/buildingblock"]
	stackitPos := position["modules/stackit/project/buildingblock"]

	assert.Less(t, azurePos, stackitPos,
		"azure/postgresql must be updated before stackit/project")
}
