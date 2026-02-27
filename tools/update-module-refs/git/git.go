package git

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

// Log returns the commit SHA of the most recent commit that touched dirPath.
// dirPath can be absolute or relative to the repository root.
func Log(dirPath string) (string, error) {
	root, err := repoRoot()
	if err != nil {
		return "", err
	}

	relPath, err := toRelPath(root, dirPath)
	if err != nil {
		return "", err
	}

	cmd := exec.Command("git", "log", "-n1", "--pretty=%H", "--", relPath) //nolint:gosec // dirPath is not user input
	cmd.Dir = root

	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git log for %q: %w", relPath, err)
	}

	sha := strings.TrimSpace(string(out))
	if sha == "" {
		return "", fmt.Errorf("git log for %q: no commits found", relPath)
	}

	return sha, nil
}

// AddAndCommit stages all changes under dirPath and commits with the given message.
// dirPath can be absolute or relative to the repository root.
func AddAndCommit(dirPath string, message string) error {
	root, err := repoRoot()
	if err != nil {
		return err
	}

	relPath, err := toRelPath(root, dirPath)
	if err != nil {
		return err
	}

	add := exec.Command("git", "add", relPath) //nolint:gosec // dirPath is not user input
	add.Dir = root
	if out, err := add.CombinedOutput(); err != nil {
		return fmt.Errorf("git add %q: %w\n%s", relPath, err, out)
	}

	// Check if there are staged changes before committing.
	diff := exec.Command("git", "diff", "--cached", "--quiet")
	diff.Dir = root
	if err := diff.Run(); err == nil {
		// Exit code 0 means no staged changes.
		return nil
	}

	commit := exec.Command("git", "commit", "-m", message) //nolint:gosec // message is not user input
	commit.Dir = root
	if out, err := commit.CombinedOutput(); err != nil {
		return fmt.Errorf("git commit: %w\n%s", err, out)
	}

	return nil
}

func repoRoot() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git rev-parse --show-toplevel: %w", err)
	}

	return strings.TrimSpace(string(out)), nil
}

// toRelPath converts dirPath to a path relative to root if it is absolute.
func toRelPath(root, dirPath string) (string, error) {
	if filepath.IsAbs(dirPath) {
		rel, err := filepath.Rel(root, dirPath)
		if err != nil {
			return "", fmt.Errorf("making %q relative to %q: %w", dirPath, root, err)
		}

		return rel, nil
	}

	return dirPath, nil
}
