package main

import (
	"bytes"
	"fmt"
	"nvm/web"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/blang/semver"
	"github.com/coreybutler/go-fsutil"
	"github.com/gen2brain/dlgs"
	"golang.org/x/sys/windows/registry"
)

var version = "1.1.11"

func main() {
	// baseVersion := version
	args := os.Args

	if len(args) > 1 {
		version = args[1]
	}

	root := os.Getenv("NVM_HOME")
	if root == "" {
		fmt.Println("Cannot find NVM_HOME")
		os.Exit(1)
	}

	exe := filepath.Join(root, "nvm.exe")
	currentNvmVersion, err := semver.Make(strings.TrimSpace(run(exe, "version")))
	if err != nil {
		fmt.Println("NVM for Windows installation not found in " + root)
		os.Exit(1)
	}

	err = currentNvmVersion.Validate()
	if err != nil {
		fmt.Println("NVM for Windows installation not found in " + root)
		os.Exit(1)
	}

	if !contains(args, "/S") && !contains(args, "/s") {
		item, _, err := dlgs.Entry("NVM Upgrade", "Upgrade to which version?", version)
		if err != nil || len(strings.TrimSpace(item)) == 0 {
			fmt.Println("Upgrade cancelled")
			os.Exit(0)
		}
		version = item
	}

	newNvmVersion, err := semver.Make(version)
	if err != nil {
		fmt.Println("Version " + version + " is not recognized or does not exist")
		os.Exit(1)
	}

	err = newNvmVersion.Validate()
	if err != nil {
		fmt.Println("Invalid version: " + version)
		os.Exit(1)
	}

	if newNvmVersion.LTE(currentNvmVersion) {
		fmt.Printf("No upgrade necessary. Already running v%s.", currentNvmVersion.String())
		os.Exit(0)
	}

	tmpdir := filepath.Join(root, "tmp")
	zipfile := filepath.Join(tmpdir, "install.zip")

	os.RemoveAll(tmpdir)
	fsutil.Touch(tmpdir)

	fmt.Println("Downloading NVM for Windows v" + version)
	success := web.Download("https://github.com/coreybutler/nvm-windows/releases/download/"+version+"/nvm-noinstall.zip", zipfile)
	if !success {
		os.RemoveAll(tmpdir)
		os.Exit(1)
	}

	fmt.Println(" - Extracting")
	web.Unzip(zipfile, tmpdir)
	os.RemoveAll(zipfile)
	fmt.Println(" - Updating")
	fsutil.Move(tmpdir, root)
	os.RemoveAll(tmpdir)

	version := strings.TrimSpace(run(exe, "version"))
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\40078385-F676-4C61-9A9C-F9028599D6D3_is1`, registry.QUERY_VALUE)
	if err == nil {
		defer key.Close()
		key.SetStringValue("DisplayVersion", version)
		key.SetStringValue("DisplayName", "NVM for Windows "+version)

		current := time.Now()
		key.SetStringValue("InstallDate", current.Format("20060102"))
	}

	fmt.Printf("\nUpgraded to NVM for Windows v%v", version)
}

func run(command ...string) string {
	base := command[0]
	args := command[1:]
	cmd := exec.Command(base, args...)

	var out bytes.Buffer
	cmd.Stdout = &out

	err := cmd.Run()

	if err != nil {
		return err.Error()
	}

	return out.String()
}

func contains(src []string, pattern string) bool {
	for _, arg := range src {
		if arg == pattern {
			return true
		}
	}

	return false
}
