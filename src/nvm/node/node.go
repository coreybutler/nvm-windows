package node

import(
  "os/exec"
  "strings"
  "regexp"
  "io/ioutil"
  "encoding/json"
  "../arch"
  "../file"
  "../web"
  "../semver"
)

/**
 * Returns version, architecture
 */
func GetCurrentVersion() (string, string) {
  cmd := exec.Command("node","-v")
  str, err := cmd.Output()
  if err == nil {
    v := strings.Trim(regexp.MustCompile("-.*$").ReplaceAllString(regexp.MustCompile("v").ReplaceAllString(strings.Trim(string(str)," \n\r"),""),"")," \n\r")
    cmd := exec.Command("node","-p","console.log(process.execPath)")
    str, _ := cmd.Output()
    file := strings.Trim(regexp.MustCompile("undefined").ReplaceAllString(string(str),"")," \n\r")
    bit := arch.Bit(file)
    if (bit == "?"){
      cmd := exec.Command("node", "-e", "console.log(process.arch)" )
      str, err := cmd.Output()
      if (err == nil) {
        if (string(str) == "x64") {
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
  return "Unknown",""
}

func IsVersionInstalled(root string, version string, cpu string) bool {
  e32 := file.Exists(root+"\\v"+version+"\\node32.exe") ||
    file.Exists(root+"\\v"+version+"\\32-bit\\node.exe")
  e64 := file.Exists(root+"\\v"+version+"\\node64.exe") ||
    file.Exists(root+"\\v"+version+"\\64-bit\\node.exe")
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

func IsUsingOldLayout(root string, version string) bool {
  return file.Exists(root+"\\v"+version+"\\node32.exe") ||
    file.Exists(root+"\\v"+version+"\\node64.exe") ||
    file.Exists(root+"\\v"+version+"\\node.exe")
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

func GetInstalled(root string) []string {
  list := make([]string,0)
  files, _ := ioutil.ReadDir(root)
  for i := len(files) - 1; i >= 0; i-- {
    if files[i].IsDir() {
      isnode, _ := regexp.MatchString("v",files[i].Name())
      if isnode {
        list = append(list,files[i].Name())
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

  version, _ := semver.New(element["version"].(string)[1:])
  benchmark, _ := semver.New("1.0.0")

  if version.LT(benchmark) {
    return false
  }

  return version.Major%2 == 0
}

// Identifies a stable old version.
func isStable(element map[string]interface{}) bool {
  if isCurrent(element) {
    return false
  }

  version, _ := semver.New(element["version"].(string)[1:])

  if (version.Major != 0) {
    return false
  }

  return version.Minor%2 == 0
}

// Identifies an unstable old version.
func isUnstable(element map[string]interface{}) bool {
  if isStable(element) {
    return false
  }

  version, _ := semver.New(element["version"].(string)[1:])

  if (version.Major != 0) {
    return false
  }

  return version.Minor%2 != 0
}

// Retrieve the remotely available versions
func GetAvailable() ([]string, []string, []string, []string, []string, map[string]string) {
  all := make([]string,0)
  lts := make([]string,0)
  current := make([]string,0)
  stable := make([]string,0)
  unstable := make([]string,0)
  npm := make(map[string]string)
  url := web.GetFullNodeUrl("index.json")

  // Check the service to make sure the version is available
  text := web.GetRemoteTextFile(url)

  // Parse
  var data = make([]map[string]interface{}, 0)
  json.Unmarshal([]byte(text), &data);

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
