package arch

import (
  "regexp"
  "os"
  "os/exec"
  "strings"
)

func Bit(path string) string {
  cmd := exec.Command("file",path)
  str, err := cmd.Output()
  if err == nil {
    is64, _ := regexp.MatchString("PE32\\+",string(str))
    if is64 {
      return "64"
    }
    return "32"
  }
  return "?"
}

func Validate(str string) (string){
  if str == "" {
    str = os.Getenv("PROCESSOR_ARCHITECTURE")
  }
  if strings.ContainsAny("64",str) {
    return "64"
  } else {
    return "32"
  }
}
