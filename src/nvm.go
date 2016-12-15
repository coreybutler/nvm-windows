package main

import (
  "fmt"
  "os"
  "os/exec"
  "strings"
  "io/ioutil"
  "regexp"
  "bytes"
  "./nvm/web"
  "./nvm/arch"
  "./nvm/file"
  "./nvm/node"
  "github.com/olekukonko/tablewriter"
)

const (
  NvmVersion = "1.1.1"
)

type Environment struct {
  settings        string
  root            string
  symlink         string
  arch            string
  node_mirror     string
  npm_mirror      string
  proxy           string
  originalpath    string
  originalversion string
}

var env = &Environment{
  settings: os.Getenv("NVM_HOME")+"\\settings.txt",
  root: "",
  symlink: os.Getenv("NVM_SYMLINK"),
  arch: os.Getenv("PROCESSOR_ARCHITECTURE"),
  node_mirror: "",
  npm_mirror: "",
  proxy: "none",
  originalpath: "",
  originalversion: "",
}

func main() {
  args := os.Args
  detail := ""
  procarch := arch.Validate(env.arch)

  Setup()

  // Capture any additional arguments
  if len(args) > 2 {
    detail = args[2]
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
    case "ls": list(detail)
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
    case "v":
      fmt.Println(NvmVersion)
    case "arch":
      if strings.Trim(detail," \r\n") != "" {
        detail = strings.Trim(detail," \r\n")
        if detail != "32" && detail != "64" {
          fmt.Println("\""+detail+"\" is an invalid architecture. Use 32 or 64.")
          return
        }
        env.arch = detail
        saveSettings()
        fmt.Println("Default architecture set to "+detail+"-bit.")
        return
      }
      _, a := node.GetCurrentVersion()
      fmt.Println("System Default: "+env.arch+"-bit.")
      fmt.Println("Currently Configured: "+a+"-bit.")
    case "proxy":
      if detail == "" {
        fmt.Println("Current proxy: "+env.proxy)
      } else {
        env.proxy = detail
        saveSettings()
      }
    case "update": update()
    default: help()
  }
}

func update() {
//  cmd := exec.Command("cmd", "/d", "echo", "testing")
//  var output bytes.Buffer
//  var _stderr bytes.Buffer
//  cmd.Stdout = &output
//  cmd.Stderr = &_stderr
//  perr := cmd.Run()
//  if perr != nil {
//      fmt.Println(fmt.Sprint(perr) + ": " + _stderr.String())
//      return
//  }
}

func CheckVersionExceedsLatest(version string) bool{
    //content := web.GetRemoteTextFile("http://nodejs.org/dist/latest/SHASUMS256.txt")
    url := web.GetFullNodeUrl("latest/SHASUMS256.txt");
    content := web.GetRemoteTextFile(url)
    re := regexp.MustCompile("node-v(.+)+msi")
    reg := regexp.MustCompile("node-v|-x.+")
	latest := reg.ReplaceAllString(re.FindString(content),"")

	if version <= latest {
		return false
	} else {
		return true
	}
}

func install(version string, cpuarch string) {
  if version == "" {
    fmt.Println("\nInvalid version.")
    fmt.Println(" ")
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

  // If user specifies "latest" version, find out what version is
  if version == "latest" {
    url := web.GetFullNodeUrl("latest/SHASUMS256.txt");
    content := web.GetRemoteTextFile(url)
    re := regexp.MustCompile("node-v(.+)+msi")
    reg := regexp.MustCompile("node-v|-x.+")
    version = reg.ReplaceAllString(re.FindString(content),"")
  }

  version = cleanVersion(version)

  if CheckVersionExceedsLatest(version) {
  	fmt.Println("Node.js v"+version+" is not yet released or available.")
  	return
  }

  if cpuarch == "64" && !web.IsNode64bitAvailable(version) {
    fmt.Println("Node.js v"+version+" is only available in 32-bit.")
    return
  }

  // Check to see if the version is already installed
  if !node.IsVersionInstalled(env.root,version,cpuarch) {

    if !node.IsVersionAvailable(version){
      fmt.Println("Version "+version+" is not available. If you are attempting to download a \"just released\" version,")
      fmt.Println("it may not be recognized by the nvm service yet (updated hourly). If you feel this is in error and")
      fmt.Println("you know the version exists, please visit http://github.com/coreybutler/nodedistro and submit a PR.")
      return
    }

    // Make the output directories
    os.Mkdir(env.root+"\\v"+version,os.ModeDir)

    // Download node
    if (cpuarch == "32" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"32") {
      os.Mkdir(env.root+"\\v"+version+"\\32-bit", os.ModeDir)
      os.Mkdir(env.root+"\\v"+version+"\\32-bit\\node_modules", os.ModeDir)
      success := web.GetNodeJS(env.root,version,"32")
      if !success {
        os.RemoveAll(env.root + "\\v" + version + "\\32-bit\\node_modules")
        fmt.Println("Could not download node.js v"+version+" 32-bit executable.")
        return
      }
	  installNpm(version, "32")
    }
    if (cpuarch == "64" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"64") {
      os.Mkdir(env.root+"\\v"+version+"\\64-bit", os.ModeDir)
      os.Mkdir(env.root+"\\v"+version+"\\64-bit\\node_modules", os.ModeDir)
      success := web.GetNodeJS(env.root,version,"64")
      if !success {
        os.RemoveAll(env.root + "\\v" + version + "\\64-bit\\node_modules")
        fmt.Println("Could not download node.js v"+version+" 64-bit executable.")
        return
      }
	  installNpm(version, "64")
    }

    // If this is ever shipped for Mac, it should use homebrew.
    // If this ever ships on Linux, it should be on bintray so it can use yum, apt-get, etc.

    return
  } else {
    fmt.Println("Version " + version + " is already installed.")
    return
  }

}

func installNpm(version string, bits string) {
  if file.Exists(env.root + "\\v" + version + "\\" + bits + "-bit\\node_modules\\npm") {
    return
  }

  // If successful, add npm
  npmv := getNpmVersion(version)
  success := web.GetNpm(env.root, getNpmVersion(version))
  if success {
    fmt.Printf("Installing npm v" + npmv + "...")

	// new temp directory under the nvm root
	tempDir := env.root + "\\temp"

    // Extract npm to the temp directory
    file.Unzip(tempDir+"\\npm-v"+npmv+".zip", tempDir+"\\nvm-npm")

    // Copy the npm and npm.cmd files to the installation directory
    os.Rename(tempDir+"\\nvm-npm\\npm-"+npmv+"\\bin\\npm", env.root+"\\v"+version+"\\"+bits+"-bit\\npm")
    os.Rename(tempDir+"\\nvm-npm\\npm-"+npmv+"\\bin\\npm.cmd", env.root+"\\v"+version+"\\"+bits+"-bit\\npm.cmd")
    os.Rename(tempDir+"\\nvm-npm\\npm-"+npmv, env.root+"\\v"+version+"\\"+bits+"-bit\\node_modules\\npm")

    // Remove the temp directory
    // may consider keep the temp files here
    os.RemoveAll(tempDir)

    fmt.Println("\n\nInstallation complete. If you want to use this version, type\n\nnvm use " + version)
   } else {
    fmt.Println("Could not download npm for node v" + version + ".")
    fmt.Println("Please visit https://github.com/npm/npm/releases/tag/v" + npmv + " to download npm.")
    fmt.Println("It should be extracted to " + env.root + "\\v" + version + "\\" + bits + "-bit")
   }
}

func uninstall(version string) {
  // Make sure a version is specified
  if len(version) == 0 {
    fmt.Println("Provide the version you want to uninstall.")
    help()
    return
  }

  version = cleanVersion(version)

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

func cleanVersion(version string) string {
  re := regexp.MustCompile("\\d+.\\d+.\\d+")
  matched := re.FindString(version)

  if len(matched) == 0 {
    re = regexp.MustCompile("\\d+.\\d+")
    matched = re.FindString(version)
    if len(matched) == 0 {
      matched = version + ".0.0"
    } else {
      matched = matched + ".0"
    }
    fmt.Println(matched)
  }

  return matched
}

func use(version string, cpuarch string) {
  if version == "32" || version == "64" {
    cpuarch = version
    v, _ := node.GetCurrentVersion()
    version = v
  }

  cpuarch = arch.Validate(cpuarch)

  version = cleanVersion(version)

  // Make sure the version is installed. If not, warn.
  if !node.IsVersionInstalled(env.root,version,cpuarch) {
    fmt.Println("node v"+version+" ("+cpuarch+"-bit) is not installed.")
    if cpuarch == "32" {
      if node.IsVersionInstalled(env.root,version,"64") {
        fmt.Println("\nDid you mean node v"+version+" (64-bit)?\nIf so, type \"nvm use "+version+" 64\" to use it.")
      }
    }
    if cpuarch == "64" {
      if node.IsVersionInstalled(env.root,version,"32") {
        fmt.Println("\nDid you mean node v"+version+" (32-bit)?\nIf so, type \"nvm use "+version+" 32\" to use it.")
      }
    }
    return
  }

  // Create or update the symlink
  sym, _ := os.Stat(env.symlink)
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

  if node.IsUsingOldLayout(env.root, version) {
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
    nodepath := env.root + "\\v" + version + "\\node.exe"
    node32path := env.root + "\\v" + version + "\\node32.exe"
    node64path := env.root + "\\v" + version + "\\node64.exe"
    node32exists := file.Exists(node32path)
    node64exists := file.Exists(node64path)
    nodeexists := file.Exists(nodepath)
    if node32exists && cpuarch == "32" { // user wants 32, but node.exe is 64
      if nodeexists {
        os.Rename(nodepath, node64path) // node.exe -> node64.exe
      }
      os.Rename(node32path, nodepath) // node32.exe -> node.exe
    }
    if node64exists && cpuarch == "64" { // user wants 64, but node.exe is 32
      if nodeexists {
        os.Rename(nodepath, node32path) // node.exe -> node32.exe
      }
      os.Rename(node64path, nodepath) // node64.exe -> node.exe
    }
  } else {
    cpuarch = arch.Validate(cpuarch)

    c := exec.Command(env.root+"\\elevate.cmd", "cmd", "/C", "mklink", "/D", env.symlink, env.root+"\\v"+version+"\\"+cpuarch+"-bit")
    var out bytes.Buffer
    var stderr bytes.Buffer
    c.Stdout = &out
    c.Stderr = &stderr
    err := c.Run()
    if err != nil {
      fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
      return
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
  if listtype == "" {
    listtype = "installed"
  }
  if listtype != "installed" && listtype != "available" {
    fmt.Println("\nInvalid list option.\n\nPlease use on of the following\n  - nvm list\n  - nvm list installed\n  - nvm list available")
    help()
    return
  }

  if listtype == "installed" {
    fmt.Println("")
    inuse, a := node.GetCurrentVersion()

    v := node.GetInstalled(env.root)
    for i := 0; i < len(v); i++ {
      version := v[i]
      isnode, _ := regexp.MatchString("v",version)
      str := ""
      if isnode {
        if "v"+inuse == version {
          str = str+"  * "
        } else {
          str = str+"    "
        }
        str = str+regexp.MustCompile("v").ReplaceAllString(version,"")
        if "v"+inuse == version {
          str = str+" (Currently using "+a+"-bit executable)"
//            str = ansi.Color(str,"green:black")
        }
        fmt.Printf(str+"\n")
      }
    }
    if len(v) == 0 {
      fmt.Println("No installations recognized.")
    }
  } else {
    _, lts, current, stable, unstable, _ := node.GetAvailable()

    releases := 20

    data := make([][]string, releases, releases + 5)
    for i := 0; i < releases; i++ {
      release := make([]string, 4, 6)

      release[0] = ""
      release[1] = ""
      release[2] = ""
      release[3] = ""

      if len(current) > i {
        if len(current[i]) > 0 {
          release[0] = current[i]
        }
      }

      if len(lts) > i {
        if len(lts[i]) > 0 {
          release[1] = lts[i]
        }
      }

      if len(stable) > i {
        if len(stable[i]) > 0 {
          release[2] = stable[i]
        }
      }

      if len(unstable) > i {
        if len(unstable[i]) > 0 {
          release[3] = unstable[i]
        }
      }

      data[i] = release
    }

    fmt.Println("")
    table := tablewriter.NewWriter(os.Stdout)
    table.SetHeader([]string{"   Current  ", "    LTS     ", " Old Stable ", "Old Unstable"})
    table.SetBorders(tablewriter.Border{Left: true, Top: false, Right: true, Bottom: false})
    table.SetAlignment(tablewriter.ALIGN_CENTER)
    table.SetCenterSeparator("|")
    table.AppendBulk(data) // Add Bulk Data
    table.Render()

    fmt.Println("\nThis is a partial list. For a complete list, visit https://nodejs.org/download/release")
  }
}

func enable() {
  dir := ""
  files, _ := ioutil.ReadDir(env.root)
  for _, f := range files {
    if f.IsDir() {
      isnode, _ := regexp.MatchString("v",f.Name())
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
  fmt.Println("\nRunning version "+NvmVersion+".")
  fmt.Println("\nUsage:")
  fmt.Println(" ")
  fmt.Println("  nvm arch                     : Show if node is running in 32 or 64 bit mode.")
  fmt.Println("  nvm install <version> [arch] : The version can be a node.js version or \"latest\" for the latest stable version.")
  fmt.Println("                                 Optionally specify whether to install the 32 or 64 bit version (defaults to system arch).")
  fmt.Println("                                 Set [arch] to \"all\" to install 32 AND 64 bit versions.")
  fmt.Println("  nvm list [available]         : List the node.js installations. Type \"available\" at the end to see what can be installed. Aliased as ls.")
  fmt.Println("  nvm on                       : Enable node.js version management.")
  fmt.Println("  nvm off                      : Disable node.js version management.")
  fmt.Println("  nvm proxy [url]              : Set a proxy to use for downloads. Leave [url] blank to see the current proxy.")
  fmt.Println("                                 Set [url] to \"none\" to remove the proxy.")
  fmt.Println("  nvm node_mirror [url]        : Set the node mirror. Defaults to https://nodejs.org/dist/. Leave [url] blank to use default url.")
  fmt.Println("  nvm npm_mirror [url]         : Set the npm mirror. Defaults to https://github.com/npm/npm/archive/. Leave [url] blank to default url.")
  fmt.Println("  nvm uninstall <version>      : The version must be a specific version.")
//  fmt.Println("  nvm update                   : Automatically update nvm to the latest version.")
  fmt.Println("  nvm use [version] [arch]     : Switch to use the specified version. Optionally specify 32/64bit architecture.")
  fmt.Println("                                 nvm use <arch> will continue using the selected version, but switch to 32/64 bit mode.")
  fmt.Println("  nvm root [path]              : Set the directory where nvm should store different versions of node.js.")
  fmt.Println("                                 If <path> is not set, the current root will be displayed.")
  fmt.Println("  nvm version                  : Displays the current running version of nvm for Windows. Aliased as v.")
  fmt.Println(" ")
}

// Given a node.js version, returns the associated npm version
func getNpmVersion(nodeversion string) string {

  _, _, _, _, _, npm := node.GetAvailable()

  return npm[nodeversion]
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
  content := "root: "+strings.Trim(env.root," \n\r")+"\r\narch: "+strings.Trim(env.arch," \n\r")+"\r\nproxy: "+strings.Trim(env.proxy," \n\r")+"\r\noriginalpath: "+strings.Trim(env.originalpath," \n\r")+"\r\noriginalversion: "+strings.Trim(env.originalversion," \n\r")
  content = content + "node_mirror: "+strings.Trim(env.node_mirror," \n\r")+ "npm_mirror: "+strings.Trim(env.npm_mirror," \n\r")
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
    line = strings.Trim(line, " \r\n")
    if strings.HasPrefix(line, "root:") {
      env.root = strings.TrimSpace(regexp.MustCompile("^root:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "originalpath:") {
      env.originalpath = strings.TrimSpace(regexp.MustCompile("^originalpath:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "originalversion:") {
      env.originalversion = strings.TrimSpace(regexp.MustCompile("^originalversion:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "arch:") {
      env.arch = strings.TrimSpace(regexp.MustCompile("^arch:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "node_mirror:") {
      env.node_mirror = strings.TrimSpace(regexp.MustCompile("^node_mirror:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "npm_mirror:") {
      env.npm_mirror = strings.TrimSpace(regexp.MustCompile("^npm_mirror:").ReplaceAllString(line, ""))
    } else if strings.HasPrefix(line, "proxy:") {
      env.proxy = strings.TrimSpace(regexp.MustCompile("^proxy:").ReplaceAllString(line, ""))
      if env.proxy != "none" && env.proxy != "" {
        if strings.ToLower(env.proxy[0:4]) != "http" {
          env.proxy = "http://"+env.proxy
        }
        web.SetProxy(env.proxy)
      }
    }
  }

  web.SetMirrors(env.node_mirror, env.npm_mirror)
  env.arch = arch.Validate(env.arch)

  // Make sure the directories exist
  _, e := os.Stat(env.root)
  if e != nil {
    fmt.Println(env.root+" could not be found or does not exist. Exiting.")
    return
  }
}
