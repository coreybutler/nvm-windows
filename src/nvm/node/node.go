package node

import (
	"../arch"
	"../file"
	"../semver"
	"../web"
	"encoding/json"
	"io/ioutil"
	"os/exec"
	"regexp"
	"strings"
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
	avail, _, _, _ := GetAvailable()

	for _, b := range avail {
		if b == v {
			return true
		}
	}
	return false
}

func GetInstalled(root string) []string {
	list := make([]string, 0)
	files, _ := ioutil.ReadDir(root)
	for i := len(files) - 1; i >= 0; i-- {
		if files[i].IsDir() {
			isnode, _ := regexp.MatchString("v", files[i].Name())
			if isnode {
				list = append(list, files[i].Name())
			}
		}
	}
	return list
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
	v1, _ := semver.New(s[i])
	v2, _ := semver.New(s[j])
	return v1.GTE(v2)
}

func GetAvailable() ([]string, []string, []string, map[string]string) {
	all := make([]string, 0)
	lts := make([]string, 0)
	stable := make([]string, 0)
	npm := make(map[string]string)
	url := web.GetFullNodeUrl("index.json")
	// Check the service to make sure the version is available
	text := web.GetRemoteTextFile(url)

	// Parse
	var data = make([]map[string]interface{}, 0)
	json.Unmarshal([]byte(text), &data)

	for _, element := range data {

		var version = element["version"].(string)[1:]
		all = append(all, version)

		if val, ok := element["npm"].(string); ok {
			npm[version] = val
		}

		switch v := element["lts"].(type) {
		case bool:
			if v == false {
				stable = append(stable, version)
			}
		case string:
			lts = append(lts, version)
		}
	}

	return all, lts, stable, npm
}
