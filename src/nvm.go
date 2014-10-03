package main

import (
  "fmt"
  "os"
  "os/exec"
  "strings"
  "io/ioutil"
  "regexp"
  "bytes"
  "encoding/json"
  "./nvm/web"
  "./nvm/arch"
  "./nvm/file"
  "./nvm/node"
//  "./ansi"
)

const (
  NvmVersion = "1.0.3"
)

type Environment struct {
  settings  string
  root      string
  symlink   string
  arch      string
  proxy     string
}

var env = &Environment{
  settings: os.Getenv("APPDATA")+"\\nvm\\settings.txt",
  root: "",
  symlink: "",
  arch: os.Getenv("PROCESSOR_ARCHITECTURE"),
  proxy: "none",
}

func main() {
  args := os.Args
  detail := ""
  procarch := arch.Validate(env.arch)

  Setup()

  // Capture any additional arguments
  if len(args) > 2 {
    detail = strings.ToLower(args[2])
  }
  if len(args) > 3 {
    procarch = args[3]
  }
  if len(args) < 2 {
    help()
    return
  }

  // Run the appropriate method
  switch args[1] {
    case "install": install(detail,procarch)
    case "uninstall": uninstall(detail)
    case "use": use(detail,procarch)
    case "list": list(detail)
    case "on": enable()
    case "off": disable()
    case "root":
      if len(args) == 3 {
        updateRootDir(args[2])
      } else {
        fmt.Println("\nCurrent Root: "+env.root)
      }
    case "version":
      fmt.Println(NvmVersion)
    case "arch":
      _, a := node.GetCurrentVersion()
      fmt.Println(a+"-bit")
    case "proxy":
      if detail == "" {
        fmt.Println("Current proxy: "+env.proxy)
      } else {
        env.proxy = detail
        saveSettings()
      }
    default: help()
  }
}

func install(version string, cpuarch string) {
  if version == "" {
    fmt.Println("\nInvalid version.\n")
    help()
    return
  }

  cpuarch = strings.ToLower(cpuarch)

  if cpuarch != "" {
    if cpuarch != "32" && cpuarch != "64" && cpuarch != "all" {
      fmt.Println("\""+cpuarch+"\" is not a valid CPU architecture. Must be 32 or 64.")
      return
    }
  } else {
    cpuarch = env.arch
  }

  if cpuarch != "all" {
    cpuarch = arch.Validate(cpuarch)
  }

  if cpuarch == "64" && !web.IsNode64bitAvailable(version) {
    fmt.Println("Node.js v"+version+" is only available in 32-bit.")
    return
  }

  // If user specifies "latest" version, find out what version is
  if version == "latest" {
    content := web.GetRemoteTextFile("http://nodejs.org/dist/latest/SHASUMS.txt")
    re := regexp.MustCompile("node-v(.+)+msi")
    reg := regexp.MustCompile("node-v|-x.+")
    version = reg.ReplaceAllString(re.FindString(content),"")
  }

  // Check to see if the version is already installed
  if !node.IsVersionInstalled(env.root,version,cpuarch) {

    if !isVersionAvailable(version){
      fmt.Println("Version "+version+" is not available. If you are attempting to download a \"just released\" version,")
      fmt.Println("it may not be recognized by the nvm service yet (updated hourly). If you feel this is in error and")
      fmt.Println("you know the version exists, please visit http://github.com/coreybutler/nodedistro and submit a PR.")
      return
    }

    // Make the output directories
    os.Mkdir(env.root+"\\v"+version,os.ModeDir)
    os.Mkdir(env.root+"\\v"+version+"\\node_modules",os.ModeDir)

    // Download node
    if (cpuarch == "32" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"32") {
      success := web.GetNodeJS(env.root,version,"32");
      if !success {
        os.RemoveAll(env.root+"\\v"+version+"\\node_modules")
        fmt.Println("Could not download node.js v"+version+" 32-bit executable.")
        return
      }
    }
    if (cpuarch == "64" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"64") {
      success := web.GetNodeJS(env.root,version,"64");
      if !success {
        os.RemoveAll(env.root+"\\v"+version+"\\node_modules")
        fmt.Println("Could not download node.js v"+version+" 64-bit executable.")
        return
      }
    }

    if file.Exists(env.root+"\\v"+version+"\\node_modules\\npm") {
      return
    }

    // If successful, add npm
    npmv := getNpmVersion(version)
    success := web.GetNpm(getNpmVersion(version))
    if success {
      fmt.Printf("Installing npm v"+npmv+"...")

      // Extract npm to the temp directory
      file.Unzip(os.TempDir()+"\\npm-v"+npmv+".zip",os.TempDir()+"\\nvm-npm")

      // Copy the npm and npm.cmd files to the installation directory
      os.Rename(os.TempDir()+"\\nvm-npm\\npm-"+npmv+"\\bin\\npm",env.root+"\\v"+version+"\\npm")
      os.Rename(os.TempDir()+"\\nvm-npm\\npm-"+npmv+"\\bin\\npm.cmd",env.root+"\\v"+version+"\\npm.cmd")
      os.Rename(os.TempDir()+"\\nvm-npm\\npm-"+npmv,env.root+"\\v"+version+"\\node_modules\\npm")

      // Remove the source file
      os.RemoveAll(os.TempDir()+"\\nvm-npm")

      fmt.Println("\n\nInstallation complete. If you want to use this version, type\n\nnvm use "+version)
    } else {
      fmt.Println("Could not download npm for node v"+version+".")
      fmt.Println("Please visit https://github.com/npm/npm/releases/tag/v"+npmv+" to download npm.")
      fmt.Println("It should be extracted to "+env.root+"\\v"+version)
    }

    // If this is ever shipped for Mac, it should use homebrew.
    // If this ever ships on Linux, it should be on bintray so it can use yum, apt-get, etc.

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
  if node.IsVersionInstalled(env.root,version,"32") || node.IsVersionInstalled(env.root,version,"64") {
    fmt.Printf("Uninstalling node v"+version+"...")
    v, _ := node.GetCurrentVersion()
    if v == version {
      cmd := exec.Command(env.root+"\\elevate.cmd", "cmd", "/C", "rmdir", env.symlink)
      cmd.Run()
    }
    e := os.RemoveAll(env.root+"\\v"+version)
    if e != nil {
      fmt.Println("Error removing node v"+version)
      fmt.Println("Manually remove "+env.root+"\\v"+version+".")
    } else {
      fmt.Printf(" done")
    }
  } else {
    fmt.Println("node v"+version+" is not installed. Type \"nvm list\" to see what is installed.")
  }
  return
}

func use(version string, cpuarch string) {

  if version == "32" || version == "64" {
    cpuarch = version
    v, _ := node.GetCurrentVersion()
    version = v
  }

  cpuarch = arch.Validate(cpuarch)

  // Make sure the version is installed. If not, warn.
  if !node.IsVersionInstalled(env.root,version,cpuarch) {
    fmt.Println("node v"+version+" ("+cpuarch+"-bit) is not installed.")
    if cpuarch == "32" {
      if node.IsVersionInstalled(env.root,version,"64") {
        fmt.Println("\nDid you mean node v"+version+" (64-bit)?\nIf so, type \"nvm use "+version+" 64\" to use it.")
      }
    }
    if cpuarch == "64" {
      if node.IsVersionInstalled(env.root,version,"64") {
        fmt.Println("\nDid you mean node v"+version+" (64-bit)?\nIf so, type \"nvm use "+version+" 64\" to use it.")
      }
    }
    return
  }

  // Create or update the symlink
  sym, serr := os.Stat(env.symlink)
  serr = serr
  if sym != nil {
    cmd := exec.Command(env.root+"\\elevate.cmd", "cmd", "/C", "rmdir", env.symlink)
    var output bytes.Buffer
    var _stderr bytes.Buffer
    cmd.Stdout = &output
    cmd.Stderr = &_stderr
    perr := cmd.Run()
    if perr != nil {
        fmt.Println(fmt.Sprint(perr) + ": " + _stderr.String())
        return
    }
  }

  c := exec.Command(env.root+"\\elevate.cmd", "cmd", "/C", "mklink", "/D", env.symlink, env.root+"\\v"+version)
  var out bytes.Buffer
  var stderr bytes.Buffer
  c.Stdout = &out
  c.Stderr = &stderr
  err := c.Run()
  if err != nil {
      fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
      return
  }

  // Use the assigned CPU architecture
  cpuarch = arch.Validate(cpuarch)
  e32 := file.Exists(env.root+"\\v"+version+"\\node32.exe")
  e64 := file.Exists(env.root+"\\v"+version+"\\node64.exe")
  used := file.Exists(env.root+"\\v"+version+"\\node.exe")
  if (e32 || e64) {
    if used {
      if e32 {
        os.Rename(env.root+"\\v"+version+"\\node.exe",env.root+"\\v"+version+"\\node64.exe")
        os.Rename(env.root+"\\v"+version+"\\node32.exe",env.root+"\\v"+version+"\\node.exe")
      } else {
        os.Rename(env.root+"\\v"+version+"\\node.exe",env.root+"\\v"+version+"\\node32.exe")
        os.Rename(env.root+"\\v"+version+"\\node64.exe",env.root+"\\v"+version+"\\node.exe")
      }
    } else if e32 || e64 {
      os.Rename(env.root+"\\v"+version+"\\node"+cpuarch+".exe",env.root+"\\v"+version+"\\node.exe")
    }
  }
  fmt.Println("Now using node v"+version+" ("+cpuarch+"-bit)")
}

func useArchitecture(a string) {
  if strings.ContainsAny("32",os.Getenv("PROCESSOR_ARCHITECTURE")) {
    fmt.Println("This computer only supports 32-bit processing.")
    return
  }
  if a == "32" || a == "64" {
    env.arch = a
    saveSettings()
    fmt.Println("Set to "+a+"-bit mode")
  } else {
    fmt.Println("Cannot set architecture to "+a+". Must be 32 or 64 are acceptable values.")
  }
}

func list(listtype string) {
//  if listtype == "" {
    listtype = "installed"
//  }
//  if listtype != "installed" && listtype != "available" {
//    fmt.Println("\nInvalid list option.\n\nPlease use on of the following\n  - nvm list\n  - nvm list installed\n  - nvm list available")
//    help()
//    return
//  }
  if listtype == "installed" {
    fmt.Println("")
    inuse, a := node.GetCurrentVersion()

    dir := ""
    files, _ := ioutil.ReadDir(env.root)
    for i := len(files) - 1; i >= 0; i-- {
      f := files[i]
      if f.IsDir() {
        isnode, _ := regexp.MatchString("v",f.Name())
        str := ""
        if isnode {
          dir = f.Name()
          if "v"+inuse == f.Name() {
            str = str+"  * "
          } else {
            str = str+"    "
          }
          str = str+regexp.MustCompile("v").ReplaceAllString(f.Name(),"")
          if "v"+inuse == f.Name() {
            str = str+" ("+a+"-bit)"
//            str = ansi.Color(str,"green:black")
          }
          fmt.Printf(str+"\n")
        }
      }
    }
    if len(strings.Trim(dir," \n\r")) == 0 {
      fmt.Println("No installations recognized.")
    }
//  } else {
//    fmt.Printf("List "+listtype)
  }
}

func enable() {
  dir := ""
  files, _ := ioutil.ReadDir(env.root)
  for _, f := range files {
    if f.IsDir() {
      isnode, verr := regexp.MatchString("v",f.Name())
      verr = verr
      if isnode {
        dir = f.Name()
      }
    }
  }
  fmt.Println("nvm enabled")
  if dir != "" {
    use(strings.Trim(regexp.MustCompile("v").ReplaceAllString(dir,"")," \n\r"),env.arch)
  } else {
    fmt.Println("No versions of node.js found. Try installing the latest by typing nvm install latest")
  }
}

func disable() {
  cmd := exec.Command(env.root+"\\elevate.cmd", "cmd", "/C", "rmdir", env.symlink)
  cmd.Run()
  fmt.Println("nvm disabled")
}

func help() {
  fmt.Println("\nUsage:\n")
  fmt.Println("  nvm arch                     : Show if node is running in 32 or 64 bit mode.")
  fmt.Println("  nvm install <version> [arch] : The version can be a node.js version or \"latest\" for the latest stable version.")
  fmt.Println("                                 Optionally specify whether to install the 32 or 64 bit version (defaults to system arch).")
  fmt.Println("                                 Set [arch] to \"all\" to install 32 AND 64 bit versions.")
  fmt.Println("  nvm list                     : List the node.js installations.")
  fmt.Println("  nvm on                       : Enable node.js version management.")
  fmt.Println("  nvm off                      : Disable node.js version management.")
  fmt.Println("  nvm proxy [url]              : Set a proxy to use for downloads. Leave [url] blank to see the current proxy.")
  fmt.Println("                                 Set [url] to \"none\" to remove the proxy.")
  fmt.Println("  nvm uninstall <version>      : The version must be a specific version.")
  fmt.Println("  nvm use <version> [arch]     : Switch to use the specified version. Optionally specify 32/64bit architecture.")
  fmt.Println("                                 nvm use <arch> will continue using the selected version, but switch to 32/64 bit mode.")
  fmt.Println("  nvm root [path]              : Set the directory where nvm should store different versions of node.js.")
  fmt.Println("                                 If <path> is not set, the current root will be displayed.")
  fmt.Println("  nvm version                  : Displays the current running version of nvm for Windows.\n")
}

// Given a node.js version, returns the associated npm version
func getNpmVersion(nodeversion string) string {

  // Get raw text
  text := web.GetRemoteTextFile("https://raw.githubusercontent.com/coreybutler/nodedistro/master/nodeversions.json")

  // Parse
  var data interface{}
  json.Unmarshal([]byte(text), &data);
  body := data.(map[string]interface{})
  all := body["all"]
  npm := all.(map[string]interface{})

  return npm[nodeversion].(string)
}

func updateRootDir(path string) {
  _, err := os.Stat(path)
  if err != nil {
    fmt.Println(path+" does not exist or could not be found.")
    return
  }

  env.root = path
  saveSettings()
  fmt.Println("\nRoot has been set to "+path)
}

func saveSettings() {
  content := "root: "+strings.Trim(env.root," \n\r")+"\r\npath: "+strings.Trim(env.symlink," \n\r")+"\r\narch: "+strings.Trim(env.arch," \n\r")+"\r\nproxy: "+strings.Trim(env.proxy," \n\r")
  ioutil.WriteFile(env.settings, []byte(content), 0644)
}

func Setup() {
  lines, err := file.ReadLines(env.settings)
  if err != nil {
    fmt.Println("\nERROR",err)
    os.Exit(1)
  }

  // Process each line and extract the value
  for _, line := range lines {
    if strings.Contains(line,"root:") {
      env.root = strings.Trim(regexp.MustCompile("root:").ReplaceAllString(line,"")," \r\n")
    } else if strings.Contains(line,"path:") {
      env.symlink = strings.Trim(regexp.MustCompile("path:").ReplaceAllString(line,"")," \r\n")
    } else if strings.Contains(line,"arch:"){
      env.arch = strings.Trim(regexp.MustCompile("arch:").ReplaceAllString(line,"")," \r\n")
    } else if strings.Contains(line,"proxy:"){
      env.proxy = strings.Trim(regexp.MustCompile("proxy:").ReplaceAllString(line,"")," \r\n")
      if env.proxy != "none" && env.proxy != "" {
        if strings.ToLower(env.proxy[0:4]) != "http" {
          env.proxy = "http://"+env.proxy
        }
        web.SetProxy(env.proxy)
      }
    }
  }

  env.arch = arch.Validate(env.arch)

  // Make sure the directories exist
  p, e := os.Stat(env.root)
  if e != nil {
    fmt.Println(env.root+" could not be found or does not exist. Exiting.")
    return
    p=p
  }
}

func isVersionAvailable(v string) bool {
  // Check the service to make sure the version is available
  text := web.GetRemoteTextFile("https://raw.githubusercontent.com/coreybutler/nodedistro/master/nodeversions.json")

  // Parse
  var data interface{}
  json.Unmarshal([]byte(text), &data);
  body := data.(map[string]interface{})
  all := body["all"]
  npm := all.(map[string]interface{})

  return npm[v] != nil
}
