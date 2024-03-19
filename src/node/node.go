package node

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"nvm/arch"
	"nvm/file"
	"nvm/web"
	"os"
	"os/exec"
	"regexp"
	"strings"

	// "../semver"
	"github.com/blang/semver"
)

/**
 * Returns version, architecture
 */
func GetCurrentVersion() (string, string) {
	cmd := exec.Command("node", "-v")
	str, err := cmd.Output()
	if err == nil {
		v := strings.Trim(regexp.MustCompile("-.*$").ReplaceAllString(regexp.MustCompile("v").ReplaceAllString(strings.Trim(string(str), " \n\r"), ""), ""), " \n\r")
		cmd := exec.Command("node", "-p", "console.log(process.execPath)")
		str, _ := cmd.Output()
		file := strings.Trim(regexp.MustCompile("undefined").ReplaceAllString(string(str), ""), " \n\r")
		bit := arch.Bit(file)
		if bit == "?" {
			cmd := exec.Command("node", "-e", "console.log(process.arch)")
			str, err := cmd.Output()
			if err == nil {
				if string(str) == "x64" {
					bit = "64"
				} else if string(str) == "arm64" {
					bit = "arm64"
				} else {
					bit = "32"
				}
			} else {
				return v, "Unknown"
			}
		}
		return v, bit
	}
	return "Unknown", ""
}

func IsVersionInstalled(root string, version string, cpu string) bool {
	e32 := file.Exists(root + "\\v" + version + "\\node32.exe")
	e64 := file.Exists(root + "\\v" + version + "\\node64.exe")
	used := file.Exists(root + "\\v" + version + "\\node.exe")
	if cpu == "all" {
		return ((e32 || e64) && used) || e32 && e64
	}
	if file.Exists(root + "\\v" + version + "\\node" + cpu + ".exe") {
		return true
	}
	if ((e32 || e64) && used) || (e32 && e64) {
		return true
	}
	if !e32 && !e64 && used && arch.Validate(cpu) == arch.Bit(root+"\\v"+version+"\\node.exe") {
		return true
	}
	if cpu == "32" {
		return e32
	}
	if cpu == "64" {
		return e64
	}
	return false
}

func IsVersionAvailable(v string) bool {
	// Check the service to make sure the version is available
	avail, _, _, _, _, _ := GetAvailable()

	for _, b := range avail {
		if b == v {
			return true
		}
	}
	return false
}

func reverseStringArray(str []string) []string {
	for i := 0; i < len(str)/2; i++ {
		j := len(str) - i - 1
		str[i], str[j] = str[j], str[i]
	}

	return str
}

func GetInstalled(root string) []string {
	list := make([]semver.Version, 0)
	files, _ := ioutil.ReadDir(root)

	for i := len(files) - 1; i >= 0; i-- {
		if files[i].IsDir() || (files[i].Mode()&os.ModeSymlink == os.ModeSymlink) {
			isnode, _ := regexp.MatchString("v", files[i].Name())

			if isnode {
				currentVersionString := strings.Replace(files[i].Name(), "v", "", 1)
				currentVersion, _ := semver.Make(currentVersionString)

				list = append(list, currentVersion)
			}
		}
	}

	semver.Sort(list)

	loggableList := make([]string, 0)

	for _, version := range list {
		loggableList = append(loggableList, "v"+version.String())
	}

	loggableList = reverseStringArray(loggableList)

	return loggableList
}

// Sorting
type BySemanticVersion []string

func (s BySemanticVersion) Len() int {
	return len(s)
}

func (s BySemanticVersion) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

func (s BySemanticVersion) Less(i, j int) bool {
	v1, _ := semver.Make(s[i])
	v2, _ := semver.Make(s[j])
	return v1.GTE(v2)
}

// Identifies a version as "LTS"
func isLTS(element map[string]interface{}) bool {
	switch datatype := element["lts"].(type) {
	case bool:
		return datatype
	case string:
		return true
	}
	return false
}

// Identifies a version as "current"
func isCurrent(element map[string]interface{}) bool {
	if isLTS(element) {
		return false
	}

	version, _ := semver.Make(element["version"].(string)[1:])
	benchmark, _ := semver.Make("1.0.0")

	if version.LT(benchmark) {
		return false
	}

	return true
	// return version.Major%2 == 1
}

// Identifies a stable old version.
func isStable(element map[string]interface{}) bool {
	if isCurrent(element) {
		return false
	}

	version, _ := semver.Make(element["version"].(string)[1:])

	if version.Major != 0 {
		return false
	}

	return version.Minor%2 == 0
}

// Identifies an unstable old version.
func isUnstable(element map[string]interface{}) bool {
	if isStable(element) {
		return false
	}

	version, _ := semver.Make(element["version"].(string)[1:])

	if version.Major != 0 {
		return false
	}

	return version.Minor%2 != 0
}

// Retrieve the remotely available versions
func GetAvailable() ([]string, []string, []string, []string, []string, map[string]string) {
	all := make([]string, 0)
	lts := make([]string, 0)
	current := make([]string, 0)
	stable := make([]string, 0)
	unstable := make([]string, 0)
	npm := make(map[string]string)
	url := web.GetFullNodeUrl("index.json")

	// Check the service to make sure the version is available
	text := web.GetRemoteTextFile(url)
	if len(text) == 0 {
		fmt.Println("Error retrieving version list: \"" + url + "\" returned blank results. This can happen when the remote file is being updated. Please try again in a few minutes.")
		os.Exit(0)
	}

	// Parse
	var data = make([]map[string]interface{}, 0)
	err := json.Unmarshal([]byte(text), &data)
	if err != nil {
		fmt.Printf("Error retrieving versions from \"%s\": %v", url, err.Error())
		os.Exit(1)
	}

	for _, element := range data {
		var version = element["version"].(string)[1:]
		all = append(all, version)

		if val, ok := element["npm"].(string); ok {
			npm[version] = val
		}

		if isLTS(element) {
			lts = append(lts, version)
		} else if isCurrent(element) {
			current = append(current, version)
		} else if isStable(element) {
			stable = append(stable, version)
		} else if isUnstable(element) {
			unstable = append(unstable, version)
		}
	}

	return all, lts, current, stable, unstable, npm
}
