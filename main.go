package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	// for optional fancy color logging
	"github.com/fatih/color"
)

// in case you want color logs
var (
	info  = color.New(color.FgCyan).PrintlnFunc()
	warn  = color.New(color.FgYellow).PrintlnFunc()
	fatal = color.New(color.FgHiRed).PrintlnFunc()
)

const scratchExt = "-scratch.md"

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		fatal("be real, can't fetch home dir:", err)
		os.Exit(1)
	}

	// scratch notes live in the daybook vault (git-versioned, not iCloud —
	// iCloud eviction made first-run-of-day block ~60s on a cloud download)
	scratchPath := filepath.Join(home, "Development", "daybook", "rubberducks")

	// generate today's filename
	todayName := time.Now().Format("20060102") + scratchExt
	todayFile := filepath.Join(scratchPath, todayName)

	// does today's file already exist?
	if fileExists(todayFile) {
		info("already got today's scratch. opening it…")
		openFile(todayFile)
		return
	}

	// ensure scratch directory is present
	if err := os.MkdirAll(scratchPath, 0755); err != nil {
		fatal("whoa, couldn't create scratch directory:", err)
		os.Exit(1)
	}

	// gather all existing scratch files
	files, err := os.ReadDir(scratchPath)
	if err != nil {
		fatal("trouble reading scratch dir:", err)
		os.Exit(1)
	}

	var scratchFiles []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(f.Name(), scratchExt) {
			scratchFiles = append(scratchFiles, f.Name())
		}
	}

	// if there aren't any old files, create fresh
	if len(scratchFiles) == 0 {
		info("no scratch files found; conjuring a fresh one…")
		createFileWithHeading(todayFile)
		openFile(todayFile)
		return
	}

	// we do have old scratch files; find the newest
	sort.Strings(scratchFiles) // ascending order by filename
	newest := scratchFiles[len(scratchFiles)-1]
	newestPath := filepath.Join(scratchPath, newest)

	// copy, but rewrite heading to today's date
	info("found previous scratch, forging new daily file…")
	copyAndRewriteHeading(newestPath, todayFile)
	openFile(todayFile)
}

// fileExists is a simple helper to see if a file path is present
func fileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

// createFileWithHeading seeds a brand-new scratch file with a stylized heading
func createFileWithHeading(path string) {
	f, err := os.Create(path)
	if err != nil {
		fatal("couldn't create scratch file:", err)
		os.Exit(1)
	}
	defer f.Close()

	// stylized heading
	dateHeading := time.Now().Format("2006-01-02")
	heading := fmt.Sprintf("# ─────────────────────────────\n# scratch for %s\n# ─────────────────────────────\n\n", dateHeading)
	_, err = f.WriteString(heading)
	if err != nil {
		fatal("failed to write to scratch file:", err)
		os.Exit(1)
	}
}

// copyAndRewriteHeading clones the contents from oldFile -> newFile
// but updates the first heading line(s) with today's date
func copyAndRewriteHeading(oldFile, newFile string) {
	in, err := os.Open(oldFile)
	if err != nil {
		fatal("couldn't open old scratch file:", err)
		os.Exit(1)
	}
	defer in.Close()

	out, err := os.Create(newFile)
	if err != nil {
		fatal("couldn't create new scratch file:", err)
		os.Exit(1)
	}
	defer out.Close()

	scanner := bufio.NewScanner(in)
	firstHeadingLineFound := false
	dateHeading := time.Now().Format("2006-01-02")

	// new heading style
	newHeading := fmt.Sprintf("# ─────────────────────────────\n# scratch for %s\n# ─────────────────────────────\n", dateHeading)

	// we read the old file line by line
	for scanner.Scan() {
		line := scanner.Text()
		// if it's the first line that starts with "# "
		// we consider that the heading block. let's skip those lines
		// until we hit a blank line or something
		if !firstHeadingLineFound && strings.HasPrefix(line, "#") {
			// skip old heading lines
			continue
		}
		if !firstHeadingLineFound {
			// once we detect that we've moved past the heading block
			// insert the new heading, mark that we've done so
			_, err = out.WriteString(newHeading + "\n")
			if err != nil {
				fatal("error writing new heading:", err)
				os.Exit(1)
			}
			firstHeadingLineFound = true
		}
		// from here on out, we preserve the old content
		_, err = out.WriteString(line + "\n")
		if err != nil {
			fatal("error copying lines:", err)
			os.Exit(1)
		}
	}

	// if the old file had no lines at all, we still want to write the heading
	if !firstHeadingLineFound {
		_, err = out.WriteString(newHeading + "\n")
		if err != nil {
			fatal("failed to write heading to new scratch file:", err)
			os.Exit(1)
		}
	}

	if err := scanner.Err(); err != nil {
		fatal("problem scanning old file:", err)
		os.Exit(1)
	}
}

// openFile spawns an editor for the specified file
func openFile(path string) {
	editor := os.Getenv("NEOVIM")
	if editor == "" {
		editor = os.Getenv("EDITOR")
		if editor == "" {
			editor = "nvim"
		}
	}
	cmd := exec.Command(editor, path)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fatal("failed to launch editor:", err)
		os.Exit(1)
	}
}
