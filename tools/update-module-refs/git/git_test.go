package git_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/meshcloud/meshstack-hub/tools/update-module-refs/git"
)

func TestLog(t *testing.T) {
	sha, err := git.Log(".")
	require.NoError(t, err)
	assert.Regexp(t, regexp.MustCompile(`^[0-9a-f]{40}$`), sha)
}

func TestLogAbsolutePath(t *testing.T) {
	// Resolve repo root to get an absolute path.
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	require.NoError(t, err)

	absPath := strings.TrimSpace(string(out))
	sha, err := git.Log(absPath)
	require.NoError(t, err)
	assert.Regexp(t, regexp.MustCompile(`^[0-9a-f]{40}$`), sha)
}

func TestAddAndCommit(t *testing.T) {
	// Create a temporary git repo for an isolated test.
	dir := t.TempDir()

	run := func(args ...string) {
		t.Helper()
		cmd := exec.Command(args[0], args[1:]...) //nolint:gosec
		cmd.Dir = dir
		out, err := cmd.CombinedOutput()
		require.NoError(t, err, "command %v failed: %s", args, out)
	}

	run("git", "init")
	run("git", "config", "user.email", "test@test.com")
	run("git", "config", "user.name", "Test")

	// Create an initial commit so the branch exists.
	require.NoError(t, os.WriteFile(filepath.Join(dir, "init.txt"), []byte("init"), 0o644))
	run("git", "add", ".")
	run("git", "commit", "-m", "initial")

	// Create a file and commit it via AddAndCommit.
	subDir := filepath.Join(dir, "sub")
	require.NoError(t, os.MkdirAll(subDir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(subDir, "test.txt"), []byte("hello"), 0o644))

	// Chdir into the temp repo so git commands resolve to it.
	t.Chdir(dir)

	err := git.AddAndCommit("sub", "test commit")
	require.NoError(t, err)

	// Verify the commit exists.
	cmd := exec.Command("git", "log", "-n1", "--pretty=%s")
	cmd.Dir = dir
	out, err := cmd.Output()
	require.NoError(t, err)
	assert.Equal(t, "test commit", strings.TrimSpace(string(out)))
}
