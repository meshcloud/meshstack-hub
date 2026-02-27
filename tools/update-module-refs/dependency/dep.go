package dependency

import "fmt"

// Dependency represents a node with dependencies on other nodes.
type Dependency[T comparable] struct {
	This      T
	DependsOn []T
}

// Dependencies is a collection of Dependency nodes.
type Dependencies[T comparable] []Dependency[T]

// CalculateWaves returns the deps as waves starting with dependencies having empty DependsOn,
// then the next wave containing deps only on the previous wave, and so on.
func (deps Dependencies[T]) CalculateWaves() ([][]T, error) {
	// Build a set of all known nodes and their remaining dependencies.
	remaining := make(map[T]map[T]bool, len(deps))
	known := make(map[T]bool, len(deps))

	for _, d := range deps {
		known[d.This] = true
	}

	for _, d := range deps {
		needs := make(map[T]bool)
		for _, dep := range d.DependsOn {
			// Only track dependencies on nodes within the graph.
			if known[dep] {
				needs[dep] = true
			}
		}
		remaining[d.This] = needs
	}

	resolved := make(map[T]bool)
	var waves [][]T

	for len(remaining) > 0 {
		// Find all nodes whose dependencies are fully resolved.
		var wave []T
		for node, needs := range remaining {
			ready := true
			for dep := range needs {
				if !resolved[dep] {
					ready = false
					break
				}
			}
			if ready {
				wave = append(wave, node)
			}
		}

		if len(wave) == 0 {
			return nil, fmt.Errorf("circular dependency detected among remaining nodes")
		}

		// Mark wave nodes as resolved and remove from remaining.
		for _, node := range wave {
			resolved[node] = true
			delete(remaining, node)
		}

		waves = append(waves, wave)
	}

	return waves, nil
}
