package main

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/url"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"nvm/arch"
	"nvm/encoding"
	"nvm/file"
	"nvm/node"
	"nvm/web"

	"github.com/blang/semver"
	// "github.com/fatih/color"
	"github.com/coreybutler/go-where"
	"github.com/olekukonko/tablewriter"
	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

const (
	NvmVersion = "1.1.11"
)

type Environment struct {
	settings        string
	root            string
	symlink         string
	arch            string
	node_mirror     string
	npm_mirror      string
	proxy           string
	originalpath    string
	originalversion string
	verifyssl       bool
}

var home = filepath.Clean(os.Getenv("NVM_HOME") + "\\settings.txt")
var symlink = filepath.Clean(os.Getenv("NVM_SYMLINK"))

var env = &Environment{
	settings:        home,
	root:            "",
	symlink:         symlink,
	arch:            os.Getenv("PROCESSOR_ARCHITECTURE"),
	node_mirror:     "",
	npm_mirror:      "",
	proxy:           "none",
	originalpath:    "",
	originalversion: "",
	verifyssl:       true,
}

func main() {
	args := os.Args
	detail := ""
	procarch := arch.Validate(env.arch)

	if !isTerminal() {
		alert("NVM for Windows should be run from a terminal such as CMD or PowerShell.", "Terminal Only")
		os.Exit(0)
	}

	// Capture any additional arguments
	if len(args) > 2 {
		detail = args[2]
	}
	if len(args) > 3 {
		if args[3] == "32" || args[3] == "64" {
			procarch = args[3]
		}
	}
	if len(args) < 2 {
		help()
		return
	}

	if args[1] != "version" && args[1] != "--version" && args[1] != "v" && args[1] != "-v" && args[1] != "--v" {
		setup()
	}

	// Run the appropriate method
	switch args[1] {
	case "install":
		install(detail, procarch)
	case "uninstall":
		uninstall(detail)
	case "use":
		use(detail, procarch)
	case "list":
		list(detail)
	case "ls":
		list(detail)
	case "on":
		enable()
	case "off":
		disable()
	case "root":
		if len(args) == 3 {
			updateRootDir(args[2])
		} else {
			fmt.Println("\nCurrent Root: " + env.root)
		}
	case "v":
		fmt.Println(NvmVersion)
	case "--version":
		fallthrough
	case "--v":
		fallthrough
	case "-v":
		fallthrough
	case "version":
		fmt.Println(NvmVersion)
	case "arch":
		if strings.Trim(detail, " \r\n") != "" {
			detail = strings.Trim(detail, " \r\n")
			if detail != "32" && detail != "64" {
				fmt.Println("\"" + detail + "\" is an invalid architecture. Use 32 or 64.")
				return
			}
			env.arch = detail
			saveSettings()
			fmt.Println("Default architecture set to " + detail + "-bit.")
			return
		}
		_, a := node.GetCurrentVersion()
		fmt.Println("System Default: " + env.arch + "-bit.")
		fmt.Println("Currently Configured: " + a + "-bit.")
	case "proxy":
		if detail == "" {
			fmt.Println("Current proxy: " + env.proxy)
		} else {
			env.proxy = detail
			saveSettings()
		}
	case "current":
		inuse, _ := node.GetCurrentVersion()
		v, _ := semver.Make(inuse)
		err := v.Validate()

		if err != nil {
			fmt.Println(inuse)
		} else if inuse == "Unknown" {
			fmt.Println("No current version. Run 'nvm use x.x.x' to set a version.")
		} else {
			fmt.Println("v" + inuse)
		}

	//case "update": update()
	case "node_mirror":
		setNodeMirror(detail)
	case "npm_mirror":
		setNpmMirror(detail)
	case "debug":
		checkLocalEnvironment()
	default:
		help()
	}
}

// ===============================================================
// BEGIN | CLI functions
// ===============================================================
func setNodeMirror(uri string) {
	env.node_mirror = uri
	saveSettings()
}

func setNpmMirror(uri string) {
	env.npm_mirror = uri
	saveSettings()
}

func isTerminal() bool {
	fileInfo, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (fileInfo.Mode() & os.ModeCharDevice) != 0
}

// const (
// 	MB_YESNOCANCEL     = 0x00000003
// 	MB_ICONINFORMATION = 0x00000040
// 	IDYES              = 6
// 	IDNO               = 7
// 	IDCANCEL           = 2
// )

// func openTerminal(msg string, caption ...string) {
// 	title := "Alert"
// 	if len(caption) > 0 {
// 		title = caption[0]
// 	}

// 	labels := []string{"Open CMD", "Open PowerShell", "Close"}
// 	var buttons []*uint16
// 	for _, label := range labels {
// 		buttons = append(buttons, syscall.StringToUTF16Ptr(label))
// 	}
// 	buttons = append(buttons, nil)

// 	user32 := windows.NewLazySystemDLL("user32.dll")
// 	mbox := user32.NewProc("MessageBoxW")

// 	ret, _, _ := mbox.Call(
// 		uintptr(0),
// 		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(msg))),
// 		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(title))),
// 		MB_YESNOCANCEL|MB_ICONINFORMATION,
// 		uintptr(0),
// 		uintptr(unsafe.Pointer(&buttons[0])),
// 	)

// 	getActiveWindow := user32.NewProc("GetActiveWindow")
// 	activeWindow, _, _ := getActiveWindow.Call()
// 	hwnd := windows.Handle(activeWindow)

// 	// Command to open the program or file

// 	switch ret {
// 	case IDYES:
// 		cmd := exec.Command("cmd", "/C", "start", "cmd", "/K", "echo Run \"nvm\" for help...")
// 		err := cmd.Start()
// 		if err != nil {
// 			log.Fatal(err)
// 		}
// 	case IDNO:
// 		cmd := exec.Command("cmd", "/C", "start", "powershell", "/K", "echo Run \"nvm\" for help...")
// 		err := cmd.Start()
// 		if err != nil {
// 			log.Fatal(err)
// 		}
// 	case IDCANCEL:
// 		fmt.Println("User clicked 'Custom Cancel'")
// 		// Handle 'Custom Cancel' button click here
// 	default:
// 		fmt.Println("User closed the message box")
// 		// Handle message box close event here
// 	}

// 	postMessage := user32.NewProc("PostMessageW")
// 	wmClose := 0x0010
// 	_, _, _ = postMessage.Call(
// 		uintptr(hwnd),
// 		uintptr(wmClose),
// 		0,
// 		0,
// 	)
// }

func alert(msg string, caption ...string) {
	user32 := windows.NewLazySystemDLL("user32.dll")
	mbox := user32.NewProc("MessageBoxW")
	getForegroundWindow := user32.NewProc("GetForegroundWindow")
	var hwnd uintptr
	ret, _, _ := getForegroundWindow.Call()
	if ret != 0 {
		hwnd = ret
	}

	title := "Alert"
	if len(caption) > 0 {
		title = caption[0]
	}

	mbox.Call(hwnd, uintptr(unsafe.Pointer(windows.StringToUTF16Ptr(msg))), uintptr(unsafe.Pointer(windows.StringToUTF16Ptr(title))), uintptr(windows.MB_OK))
}

/*
func update() {
  cmd := exec.Command("cmd", "/d", "echo", "testing")
  var output bytes.Buffer
  var _stderr bytes.Buffer
  cmd.Stdout = &output
  cmd.Stderr = &_stderr
  perr := cmd.Run()
  if perr != nil {
      fmt.Println(fmt.Sprint(perr) + ": " + _stderr.String())
      return
  }
}
*/

func getVersion(version string, cpuarch string, localInstallsOnly ...bool) (string, string, error) {
	requestedVersion := version
	cpuarch = strings.ToLower(cpuarch)

	if cpuarch != "" {
		if cpuarch != "32" && cpuarch != "64" && cpuarch != "all" {
			return version, cpuarch, errors.New("\"" + cpuarch + "\" is not a valid CPU architecture. Must be 32 or 64.")
		}
	} else {
		cpuarch = env.arch
	}

	if cpuarch != "all" {
		cpuarch = arch.Validate(cpuarch)
	}

	if version == "" {
		return "", cpuarch, errors.New("A version argument is required but missing.")
	}

	// If user specifies "latest" version, find out what version is
	if version == "latest" || version == "node" {
		version = getLatest()
		fmt.Println(version)
	}

	if version == "lts" {
		version = getLTS()
	}

	if version == "newest" {
		installed := node.GetInstalled(env.root)
		if len(installed) == 0 {
			return version, "", errors.New("No versions of node.js found. Try installing the latest by typing nvm install latest.")
		}

		version = installed[0]
	}

	if version == "32" || version == "64" {
		cpuarch = version
		v, _ := node.GetCurrentVersion()
		version = v
	}

	version = versionNumberFrom(version)
	v, err := semver.Make(version)
	if err == nil {
		err = v.Validate()
	}

	if err == nil {
		// if the user specifies only the major/minor version, identify the latest
		// version applicable to what was provided.
		sv := strings.Split(version, ".")
		if len(sv) < 3 {
			version = findLatestSubVersion(version)
		} else {
			version = cleanVersion(version)
		}

		version = versionNumberFrom(version)
	} else if strings.Contains(err.Error(), "No Major.Minor.Patch") {
		latestLocalInstall := false
		if len(localInstallsOnly) > 0 {
			latestLocalInstall = localInstallsOnly[0]
		}
		version = findLatestSubVersion(version, latestLocalInstall)
		if len(version) == 0 {
			err = errors.New("Unrecognized version: \"" + requestedVersion + "\"")
		}
	}

	return version, cpuarch, err
}

func install(version string, cpuarch string) {
	requestedVersion := version
	args := os.Args
	lastarg := args[len(args)-1]

	if lastarg == "--insecure" {
		env.verifyssl = false
	}

	if strings.HasPrefix(version, "--") {
		fmt.Println("\"--\" prefixes are unnecessary in NVM for Windows!")
		version = strings.ReplaceAll(version, "-", "")
		fmt.Printf("attempting to install \"%v\" instead...\n\n", version)
		time.Sleep(2 * time.Second)
	}

	v, a, err := getVersion(version, cpuarch)
	version = v
	cpuarch = a

	if err != nil {
		if strings.Contains(err.Error(), "No Major.Minor.Patch") {
			sv, sverr := semver.Make(version)
			if sverr == nil {
				sverr = sv.Validate()
			}
			if sverr != nil {
				version = findLatestSubVersion(version)
				if len(version) == 0 {
					sverr = errors.New("Unrecognized version: \"" + requestedVersion + "\"")
				}
			}
			err = sverr
		}

		if err != nil {
			fmt.Println(err.Error())
			if version == "" {
				fmt.Println(" ")
				help()
			}
			return
		}
	}

	if err != nil {
		fmt.Println("\"" + requestedVersion + "\" is not a valid version.")
		fmt.Println("Please use a valid semantic version number, \"lts\", or \"latest\".")
		return
	}

	if checkVersionExceedsLatest(version) {
		fmt.Println("Node.js v" + version + " is not yet released or is not available.")
		return
	}

	if cpuarch == "64" && !web.IsNode64bitAvailable(version) {
		fmt.Println("Node.js v" + version + " is only available in 32-bit.")
		return
	}

	// Check to see if the version is already installed
	if !node.IsVersionInstalled(env.root, version, cpuarch) {
		if !node.IsVersionAvailable(version) {
			url := web.GetFullNodeUrl("index.json")
			fmt.Println("\nVersion " + version + " is not available.\n\nThe complete list of available versions can be found at " + url)
			return
		}

		// Make the output directories
		os.Mkdir(filepath.Join(env.root, "v"+version), os.ModeDir)
		os.Mkdir(filepath.Join(env.root, "v"+version, "node_modules"), os.ModeDir)

		// Warn the user if they're attempting to install without verifying the remote SSL cert
		if !env.verifyssl {
			fmt.Println("\nWARNING: The remote SSL certificate will not be validated during the download process.\n")
		}

		// Download node
		append32 := node.IsVersionInstalled(env.root, version, "64")
		append64 := node.IsVersionInstalled(env.root, version, "32")
		if (cpuarch == "32" || cpuarch == "all") && !node.IsVersionInstalled(env.root, version, "32") {
			success := web.GetNodeJS(env.root, version, "32", append32)
			if !success {
				os.RemoveAll(filepath.Join(env.root, "v"+version, "node_modules"))
				fmt.Println("Could not download node.js v" + version + " 32-bit executable.")
				return
			}
		}
		if (cpuarch == "64" || cpuarch == "all") && !node.IsVersionInstalled(env.root, version, "64") {
			success := web.GetNodeJS(env.root, version, "64", append64)
			if !success {
				os.RemoveAll(filepath.Join(env.root, "v"+version, "node_modules"))
				fmt.Println("Could not download node.js v" + version + " 64-bit executable.")
				return
			}
		}

		if file.Exists(filepath.Join(env.root, "v"+version, "node_modules", "npm")) {
			npmv := getNpmVersion(version)
			fmt.Println("npm v" + npmv + " installed successfully.")
			fmt.Println("\n\nInstallation complete. If you want to use this version, type\n\nnvm use " + version)
			return
		}

		// If successful, add npm
		npmv := getNpmVersion(version)
		success := web.GetNpm(env.root, getNpmVersion(version))
		if success {
			fmt.Printf("Installing npm v" + npmv + "...")

			// new temp directory under the nvm root
			tempDir := filepath.Join(env.root, "temp")

			// Extract npm to the temp directory
			err := file.Unzip(filepath.Join(tempDir, "npm-v"+npmv+".zip"), filepath.Join(tempDir, "nvm-npm"))

			// Copy the npm and npm.cmd files to the installation directory
			tempNpmBin := filepath.Join(tempDir, "nvm-npm", "cli-"+npmv, "bin")

			// Support npm < 6.2.0
			if file.Exists(tempNpmBin) == false {
				tempNpmBin = filepath.Join(tempDir, "nvm-npm", "npm-"+npmv, "bin")
			}

			if file.Exists(tempNpmBin) == false {
				log.Fatal("Failed to extract npm. Could not find " + tempNpmBin)
			}

			// Standard npm support
			os.Rename(filepath.Join(tempNpmBin, "npm"), filepath.Join(env.root, "v"+version, "npm"))
			os.Rename(filepath.Join(tempNpmBin, "npm.cmd"), filepath.Join(env.root, "v"+version, "npm.cmd"))

			// npx support
			if _, err := os.Stat(filepath.Join(tempNpmBin, "npx")); err == nil {
				os.Rename(filepath.Join(tempNpmBin, "npx"), filepath.Join(env.root, "v"+version, "npx"))
				os.Rename(filepath.Join(tempNpmBin, "npx.cmd"), filepath.Join(env.root, "v"+version, "npx.cmd"))
			}

			npmSourcePath := filepath.Join(tempDir, "nvm-npm", "npm-"+npmv)

			if file.Exists(npmSourcePath) == false {
				npmSourcePath = filepath.Join(tempDir, "nvm-npm", "cli-"+npmv)
			}

			moveNpmErr := os.Rename(npmSourcePath, filepath.Join(env.root, "v"+version, "node_modules", "npm"))
			if moveNpmErr != nil {
				// sometimes Windows can take some time to enable access to large amounts of files after unzip, use exponential backoff to wait until it is ready
				for _, i := range [5]int{1, 2, 4, 8, 16} {
					time.Sleep(time.Duration(i) * time.Second)
					moveNpmErr = os.Rename(npmSourcePath, filepath.Join(env.root, "v"+version, "node_modules", "npm"))
					if moveNpmErr == nil {
						break
					}
				}

			}

			if err == nil && moveNpmErr == nil {
				// Remove the temp directory
				// may consider keep the temp files here
				os.RemoveAll(tempDir)

				fmt.Println("\n\nInstallation complete. If you want to use this version, type\n\nnvm use " + version)
			} else if moveNpmErr != nil {
				fmt.Println("Error: Unable to move directory " + npmSourcePath + " to node_modules: " + moveNpmErr.Error())
			} else {
				fmt.Println("Error: Unable to install NPM: " + err.Error())
			}
		} else {
			fmt.Println("Could not download npm for node v" + version + ".")
			fmt.Println("Please visit https://github.com/npm/cli/releases/tag/v" + npmv + " to download npm.")
			fmt.Println("It should be extracted to " + env.root + "\\v" + version)
		}

		// Reset the SSL verification
		env.verifyssl = true

		// If this is ever shipped for Mac, it should use homebrew.
		// If this ever ships on Linux, it should be on bintray so it can use yum, apt-get, etc.
		return
	} else {
		fmt.Println("Version " + version + " is already installed.")
		return
	}

}

func uninstall(version string) {
	// Make sure a version is specified
	if len(version) == 0 {
		fmt.Println("Provide the version you want to uninstall.")
		help()
		return
	}

	if strings.ToLower(version) == "latest" || strings.ToLower(version) == "node" {
		version = getLatest()
	} else if strings.ToLower(version) == "lts" {
		version = getLTS()
	} else if strings.ToLower(version) == "newest" {
		installed := node.GetInstalled(env.root)
		if len(installed) == 0 {
			fmt.Println("No versions of node.js found. Try installing the latest by typing nvm install latest.")
			return
		}

		version = installed[0]
	}

	version = cleanVersion(version)

	// Determine if the version exists and skip if it doesn't
	if node.IsVersionInstalled(env.root, version, "32") || node.IsVersionInstalled(env.root, version, "64") {
		fmt.Printf("Uninstalling node v" + version + "...")
		v, _ := node.GetCurrentVersion()
		if v == version {
			// _, err := runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`, filepath.Join(env.root, "elevate.cmd"), filepath.Clean(env.symlink)))
			_, err := elevatedRun("rmdir", filepath.Clean(env.symlink))
			if err != nil {
				fmt.Println(fmt.Sprint(err))
				return
			}
		}
		e := os.RemoveAll(filepath.Join(env.root, "v"+version))
		if e != nil {
			fmt.Println("Error removing node v" + version)
			fmt.Println("Manually remove " + filepath.Join(env.root, "v"+version) + ".")
		} else {
			fmt.Printf(" done")
		}
	} else {
		fmt.Println("node v" + version + " is not installed. Type \"nvm list\" to see what is installed.")
	}
	return
}

func versionNumberFrom(version string) string {
	reg, _ := regexp.Compile("[^0-9]")

	if reg.MatchString(version[:1]) {
		if version[0:1] != "v" {
			url := web.GetFullNodeUrl("latest-" + version + "/SHASUMS256.txt")
			content := strings.Split(web.GetRemoteTextFile(url), "\n")[0]
			if strings.Contains(content, "node") {
				parts := strings.Split(content, "-")
				if len(parts) > 1 {
					if parts[1][0:1] == "v" {
						return parts[1][1:]
					}
				}
			}
			fmt.Printf("\"%v\" is not a valid version or known alias.\n", version)
			fmt.Println("\nAvailable aliases: latest, node (latest), lts\nNamed releases (boron, dubnium, etc) are also supported.")
			os.Exit(0)
		}
	}

	for reg.MatchString(version[:1]) {
		version = version[1:]
	}

	return version
}

func splitVersion(version string) map[string]int {
	parts := strings.Split(version, ".")
	var result = make([]int, 3)

	for i, item := range parts {
		v, _ := strconv.Atoi(item)
		result[i] = v
	}

	return map[string]int{
		"major": result[0],
		"minor": result[1],
		"patch": result[2],
	}
}

func findLatestSubVersion(version string, localOnly ...bool) string {
	if len(localOnly) > 0 && localOnly[0] {
		installed := node.GetInstalled(env.root)
		result := ""
		for _, v := range installed {
			if strings.HasPrefix(v, "v"+version) {
				if result != "" {
					current, _ := semver.New(versionNumberFrom(result))
					next, _ := semver.New(versionNumberFrom(v))
					if current.LT(*next) {
						result = v
					}
				} else {
					result = v
				}
			}
		}

		if len(strings.TrimSpace(result)) > 0 {
			return versionNumberFrom(result)
		}
	}

	if len(strings.Split(version, ".")) == 2 {
		all, _, _, _, _, _ := node.GetAvailable()
		requested := splitVersion(version + ".0")
		for _, v := range all {
			available := splitVersion(v)
			if requested["major"] == available["major"] {
				if requested["minor"] == available["minor"] {
					if available["patch"] > requested["patch"] {
						requested["patch"] = available["patch"]
					}
				}
				if requested["minor"] > available["minor"] {
					break
				}
			}

			if requested["major"] > available["major"] {
				break
			}
		}
		return fmt.Sprintf("%v.%v.%v", requested["major"], requested["minor"], requested["patch"])
	}

	url := web.GetFullNodeUrl("latest-v" + version + ".x" + "/SHASUMS256.txt")
	content := web.GetRemoteTextFile(url)
	re := regexp.MustCompile("node-v(.+)+msi")
	reg := regexp.MustCompile("node-v|-[xa].+")
	latest := reg.ReplaceAllString(re.FindString(content), "")
	return latest
}

func accessDenied(err error) bool {
	fmt.Println(fmt.Sprintf("%v", err))

	if strings.Contains(strings.ToLower(err.Error()), "access is denied") {
		fmt.Println("See https://bit.ly/nvm4w-help")
		return true
	}

	return false
}

func use(version string, cpuarch string, reload ...bool) {
	version, cpuarch, err := getVersion(version, cpuarch, true)

	if err != nil {
		if !strings.Contains(err.Error(), "No Major.Minor.Patch") {
			fmt.Println(err.Error())
			return
		}
	}

	// Make sure the version is installed. If not, warn.
	if !node.IsVersionInstalled(env.root, version, cpuarch) {
		fmt.Println("node v" + version + " (" + cpuarch + "-bit) is not installed.")
		if cpuarch == "32" {
			if node.IsVersionInstalled(env.root, version, "64") {
				fmt.Println("\nDid you mean node v" + version + " (64-bit)?\nIf so, type \"nvm use " + version + " 64\" to use it.")
			}
		}
		if cpuarch == "64" {
			if node.IsVersionInstalled(env.root, version, "32") {
				fmt.Println("\nDid you mean node v" + version + " (32-bit)?\nIf so, type \"nvm use " + version + " 32\" to use it.")
			}
		}
		return
	}

	// Remove symlink if it already exists
	sym, _ := os.Lstat(env.symlink)
	if sym != nil {
		// _, err := runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`, filepath.Join(env.root, "elevate.cmd"), filepath.Clean(env.symlink)))
		_, err := elevatedRun("rmdir", filepath.Clean(env.symlink))
		if err != nil {
			if accessDenied(err) {
				return
			}
		}

		// // Return if the symlink already exists
		// if ok {
		// 	fmt.Print(err)
		// 	return
		// }
	}

	// Create new symlink
	var ok bool
	// ok, err = runElevated(fmt.Sprintf(`"%s" cmd /C mklink /D "%s" "%s"`, filepath.Join(env.root, "elevate.cmd"), filepath.Clean(env.symlink), filepath.Join(env.root, "v"+version)))
	ok, err = elevatedRun("mklink", "/D", filepath.Clean(env.symlink), filepath.Join(env.root, "v"+version))
	if err != nil {
		if strings.Contains(err.Error(), "not have sufficient privilege") || strings.Contains(strings.ToLower(err.Error()), "access is denied") {
			// cmd := exec.Command(filepath.Join(env.root, "elevate.cmd"), "cmd", "/C", "mklink", "/D", filepath.Clean(env.symlink), filepath.Join(env.root, "v"+version))
			// var output bytes.Buffer
			// var _stderr bytes.Buffer
			// cmd.Stdout = &output
			// cmd.Stderr = &_stderr
			// perr := cmd.Run()
			ok, err = elevatedRun("mklink", "/D", filepath.Clean(env.symlink), filepath.Join(env.root, "v"+version))

			if err != nil {
				ok = false
				fmt.Println(fmt.Sprint(err)) // + ": " + _stderr.String())
			} else {
				ok = true
			}
		} else if strings.Contains(err.Error(), "file already exists") {
			ok, err = elevatedRun("rmdir", filepath.Clean(env.symlink))
			// ok, err = runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`, filepath.Join(env.root, "elevate.cmd"), filepath.Clean(env.symlink)))
			reloadable := true
			if len(reload) > 0 {
				reloadable = reload[0]
			}
			if err != nil {
				fmt.Println(fmt.Sprint(err))
			} else if reloadable {
				use(version, cpuarch, false)
				return
			}
		} else {
			fmt.Print(fmt.Sprint(err))
		}
	}
	if !ok {
		return
	}

	// Use the assigned CPU architecture
	cpuarch = arch.Validate(cpuarch)
	nodepath := filepath.Join(env.root, "v"+version, "node.exe")
	node32path := filepath.Join(env.root, "v"+version, "node32.exe")
	node64path := filepath.Join(env.root, "v"+version, "node64.exe")
	node32exists := file.Exists(node32path)
	node64exists := file.Exists(node64path)
	nodeexists := file.Exists(nodepath)
	if node32exists && cpuarch == "32" { // user wants 32, but node.exe is 64
		if nodeexists {
			os.Rename(nodepath, node64path) // node.exe -> node64.exe
		}
		os.Rename(node32path, nodepath) // node32.exe -> node.exe
	}
	if node64exists && cpuarch == "64" { // user wants 64, but node.exe is 32
		if nodeexists {
			os.Rename(nodepath, node32path) // node.exe -> node32.exe
		}
		os.Rename(node64path, nodepath) // node64.exe -> node.exe
	}
	fmt.Println("Now using node v" + version + " (" + cpuarch + "-bit)")
}

func useArchitecture(a string) {
	if strings.ContainsAny("32", os.Getenv("PROCESSOR_ARCHITECTURE")) {
		fmt.Println("This computer only supports 32-bit processing.")
		return
	}
	if a == "32" || a == "64" {
		env.arch = a
		saveSettings()
		fmt.Println("Set to " + a + "-bit mode")
	} else {
		fmt.Println("Cannot set architecture to " + a + ". Must be 32 or 64 are acceptable values.")
	}
}

func list(listtype string) {
	if listtype == "" {
		listtype = "installed"
	}
	if listtype != "installed" && listtype != "available" {
		fmt.Println("\nInvalid list option.\n\nPlease use on of the following\n  - nvm list\n  - nvm list installed\n  - nvm list available")
		help()
		return
	}

	if listtype == "installed" {
		fmt.Println("")
		inuse, a := node.GetCurrentVersion()

		v := node.GetInstalled(env.root)

		for i := 0; i < len(v); i++ {
			version := v[i]
			isnode, _ := regexp.MatchString("v", version)
			str := ""
			if isnode {
				if "v"+inuse == version {
					str = str + "  * "
				} else {
					str = str + "    "
				}
				str = str + regexp.MustCompile("v").ReplaceAllString(version, "")
				if "v"+inuse == version {
					str = str + " (Currently using " + a + "-bit executable)"
					//            str = ansi.Color(str,"green:black")
				}
				fmt.Printf(str + "\n")
			}
		}
		if len(v) == 0 {
			fmt.Println("No installations recognized.")
		}
	} else {
		_, lts, current, stable, unstable, _ := node.GetAvailable()

		releases := 20

		data := make([][]string, releases, releases+5)
		for i := 0; i < releases; i++ {
			release := make([]string, 4, 6)

			release[0] = ""
			release[1] = ""
			release[2] = ""
			release[3] = ""

			if len(current) > i {
				if len(current[i]) > 0 {
					release[0] = current[i]
				}
			}

			if len(lts) > i {
				if len(lts[i]) > 0 {
					release[1] = lts[i]
				}
			}

			if len(stable) > i {
				if len(stable[i]) > 0 {
					release[2] = stable[i]
				}
			}

			if len(unstable) > i {
				if len(unstable[i]) > 0 {
					release[3] = unstable[i]
				}
			}

			data[i] = release
		}

		fmt.Println("")
		table := tablewriter.NewWriter(os.Stdout)
		table.SetHeader([]string{"   Current  ", "    LTS     ", " Old Stable ", "Old Unstable"})
		table.SetBorders(tablewriter.Border{Left: true, Top: false, Right: true, Bottom: false})
		table.SetAlignment(tablewriter.ALIGN_CENTER)
		table.SetCenterSeparator("|")
		table.AppendBulk(data) // Add Bulk Data
		table.Render()

		fmt.Println("\nThis is a partial list. For a complete list, visit https://nodejs.org/en/download/releases")
	}
}

func enable() {
	dir := ""
	files, _ := ioutil.ReadDir(env.root)
	for _, f := range files {
		if f.IsDir() {
			isnode, _ := regexp.MatchString("v", f.Name())
			if isnode {
				dir = f.Name()
			}
		}
	}
	fmt.Println("nvm enabled")
	if dir != "" {
		use(strings.Trim(regexp.MustCompile("v").ReplaceAllString(dir, ""), " \n\r"), env.arch)
	} else {
		fmt.Println("No versions of node.js found. Try installing the latest by typing nvm install latest")
	}
}

func disable() {
	// ok, err := runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`, filepath.Join(env.root, "elevate.cmd"), filepath.Clean(env.symlink)))
	ok, err := elevatedRun("rmdir", filepath.Clean(env.symlink))
	if !ok {
		return
	}
	if err != nil {
		fmt.Print(fmt.Sprint(err))
	}

	fmt.Println("nvm disabled")
}

const (
	VER_PLATFORM_WIN32s        = 0
	VER_PLATFORM_WIN32_WINDOWS = 1
	VER_PLATFORM_WIN32_NT      = 2
)

type OSVersionInfoEx struct {
	OSVersionInfoSize uint32
	MajorVersion      uint32
	MinorVersion      uint32
	BuildNumber       uint32
	PlatformId        uint32
	CSDVersion        [128]uint16
}

func checkLocalEnvironment() {
	problems := make([]string, 0)

	// Check for PATH problems
	paths := strings.Split(os.Getenv("PATH"), ";")
	current := env.symlink
	if strings.HasSuffix(current, "/") || strings.HasSuffix(current, "\\") {
		current = current[:len(current)-1]
	}

	nvmsymlinkfound := false
	for _, path := range paths {
		if strings.HasSuffix(path, "/") || strings.HasSuffix(path, "\\") {
			path = path[:len(path)-1]
		}

		if strings.EqualFold(path, current) {
			nvmsymlinkfound = true
			break
		}

		if _, err := os.Stat(filepath.Join(path, "node.exe")); err == nil {
			problems = append(problems, "Another Node.js installation is blocking NVM4W installations from running. Please uninstall the conflicting version or update the PATH environment variable to assure \""+current+"\" precedes \""+path+"\".")
			break
		} else if !errors.Is(err, os.ErrNotExist) {
			fmt.Println("Error running environment check:\n" + err.Error())
		}
	}

	// Check for developer mode
	devmode := "OFF"
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`, registry.QUERY_VALUE)
	if err == nil {
		value, _, err := k.GetIntegerValue("AllowDevelopmentWithoutDevLicense")
		if err == nil {
			if value > 0 {
				devmode = "ON"
			}
		} else {
			devmode = "UNKNOWN"
		}
	} else {
		devmode = "UNKNOWN (user cannot read registry)"
	}
	defer k.Close()

	// Check for permission problems
	admin, elevated, err := getProcessPermissions()
	if err == nil {
		if !admin && !elevated {
			user, _ := user.Current()
			username := strings.Split(user.Username, "\\")
			fmt.Printf("%v is not using admin or elevated rights", username[len(username)-1])
			if devmode == "ON" {
				fmt.Printf(", but windows developer mode is\nenabled. Most commands will still work unless %v lacks rights to\nmodify the %v symlink.\n", username[len(username)-1], current)
			} else {
				fmt.Println(".")
			}
		} else {
			if admin {
				fmt.Println("Running NVM for Windows with administrator privileges.")
			} else if elevated {
				fmt.Println("Running NVM for Windows with elevated permissions.")
			}
		}
	} else {
		fmt.Println(err)
	}

	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	handle, _, err := kernel32.NewProc("GetStdHandle").Call(uintptr(0xfffffff5)) // get handle for console input
	if err != nil && err.Error() != "The operation completed successfully." {
		fmt.Printf("Error getting console handle: %v", err)
	} else {
		var mode uint32
		result, _, _ := kernel32.NewProc("GetConsoleMode").Call(handle, uintptr(unsafe.Pointer(&mode)))
		if result != 0 {
			var title [256]uint16
			_, _, err := kernel32.NewProc("GetConsoleTitleW").Call(uintptr(unsafe.Pointer(&title)), uintptr(len(title)))
			if err != nil && err.Error() != "The operation completed successfully." {
				fmt.Printf("Error getting console title: %v", err)
			} else {
				consoleTitle := syscall.UTF16ToString(title[:])

				if !strings.Contains(strings.ToLower(consoleTitle), "command prompt") && !strings.Contains(strings.ToLower(consoleTitle), "powershell") {
					problems = append(problems, fmt.Sprintf("\"%v\" is not an officially supported shell. Some features may not work as expected.\n", consoleTitle))
				}

				fmt.Printf("\n%v", consoleTitle)
			}
		}
	}

	// Get Windows details
	getVersionEx := kernel32.NewProc("GetVersionExW")
	versionInfo := OSVersionInfoEx{
		OSVersionInfoSize: uint32(unsafe.Sizeof(OSVersionInfoEx{})),
	}
	ret, _, _ := getVersionEx.Call(uintptr(unsafe.Pointer(&versionInfo)))
	if ret == 0 {
		fmt.Println("Failed to retrieve version information.")
	}
	// fmt.Printf(" %d.%d\n", versionInfo.MajorVersion, versionInfo.MinorVersion)
	maj, min, patch := windows.RtlGetNtVersionNumbers()
	fmt.Printf("\nWindows Version: %d.%d (Build %d)\n", maj, min, patch)

	// SHELL in Linux
	// TERM in Windows
	// COMSPEC in Windows provides the terminal path
	// shell := os.Getenv("ConEmuANSI")
	// fmt.Printf("Shell: %v\n", shell)

	// Display developer mode status
	if !admin {
		// if devmode == "ON" {
		// 	devmode = color.GreenString(devmode)
		// } else if devmode == "OFF" {
		// 	devmode = color.YellowString(devmode)
		// } else {
		// 	devmode = color.YellowString(devmode)
		// }

		fmt.Printf("\n%v %v\n", "Windows Developer Mode:", devmode)
	}

	executable := os.Args[0]
	path, err := where.Find(filepath.Base(executable))

	if err != nil {
		path = "UNKNOWN: " + err.Error()
	}

	out := "none\n(run \"nvm use <version>\" to activate a version)\n"
	output, err := exec.Command(os.Getenv("NVM_SYMLINK")+"\\node.exe", "-v").Output()
	if err == nil {
		out = string(output)
	}

	v := node.GetInstalled(env.root)

	nvmhome := os.Getenv("NVM_HOME")
	fmt.Printf("\nNVM4W Version:      %v\nNVM4W Path:         %v\nNVM4W Settings:     %v\nNVM_HOME:           %v\nNVM_SYMLINK:        %v\nNode Installations: %v\n\nTotal Node.js Versions: %v\nActive Node.js Version: %v", NvmVersion, path, home, nvmhome, symlink, env.root, len(v), out)

	if !nvmsymlinkfound {
		problems = append(problems, "The NVM4W symlink ("+env.symlink+") was not found in the PATH environment variable.")
	}

	if home == symlink {
		problems = append(problems, "NVM_HOME and NVM_SYMLINK cannot be the same value ("+symlink+"). Change NVM_SYMLINK.")
	}

	fileInfo, err := os.Lstat(symlink)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("NVM_SYMLINK does not exist yet. This is auto-created when \"nvm use\" is run.")
		} else {
			problems = append(problems, "Could not determine if NVM_SYMLINK is actually a symlink: "+err.Error())
		}
	} else {
		if fileInfo.Mode()&os.ModeSymlink != 0 {
			targetPath, err := os.Readlink(symlink)
			if err != nil {
				fmt.Println(err)
			}

			targetFileInfo, err := os.Lstat(targetPath)

			if !targetFileInfo.Mode().IsDir() {
				problems = append(problems, "NVM_SYMLINK is a symlink linking to a file instead of a directory.")
			}
		} else {
			problems = append(problems, "NVM_SYMLINK ("+symlink+") is not a valid symlink.")
		}
	}

	ipv6, err := web.IsLocalIPv6()
	if err != nil {
		problems = append(problems, "Connection type cannot be determined: "+err.Error())
	} else if !ipv6 {
		fmt.Println("\nIPv6 is enabled. This can slow downloads significantly.")
	}

	nodelist := web.Ping(web.GetFullNodeUrl("index.json"))
	if !nodelist {
		if len(env.node_mirror) > 0 && env.node_mirror != "none" {
			problems = append(problems, "Connection to "+env.node_mirror+" (mirror) cannot be established. Check the mirror server to assure it is online.")
		} else {
			if len(env.proxy) > 0 {
				problems = append(problems, "Connection to nodejs.org cannot be established. Check your proxy ("+env.proxy+") and your physical internet connection.")
			} else {
				problems = append(problems, "Connection to nodejs.org cannot be established. Check your internet connection.")
			}
		}
	}

	invalid := make([]string, 0)
	invalidnpm := make([]string, 0)
	for i := 0; i < len(v); i++ {
		if _, err = os.Stat(filepath.Join(env.root, v[i], "node.exe")); err != nil {
			invalid = append(invalid, v[i])
		} else if _, err = os.Stat(filepath.Join(env.root, v[i], "npm.cmd")); err != nil {
			invalidnpm = append(invalid, v[i])
		}
	}

	if len(invalid) > 0 {
		problems = append(problems, "The following Node installations are invalid (missing node.exe): "+strings.Join(invalid, ", ")+" - consider reinstalling these versions")
	}

	if len(invalidnpm) > 0 {
		fmt.Printf("\nWARNING: The following Node installations are missing npm: %v\n         (Node will still run, but npm will not work on these versions)\n", strings.Join(invalidnpm, ", "))
	}

	if len(env.npm_mirror) > 0 {
		fmt.Println("If you are experiencing npm problems, check the npm mirror (" + env.npm_mirror + ") to assure it is online and accessible.")
	}

	if _, err := os.Stat(env.settings); err != nil {
		problems = append(problems, "Cannot find "+env.settings)
	}

	if len(problems) == 0 {
		fmt.Println("\n" + "No problems detected.")
	} else {
		// fmt.Println("")
		// table := tablewriter.NewWriter(os.Stdout)
		// table.SetHeader([]string{"#", "Problems Detected"})
		// table.SetColMinWidth(1, 40)
		// table.SetAutoWrapText(false)
		// // table.SetBorders(tablewriter.Border{Left: true, Top: false, Right: true, Bottom: false})
		// // table.SetAlignment(tablewriter.ALIGN_LEFT)
		// // table.SetCenterSeparator("|")
		// data := make([][]string, 0)
		// for i := 0; i < len(problems); i++ {
		// 	data = append(data, []string{fmt.Sprintf(" %v ", i+1), problems[i]})
		// }
		// table.AppendBulk(data) // Add Bulk Data
		// table.Render()
		fmt.Println("\nPROBLEMS DETECTED\n-----------------")
		for _, p := range problems {
			fmt.Println(p + "\n")
		}
	}

	fmt.Println("\n" + "Find help at https://github.com/coreybutler/nvm-windows/wiki/Common-Issues")
}

func help() {
	fmt.Println("\nRunning version " + NvmVersion + ".")
	fmt.Println("\nUsage:")
	fmt.Println(" ")
	fmt.Println("  nvm arch                     : Show if node is running in 32 or 64 bit mode.")
	fmt.Println("  nvm current                  : Display active version.")
	fmt.Println("  nvm debug                    : Check the NVM4W process for known problems (troubleshooter).")
	fmt.Println("  nvm install <version> [arch] : The version can be a specific version, \"latest\" for the latest current version, or \"lts\" for the")
	fmt.Println("                                 most recent LTS version. Optionally specify whether to install the 32 or 64 bit version (defaults")
	fmt.Println("                                 to system arch). Set [arch] to \"all\" to install 32 AND 64 bit versions.")
	fmt.Println("                                 Add --insecure to the end of this command to bypass SSL validation of the remote download server.")
	fmt.Println("  nvm list [available]         : List the node.js installations. Type \"available\" at the end to see what can be installed. Aliased as ls.")
	fmt.Println("  nvm on                       : Enable node.js version management.")
	fmt.Println("  nvm off                      : Disable node.js version management.")
	fmt.Println("  nvm proxy [url]              : Set a proxy to use for downloads. Leave [url] blank to see the current proxy.")
	fmt.Println("                                 Set [url] to \"none\" to remove the proxy.")
	fmt.Println("  nvm node_mirror [url]        : Set the node mirror. Defaults to https://nodejs.org/dist/. Leave [url] blank to use default url.")
	fmt.Println("  nvm npm_mirror [url]         : Set the npm mirror. Defaults to https://github.com/npm/cli/archive/. Leave [url] blank to default url.")
	fmt.Println("  nvm uninstall <version>      : The version must be a specific version.")
	//  fmt.Println("  nvm update                   : Automatically update nvm to the latest version.")
	fmt.Println("  nvm use [version] [arch]     : Switch to use the specified version. Optionally use \"latest\", \"lts\", or \"newest\".")
	fmt.Println("                                 \"newest\" is the latest installed version. Optionally specify 32/64bit architecture.")
	fmt.Println("                                 nvm use <arch> will continue using the selected version, but switch to 32/64 bit mode.")
	fmt.Println("  nvm root [path]              : Set the directory where nvm should store different versions of node.js.")
	fmt.Println("                                 If <path> is not set, the current root will be displayed.")
	fmt.Println("  nvm [--]version              : Displays the current running version of nvm for Windows. Aliased as v.")
	fmt.Println(" ")
}

// ===============================================================
// END | CLI functions
// ===============================================================

// ===============================================================
// BEGIN | Utility functions
// ===============================================================
func checkVersionExceedsLatest(version string) bool {
	//content := web.GetRemoteTextFile("http://nodejs.org/dist/latest/SHASUMS256.txt")
	url := web.GetFullNodeUrl("latest/SHASUMS256.txt")
	content := web.GetRemoteTextFile(url)
	re := regexp.MustCompile("node-v(.+)+msi")
	reg := regexp.MustCompile("node-v|-[xa].+")
	latest := reg.ReplaceAllString(re.FindString(content), "")
	var vArr = strings.Split(version, ".")
	var lArr = strings.Split(latest, ".")
	for index := range lArr {
		lat, _ := strconv.Atoi(lArr[index])
		ver, _ := strconv.Atoi(vArr[index])
		//Should check for valid input (checking for conversion errors) but this tool is made to trust the user
		if ver < lat {
			return false
		} else if ver > lat {
			return true
		}
	}
	return false
}

func cleanVersion(version string) string {
	re := regexp.MustCompile("\\d+.\\d+.\\d+")
	matched := re.FindString(version)

	if len(matched) == 0 {
		re = regexp.MustCompile("\\d+.\\d+")
		matched = re.FindString(version)
		if len(matched) == 0 {
			matched = version + ".0.0"
		} else {
			matched = matched + ".0"
		}
		fmt.Println(matched)
	}

	return matched
}

// Given a node.js version, returns the associated npm version
func getNpmVersion(nodeversion string) string {
	_, _, _, _, _, npm := node.GetAvailable()
	return npm[nodeversion]
}

func getLatest() string {
	url := web.GetFullNodeUrl("latest/SHASUMS256.txt")
	content := web.GetRemoteTextFile(url)
	re := regexp.MustCompile("node-v(.+)+msi")
	reg := regexp.MustCompile("node-v|-[xa].+")
	return reg.ReplaceAllString(re.FindString(content), "")
}

func getLTS() string {
	all, ltsList, current, stable, unstable, npm := node.GetAvailable()
	fmt.Println(all)
	fmt.Println(ltsList)
	fmt.Println(current)
	fmt.Println(stable)
	fmt.Println(unstable)
	fmt.Println(npm)
	// _, ltsList, _, _, _, _ := node.GetAvailable()
	// ltsList has already been numerically sorted
	return ltsList[0]
}

func updateRootDir(path string) {
	_, err := os.Stat(path)
	if err != nil {
		fmt.Println(path + " does not exist or could not be found.")
		return
	}

	currentRoot := env.root
	env.root = filepath.Clean(path)

	// Copy command files
	os.Link(filepath.Clean(currentRoot+"/elevate.cmd"), filepath.Clean(env.root+"/elevate.cmd"))
	os.Link(filepath.Clean(currentRoot+"/elevate.vbs"), filepath.Clean(env.root+"/elevate.vbs"))

	saveSettings()

	if currentRoot != env.root {
		fmt.Println("\nRoot has been changed from " + currentRoot + " to " + path)
	}
}

func elevatedRun(name string, arg ...string) (bool, error) {
	ok, err := run("cmd", nil, append([]string{"/C", name}, arg...)...)
	if err != nil {
		ok, err = run("elevate.cmd", &env.root, append([]string{"cmd", "/C", name}, arg...)...)
	}

	return ok, err
}

func run(name string, dir *string, arg ...string) (bool, error) {
	c := exec.Command(name, arg...)
	if dir != nil {
		c.Dir = *dir
	}
	var stderr bytes.Buffer
	c.Stderr = &stderr
	err := c.Run()
	if err != nil {
		return false, errors.New(fmt.Sprint(err) + ": " + stderr.String())
	}

	return true, nil
}

func runElevated(command string, forceUAC ...bool) (bool, error) {
	uac := true //false
	if len(forceUAC) > 0 {
		uac = forceUAC[0]
	}

	if uac {
		// Alternative elevation option at stackoverflow.com/questions/31558066/how-to-ask-for-administer-privileges-on-windows-with-go
		cmd := exec.Command(filepath.Join(env.root, "elevate.cmd"), command)

		var output bytes.Buffer
		var _stderr bytes.Buffer
		cmd.Stdout = &output
		cmd.Stderr = &_stderr
		perr := cmd.Run()
		if perr != nil {
			return false, errors.New(fmt.Sprint(perr) + ": " + _stderr.String())
		}
	}

	c := exec.Command("cmd") // dummy executable that actually needs to exist but we'll overwrite using .SysProcAttr

	// Based on the official docs, syscall.SysProcAttr.CmdLine doesn't exist.
	// But it does and is vital:
	// https://github.com/golang/go/issues/15566#issuecomment-333274825
	// https://medium.com/@felixge/killing-a-child-process-and-all-of-its-children-in-go-54079af94773
	c.SysProcAttr = &syscall.SysProcAttr{CmdLine: command}

	var stderr bytes.Buffer
	c.Stderr = &stderr

	err := c.Run()
	if err != nil {
		msg := stderr.String()
		if strings.Contains(msg, "not have sufficient privilege") && uac {
			return runElevated(command, false)
		}
		// fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
		return false, errors.New(fmt.Sprint(err) + ": " + msg)
	}

	return true, nil
}

func saveSettings() {
	content := "root: " + strings.Trim(encode(env.root), " \n\r") + "\r\narch: " + strings.Trim(encode(env.arch), " \n\r") + "\r\nproxy: " + strings.Trim(encode(env.proxy), " \n\r") + "\r\noriginalpath: " + strings.Trim(encode(env.originalpath), " \n\r") + "\r\noriginalversion: " + strings.Trim(encode(env.originalversion), " \n\r")
	content = content + "\r\nnode_mirror: " + strings.Trim(encode(env.node_mirror), " \n\r") + "\r\nnpm_mirror: " + strings.Trim(encode(env.npm_mirror), " \n\r")
	ioutil.WriteFile(env.settings, []byte(content), 0644)
}

func getProcessPermissions() (admin bool, elevated bool, err error) {
	admin = false
	elevated = false
	var sid *windows.SID
	err = windows.AllocateAndInitializeSid(
		&windows.SECURITY_NT_AUTHORITY,
		2,
		windows.SECURITY_BUILTIN_DOMAIN_RID,
		windows.DOMAIN_ALIAS_RID_ADMINS,
		0, 0, 0, 0, 0, 0,
		&sid)
	if err != nil {
		return
	}
	defer windows.FreeSid(sid)

	token := windows.Token(0)
	elevated = token.IsElevated()
	admin, err = token.IsMember(sid)

	return
}

func encode(val string) string {
	converted := encoding.ToUTF8(val)
	// if err != nil {
	// 	fmt.Printf("WARNING: [encoding error] - %v\n", err.Error())
	// 	return val
	// }

	return string(converted)
}

// ===============================================================
// END | Utility functions
// ===============================================================

func setup() {
	lines, err := file.ReadLines(env.settings)
	if err != nil {
		fmt.Println("\nERROR", err)
		os.Exit(1)
	}

	// Process each line and extract the value
	m := make(map[string]string)
	for _, line := range lines {
		line = strings.TrimSpace(line)
		line = os.ExpandEnv(line)
		res := strings.Split(line, ":")
		if len(res) < 2 {
			continue
		}
		m[res[0]] = strings.TrimSpace(strings.Join(res[1:], ":"))
	}

	if val, ok := m["root"]; ok {
		env.root = filepath.Clean(val)
	}
	if val, ok := m["originalpath"]; ok {
		env.originalpath = filepath.Clean(val)
	}
	if val, ok := m["originalversion"]; ok {
		env.originalversion = val
	}
	if val, ok := m["arch"]; ok {
		env.arch = val
	}
	if val, ok := m["node_mirror"]; ok {
		env.node_mirror = val
	}
	if val, ok := m["npm_mirror"]; ok {
		env.npm_mirror = val
	}

	if val, ok := m["proxy"]; ok {
		if val != "none" && val != "" {
			if strings.ToLower(val[0:4]) != "http" {
				val = "http://" + val
			}
			res, err := url.Parse(val)
			if err == nil {
				web.SetProxy(res.String(), env.verifyssl)
				env.proxy = res.String()
			}
		}
	}

	web.SetMirrors(env.node_mirror, env.npm_mirror)
	env.arch = arch.Validate(env.arch)

	// Make sure the directories exist
	_, e := os.Stat(env.root)
	if e != nil {
		fmt.Println(env.root + " could not be found or does not exist. Exiting.")
		return
	}
}
