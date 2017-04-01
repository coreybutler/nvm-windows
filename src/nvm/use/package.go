package use

import (
  "io/ioutil"
  "errors"
  "encoding/json"
)

type PackageJson struct {
  Engines struct {
    Node string `json:"node"`
  } `json:"engines"`
}

func openPackage() ([]byte, error) {
  file, e := ioutil.ReadFile("./package.json")
  if e != nil {
    return nil, errors.New("Error with package.json file present in this directory!")
  }
  return file, nil
}

func parsePackageFile(file []byte) (string, error) {
  var packageData PackageJson
  err := json.Unmarshal(file, &packageData)

  if err != nil {
    return "", err
  }

  if packageData.Engines.Node == "" {
    return "", errors.New("Missing node version")
  }

  return packageData.Engines.Node, nil
}

func tryPackage() (string, error) {
  packageFile, e := openPackage()
  if e != nil {
    return "", e
  }
  version, e := parsePackageFile(packageFile)
  if e != nil {
    return "", e
  }
  return version, nil
}
