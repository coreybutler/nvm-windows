package use

import (
  "github.com/blang/semver"
  "errors"
)

func popV(input string) string {
  firstLetter := string(input[0])

  if firstLetter == "V" || firstLetter == "v" {
    input = input[1:len(input)]
  }

  return input
}

func stringToVersion(versions []string) ([]semver.Version) {
  var results semver.Versions

  for _, value := range versions {
    value = popV(value)
    ver, e := semver.Parse(value)
    if e == nil {
      results = append(results, ver)
    }
  }

  return results
}

func getMaxVersion(sortedSemVersions []semver.Version, semRange semver.Range) (semver.Version, error) {
  var valid semver.Version

  for i := semver.Versions.Len(sortedSemVersions) - 1; i >= 0; i-- {
    if semRange(sortedSemVersions[i]) {
      return sortedSemVersions[i], nil
    }
  }

  return valid, errors.New("No version matched range specified.")
}
