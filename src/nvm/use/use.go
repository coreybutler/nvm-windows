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
    return available[semver.Versions.Len(available) - 1].String(), nil
  }

  semRange, e := semver.ParseRange(engineRangeRaw)

  if e != nil {
    return "", e
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
