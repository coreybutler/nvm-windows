package node

import(
  "os/exec"
  "strings"
  "regexp"
  "../arch"
  "../file"
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
    return v, arch.Bit(file)
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
