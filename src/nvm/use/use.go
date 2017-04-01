package use

import (
  "fmt"
  "github.com/blang/semver"
)

func packageJsonMatch(available semver.Versions) (string, error) {
  engineRangeRaw, e := tryPackage()

  if e != nil {
    // TODO: Error Handling
    return "", e
  }

  fmt.Println("\nRange Specified: ", engineRangeRaw)

  if engineRangeRaw == "*" {
    fmt.Println("Wildcard Activated. This needs to be written!")
    return "", nil
  }

  semRange, e := semver.ParseRange(engineRangeRaw)

  if e != nil {
    // TODO: Error Handling
    return "", nil
  }

  minimum, err := getMaxVersion(available, semRange)

  return minimum.String(), err
}

func AutoUse(available []string) (string, error) {
  availableVersions := stringToVersion(available)
  semver.Sort(availableVersions)
  version, e := packageJsonMatch(availableVersions)

  if e != nil {
    return "", e
  }

  return version, nil
}
