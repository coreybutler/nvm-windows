package node

import(
  "os/exec"
  "strings"
  "regexp"
  "io/ioutil"
  "encoding/json"
  "sort"
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
  e32 := file.Exists(root+"\\v"+version+"\\node32.exe")
  e64 := file.Exists(root+"\\v"+version+"\\node64.exe")
  used := file.Exists(root+"\\v"+version+"\\node.exe")
  if cpu == "all" {
    return ((e32 || e64) && used) || e32 && e64
  }
  if file.Exists(root+"\\v"+version+"\\node"+cpu+".exe") {
    return true
  }
  if ((e32||e64) && used) || (e32 && e64) {
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
  avail, _, _ := GetAvailable()

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

func GetAvailabeVersions() (map[string]interface{}, map[string]interface{},map[string]interface{}){
  // Check the service to make sure the version is available
  // modified by lzm at 4-7-2016, to chinese guys github maybe blocked at anytime.why not use the http://nodejs.org/dist/index.json?
  //text := web.GetRemoteTextFile("https://raw.githubusercontent.com/coreybutler/nodedistro/master/nodeversions.json")
  url := web.GetFullNodeUrl("index.json")
  text := web.GetRemoteTextFile(url)
  // Parse
  var data interface{}
  json.Unmarshal([]byte(text), &data);

  //body := data.(map[string]interface{})
  //_all := body["all"]
  //_stable := body["stable"]
  //_unstable := body["unstable"]
  //allkeys := _all.(map[string]interface{})
  //stablekeys := _stable.(map[string]interface{})
  //unstablekeys := _unstable.(map[string]interface{})

  body := data.([]interface{})
  allkeys := make(map[string]interface{})
  stablekeys := make(map[string]interface{})
  unstablekeys := make(map[string]interface{})
  for _, temp := range body {
    item := temp.(map[string]interface{})
    key := strings.TrimLeft(item["version"].(string), "v")
    value := item["npm"]
    if value != nil{
      allkeys[key] = value.(string)
      version,_ := semver.New(key)
      if (version.Major!=0 && version.Major % 2 ==0) || version.Minor % 2==0{
        stablekeys[key] = value.(string)
      } else{
        unstablekeys[key] = value.(string)
      }
    }
  }
  return allkeys, stablekeys, unstablekeys
}

func GetAvailable() ([]string, []string, []string) {
  all := make([]string,0)
  stable := make([]string,0)
  unstable := make([]string,0)

  allkeys, stablekeys, unstablekeys := GetAvailabeVersions()

  for nodev, _ := range allkeys {
    all = append(all,nodev)
  }
  for nodev, _ := range stablekeys {
    stable = append(stable,nodev)
  }
  for nodev, _ := range unstablekeys {
    unstable = append(unstable,nodev)
  }

  sort.Sort(BySemanticVersion(all))
  sort.Sort(BySemanticVersion(stable))
  sort.Sort(BySemanticVersion(unstable))

  return all, stable, unstable
}
