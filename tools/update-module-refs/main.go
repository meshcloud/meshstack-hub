package main

import (
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/dependency"
	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/git"
	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/tf"
)

func main() {
	repoURL := flag.String("repo", "github.com/meshcloud/meshstack-hub", "repository host+path to match module sources against")
	dryRun := flag.Bool("dry-run", false, "only print what would be updated, do not write or commit")
	flag.Parse()

	cwd, err := os.Getwd()
	if err != nil {
		log.Fatalf("failed to get working directory: %v", err)
	}

	fsys := os.DirFS(cwd)
	modules, err := scanModules(fsys, *repoURL)
	if err != nil {
		log.Fatalf("failed to scan modules: %v", err)
	}

	log.Printf("found modules in %d directories", len(modules))

	deps := buildDependencies(modules, *repoURL)
	waves, err := deps.CalculateWaves()
	if err != nil {
		log.Fatalf("failed to calculate dependency waves: %v", err)
	}

	log.Printf("calculated %d dependency waves", len(waves))

	if *dryRun {
		log.Println("WARNING: dry-run mode — refs shown may not be accurate as changes are not committed")
	}

	for i, wave := range waves {
		log.Printf("wave %d: %v", i, wave)

		for _, dir := range wave {
			if err := processDirectory(cwd, dir, modules[dir], *repoURL, *dryRun); err != nil {
				log.Fatalf("failed to process %q: %v", dir, err)
			}
		}
	}
}

func processDirectory(cwd, dir string, files []tf.File, repoURL string, dryRun bool) error {
	dirChanged := false

	for _, f := range files {
		fileChanged := false

		for _, m := range f.Modules {
			depPath := extractModulePath(repoURL, m.Source())

			sha, err := git.Log(depPath)
			if err != nil {
				return fmt.Errorf("git log for %q: %w", depPath, err)
			}

			newSource := repoURL + "//" + depPath + "?ref=" + sha
			if m.Source() == newSource {
				log.Printf("  %s/%s -> %s (up to date)", dir, m.Name, depPath)
				continue
			}

			log.Printf("  %s/%s -> %s ref=%s", dir, m.Name, depPath, sha)
			m.SetSource(newSource)
			fileChanged = true
		}

		if !fileChanged {
			continue
		}

		dirChanged = true

		if dryRun {
			log.Printf("  would write %s", filepath.Join(dir, f.Path))
			continue
		}

		outPath := filepath.Join(cwd, dir, f.Path)
		if err := os.WriteFile(outPath, f.HCL.Bytes(), 0o644); err != nil {
			return fmt.Errorf("writing %q: %w", outPath, err)
		}

		log.Printf("  wrote %s", filepath.Join(dir, f.Path))
	}

	if !dirChanged {
		log.Printf("  %s: all refs up to date, nothing to commit", dir)
		return nil
	}

	commitMsg := fmt.Sprintf("chore: update module refs in %s", dir)

	if dryRun {
		log.Printf("  would commit %s: %q", dir, commitMsg)
		return nil
	}

	absDir := filepath.Join(cwd, dir)
	if err := git.AddAndCommit(absDir, commitMsg); err != nil {
		return fmt.Errorf("commit %q: %w", dir, err)
	}

	log.Printf("  committed %s", dir)

	return nil
}

// scanModules walks all directories in fsys and returns only those
// containing terraform modules with sources matching repoURL.
func scanModules(fsys fs.FS, repoURL string) (map[string][]tf.File, error) {
	result := make(map[string][]tf.File)

	err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if !d.IsDir() {
			return nil
		}

		sub, err := fs.Sub(fsys, path)
		if err != nil {
			return err
		}

		files, err := tf.Load(sub)
		if err != nil {
			return err
		}

		// Filter to only files that have at least one module source matching repoURL.
		var matched []tf.File
		for _, f := range files {
			var matchingModules []tf.ModuleSource
			for _, m := range f.Modules {
				if strings.HasPrefix(m.Source(), repoURL+"//") {
					matchingModules = append(matchingModules, m)
				}
			}

			if len(matchingModules) > 0 {
				matched = append(matched, tf.File{
					Path:    f.Path,
					HCL:     f.HCL,
					Modules: matchingModules,
				})
			}
		}

		if len(matched) > 0 {
			result[path] = matched
		}

		return nil
	})

	return result, err
}

// buildDependencies creates dependency graph entries from the module map.
// Each directory becomes a node, its dependencies are the repo-internal module paths it references.
func buildDependencies(modules map[string][]tf.File, repoURL string) dependency.Dependencies[string] {
	var deps dependency.Dependencies[string]

	for dir, files := range modules {
		seen := make(map[string]bool)

		for _, f := range files {
			for _, m := range f.Modules {
				depPath := extractModulePath(repoURL, m.Source())
				if depPath != "" && !seen[depPath] {
					seen[depPath] = true
				}
			}
		}

		var dependsOn []string
		for dep := range seen {
			dependsOn = append(dependsOn, dep)
		}

		deps = append(deps, dependency.Dependency[string]{
			This:      dir,
			DependsOn: dependsOn,
		})
	}

	return deps
}

// extractModulePath extracts the repo-relative path from a terraform module source.
// e.g. "github.com/meshcloud/meshstack-hub//modules/azure/postgresql?ref=v1.0.0"
// returns "modules/azure/postgresql".
func extractModulePath(repoURL, source string) string {
	prefix := repoURL + "//"
	if !strings.HasPrefix(source, prefix) {
		return ""
	}

	path := strings.TrimPrefix(source, prefix)

	// Strip ?ref=... query parameter.
	if idx := strings.Index(path, "?"); idx != -1 {
		path = path[:idx]
	}

	return path
}
