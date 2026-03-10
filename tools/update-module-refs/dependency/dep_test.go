package dependency_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/dependency"
)

func TestCalculateWaves_Linear(t *testing.T) {
	// c -> b -> a (a is leaf)
	deps := dependency.Dependencies[string]{
		{This: "a"},
		{This: "b", DependsOn: []string{"a"}},
		{This: "c", DependsOn: []string{"b"}},
	}

	waves, err := deps.CalculateWaves()
	require.NoError(t, err)
	require.Len(t, waves, 3)

	assert.ElementsMatch(t, []string{"a"}, waves[0])
	assert.ElementsMatch(t, []string{"b"}, waves[1])
	assert.ElementsMatch(t, []string{"c"}, waves[2])
}

func TestCalculateWaves_Diamond(t *testing.T) {
	// d -> b, c; b -> a; c -> a
	deps := dependency.Dependencies[string]{
		{This: "a"},
		{This: "b", DependsOn: []string{"a"}},
		{This: "c", DependsOn: []string{"a"}},
		{This: "d", DependsOn: []string{"b", "c"}},
	}

	waves, err := deps.CalculateWaves()
	require.NoError(t, err)
	require.Len(t, waves, 3)

	assert.ElementsMatch(t, []string{"a"}, waves[0])
	assert.ElementsMatch(t, []string{"b", "c"}, waves[1])
	assert.ElementsMatch(t, []string{"d"}, waves[2])
}

func TestCalculateWaves_AllIndependent(t *testing.T) {
	deps := dependency.Dependencies[string]{
		{This: "x"},
		{This: "y"},
		{This: "z"},
	}

	waves, err := deps.CalculateWaves()
	require.NoError(t, err)
	require.Len(t, waves, 1)

	assert.ElementsMatch(t, []string{"x", "y", "z"}, waves[0])
}

func TestCalculateWaves_Circular(t *testing.T) {
	deps := dependency.Dependencies[string]{
		{This: "a", DependsOn: []string{"b"}},
		{This: "b", DependsOn: []string{"a"}},
	}

	_, err := deps.CalculateWaves()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "circular dependency")
}

func TestCalculateWaves_ExternalDeps(t *testing.T) {
	// b depends on "ext" which is not in the deps list.
	deps := dependency.Dependencies[string]{
		{This: "a"},
		{This: "b", DependsOn: []string{"a", "ext"}},
	}

	waves, err := deps.CalculateWaves()
	require.NoError(t, err)
	require.Len(t, waves, 2)

	assert.ElementsMatch(t, []string{"a"}, waves[0])
	assert.ElementsMatch(t, []string{"b"}, waves[1])
}
