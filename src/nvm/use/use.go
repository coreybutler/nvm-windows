package use

import (
  "fmt"
  "sort"
)

func readVersion() {
  version, e := tryPackage()

  if e != nil {
    fmt.Println(e)
  }

  fmt.Println(version)
}

func AutoUse(available []string) (string, error) {
  sort.Strings(available)
  readVersion()
  return "", nil
}
