package main

import (
  "fmt"
  "os"
  "os/exec"
  "strings"
  "path/filepath"
  "net/http"
  "io"
  "io/ioutil"
  "regexp"
  "bytes"
)

var root = ""

func main() {
  args := os.Args
  detail := ""

  setRootDir(filepath.Dir(args[0]))

  // Capture any additional arguments
  if (len(args) > 2) {
    detail = strings.ToLower(args[2])
  }

  // Run the appropriate method
  switch args[1] {
    case "install": install(detail)
    case "uninstall": uninstall(detail)
    case "use": use(detail)
    case "list": list(detail)
    case "enable": enable()
    case "disable": disable()
    //case "root": setRootDir(detail)
    default: help()
  }

}

func install(version string) {
  if version == "" {
    fmt.Println("\nInvalid version.\n")
    help()
    return
  }

  // If user specifies "latest" version, find out what version is
  if version == "latest" {
    content := getRemoteTextFile("http://nodejs.org/dist/latest/SHASUMS.txt")
    re := regexp.MustCompile("node-v(.+)+msi")
    reg := regexp.MustCompile("node-v|-x.+")
    version = reg.ReplaceAllString(re.FindString(content),"")
  }

  // Check to see if the version is already installed
  if !isVersionInstalled(version) {

    // If the version does not exist, download it to the temp directory.
    success := download(version);

     // Run the installer
    if success {
      fmt.Printf("Installing v"+version+"... ")
      os.Mkdir(root+"\\v"+version,os.ModeDir)
      cmd := exec.Command("msiexec.exe","/i",os.TempDir()+"\\"+"node-v"+version+".msi","INSTALLDIR="+root+"\\v"+version,"/qb")
      err := cmd.Run()
      if err != nil {
        fmt.Println("ERROR")
        fmt.Print(err)
        os.Exit(1)
      }
      fmt.Printf("done.")
    }

    // Clean up
    fmt.Printf("\nCleaning up... ")
    os.Remove(os.TempDir()+"\\"+"node-v"+version+".msi")
    fmt.Printf("done.\n")

    return
   } else {
     fmt.Println("Version "+version+" is already installed.")
     return
   }

}

func uninstall(version string) {
  // Make sure a version is specified
  if len(version) == 0 {
    fmt.Println("Provide the version you want to uninstall.")
    help()
    return
  }

  // Determine if the version exists and skip if it doesn't
  if isVersionInstalled(version) {
    fmt.Printf("\nUninstalling node v"+version+"...")
    e := os.RemoveAll(root+"\\v"+version)
    if e != nil {
      fmt.Println("Error removing node v"+version)
      fmt.Println("Check to assure "+root+"\\v"+version+" no longer exists.")
    }
    fmt.Printf(" done")
  } else {
    fmt.Println("node v"+version+" is not installed. Type \"nvm list\" to see what is installed.")
  }
  return
}

func use(version string) {
  // Make sure the version is installed. If not, warn.
  if !isVersionInstalled(version) {
    fmt.Println("node v"+version+" is not installed.")
    return
  }

  // Create the symlink
  c := exec.Command(root+"\\elevate.cmd", "cmd", "/C", "mklink", "/D", root+"\\action", root+"\\v"+version)
  var out bytes.Buffer
  var stderr bytes.Buffer
  c.Stdout = &out
  c.Stderr = &stderr
  err := c.Run()
  if err != nil {
      fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
      return
  }
  fmt.Println("Now using node v"+version)
}

func list(listtype string) {
  if listtype == "" {
    listtype = "installed"
  }
  if listtype != "installed" && listtype != "available" {
    fmt.Println("\nInvalid list option.\n\nPlease use on of the following\n  - wnvm list\n  - wnvm list installed\n  - wnvm list available")
    help()
    return
  }
  fmt.Printf("List "+listtype)
}

func enable() {
  // Prompt user, warning them what they're going to do
  fmt.Printf("Enable by setting the PATH to use the root with a symlink")
}

func disable() {
  // Prompt user, warning them what they're going to do
  fmt.Printf("Disable by removing the symlink in PATH var")
}

func setRootDir(path string) {
  // Prompt user, warning them what they're going to do
  rootdir, err := filepath.Abs(filepath.Dir(path+"\\"))
  if err != nil {
    fmt.Println("Error setting root directory")
    os.Exit(1)
  }
  root = rootdir
  fmt.Println("\nSet the root path to "+root)
}

func help() {
  fmt.Println("\nUsage:\n")
  fmt.Println("  nvm install <version>        : The version can be a node.js version or \"latest\" for the latest stable version.")
  fmt.Println("  nvm uninstall <version>      : The version must be a specific version.")
  fmt.Println("  nvm use <version>            : Switch to use the specified version.")
  fmt.Println("  nvm list [type]              : type can be \"available\" (from nodejs.org),")
  fmt.Println("                                  \"installed\" (what is currently on the computer),")
  fmt.Println("                                  or left blank (same as \"installed\").")
  fmt.Println("  nvm enable                   : Enable node.js version management.")
  fmt.Println("  nvm disable                  : Disable node.js version management.")
  fmt.Println("  nvm root <path>              : Set the directory where wnvm should install different node.js versions.\n")
}

func getRemoteTextFile(url string) string {
  response, httperr := http.Get(url)
  if httperr != nil {
    fmt.Println("\nCould not retrieve "+url+".\n\n")
    fmt.Printf("%s", httperr)
    os.Exit(1)
  } else {
    defer response.Body.Close()
    contents, readerr := ioutil.ReadAll(response.Body)
    if readerr != nil {
      fmt.Printf("%s", readerr)
      os.Exit(1)
    }
    return string(contents)
  }
  os.Exit(1)
  return ""
}

// Download an MSI to the temp directory
func download(v string) bool {

  url := "http://nodejs.org/dist/v"+v+"/node-v"+v+"-x86.msi"
  fileName := os.TempDir()+"\\"+"node-v"+v+".msi"

  fmt.Printf("\nDownloading node.js version "+v+"... ")

  output, err := os.Create(fileName)
  if err != nil {
    fmt.Println("Error while creating", fileName, "-", err)
  }
  defer output.Close()

  response, err := http.Get(url)
  if err != nil {
    fmt.Println("Error while downloading", url, "-", err)
  }
  defer response.Body.Close()

  n, err := io.Copy(output, response.Body)
  if err != nil {
    fmt.Println("Error while downloading", url, "-", err)
  }

  if response.Status[0:3] == "200" {
    fmt.Println(n, "bytes downloaded.")
  } else {
    fmt.Println("ERROR")
  }

  return response.Status[0:3] == "200"
}

func isVersionInstalled(version string) bool {
  src, err := os.Stat(root+"\\v"+version)
  src = src
  return err == nil
}
