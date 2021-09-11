package main

import (
  "bytes"
  "fmt"
  "io/ioutil"
  "log"
  "os"
  "os/exec"
  "path/filepath"
  "regexp"
  "strconv"
  "strings"
  "syscall"
  "time"
  "./nvm/web"
  "./nvm/arch"
  "./nvm/file"
  "./nvm/node"
  "github.com/olekukonko/tablewriter"
)

const (
  NvmVersion = "1.1.8"
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
  verifyssl       bool
}

var home = filepath.Clean(os.Getenv("NVM_HOME")+"\\settings.txt")
var symlink = filepath.Clean(os.Getenv("NVM_SYMLINK"))

var env = &Environment{
  settings: home,
  root: "",
  symlink: symlink,
  arch: os.Getenv("PROCESSOR_ARCHITECTURE"),
  node_mirror: "",
  npm_mirror: "",
  proxy: "none",
  originalpath: "",
  originalversion: "",
  verifyssl: true,
}

func main() {
  args := os.Args
  detail := ""
  procarch := arch.Validate(env.arch)

  setup()

  // Capture any additional arguments
  if len(args) > 2 {
    detail = args[2]
  }
  if len(args) > 3 {
    if (args[3] == "32" || args[3] == "64") {
      procarch = args[3]
    }
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

    //case "update": update()
    case "node_mirror": setNodeMirror(detail)
    case "npm_mirror": setNpmMirror(detail)
    default: help()
  }
}

// ===============================================================
// BEGIN | CLI functions
// ===============================================================
func setNodeMirror(uri string) {
	env.node_mirror = uri
	saveSettings()
}

func setNpmMirror(uri string) {
	env.npm_mirror = uri
	saveSettings()
}

/*
func update() {
  cmd := exec.Command("cmd", "/d", "echo", "testing")
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
*/

func install(version string, cpuarch string) {
  args := os.Args
  lastarg := args[len(args) - 1]

  if lastarg == "--insecure" {
    env.verifyssl = false
  }

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

  // If user specifies "latest" or "lts" (latest LTS) version, find out what version is
  if version == "latest" {
    url := web.GetFullNodeUrl("latest/SHASUMS256.txt");
    content := web.GetRemoteTextFile(url)
    re := regexp.MustCompile("node-v(.+)+msi")
    reg := regexp.MustCompile("node-v|-x.+")
    version = reg.ReplaceAllString(re.FindString(content),"")
  } else if version == "lts" {
    _, ltsList, _, _, _, _ := node.GetAvailable()
    // ltsList has already been numerically sorted
    version = ltsList[0]
  }

  // if the user specifies only the major version number then install the latest
  // version of the major version number
  if len(version) == 1 {
    version = findLatestSubVersion(version)
  } else {
    version = cleanVersion(version)
  }

  if checkVersionExceedsLatest(version) {
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
      url := web.GetFullNodeUrl("index.json")
      fmt.Println("\nVersion "+version+" is not available.\n\nThe complete list of available versions can be found at " + url)
      return
    }

    // Make the output directories
    os.Mkdir(filepath.Join(env.root, "v"+version), os.ModeDir)
    os.Mkdir(filepath.Join(env.root, "v"+version, "node_modules"), os.ModeDir)

    // Warn the user if they're attempting to install without verifying the remote SSL cert
    if !env.verifyssl {
      fmt.Println("\nWARNING: The remote SSL certificate will not be validated during the download process.\n")
    }

    // Download node
    if (cpuarch == "32" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"32") {
      success := web.GetNodeJS(env.root,version,"32");
      if !success {
        os.RemoveAll(filepath.Join(env.root, "v"+version, "node_modules"))
        fmt.Println("Could not download node.js v"+version+" 32-bit executable.")
        return
      }
    }
    if (cpuarch == "64" || cpuarch == "all") && !node.IsVersionInstalled(env.root,version,"64") {
      success := web.GetNodeJS(env.root,version,"64");
      if !success {
        os.RemoveAll(filepath.Join(env.root, "v"+version, "node_modules"))
        fmt.Println("Could not download node.js v"+version+" 64-bit executable.")
        return
      }
    }

    if file.Exists(filepath.Join(env.root, "v"+version, "node_modules", "npm")) {
      return
    }

    // If successful, add npm
    npmv := getNpmVersion(version)
    success := web.GetNpm(env.root, getNpmVersion(version))
    if success {
      fmt.Printf("Installing npm v"+npmv+"...")

      // new temp directory under the nvm root
      tempDir := filepath.Join(env.root, "temp")

      // Extract npm to the temp directory
      err := file.Unzip(filepath.Join(tempDir, "npm-v"+npmv+".zip"), filepath.Join(tempDir, "nvm-npm"))

      // Copy the npm and npm.cmd files to the installation directory
      tempNpmBin := filepath.Join(tempDir, "nvm-npm", "cli-"+npmv, "bin")

      // Support npm < 6.2.0
      if file.Exists(tempNpmBin) == false {
        tempNpmBin = filepath.Join(tempDir, "nvm-npm", "npm-"+npmv, "bin")
      }

      if file.Exists(tempNpmBin) == false {
        log.Fatal("Failed to extract npm. Could not find " + tempNpmBin)
      }

      // Standard npm support
      os.Rename(filepath.Join(tempNpmBin, "npm"), filepath.Join(env.root, "v"+version, "npm"))
      os.Rename(filepath.Join(tempNpmBin, "npm.cmd"),filepath.Join(env.root, "v"+version, "npm.cmd"))

      // npx support
      if _, err := os.Stat(filepath.Join(tempNpmBin, "npx")); err == nil {
        os.Rename(filepath.Join(tempNpmBin, "npx"), filepath.Join(env.root, "v"+version, "npx"))
        os.Rename(filepath.Join(tempNpmBin, "npx.cmd"), filepath.Join(env.root, "v"+version, "npx.cmd"))
      }

      npmSourcePath := filepath.Join(tempDir, "nvm-npm", "npm-"+npmv)

      if file.Exists(npmSourcePath) == false {
        npmSourcePath = filepath.Join(tempDir, "nvm-npm", "cli-"+npmv)
      }

      moveNpmErr := os.Rename(npmSourcePath, filepath.Join(env.root, "v"+version, "node_modules", "npm"))
      if moveNpmErr != nil {
        // sometimes Windows can take some time to enable access to large amounts of files after unzip, use exponential backoff to wait until it is ready
        for _, i := range [5]int{1, 2, 4, 8, 16} {
          time.Sleep(time.Duration(i)*time.Second)
          moveNpmErr = os.Rename(npmSourcePath, filepath.Join(env.root, "v"+version, "node_modules", "npm"))
          if moveNpmErr == nil { break }
        }

      }

      if err == nil && moveNpmErr == nil {
        // Remove the temp directory
        // may consider keep the temp files here
        os.RemoveAll(tempDir)

        fmt.Println("\n\nInstallation complete. If you want to use this version, type\n\nnvm use "+version)
      } else if moveNpmErr != nil {
        fmt.Println("Error: Unable to move directory "+npmSourcePath+" to node_modules: "+moveNpmErr.Error())
      } else {
        fmt.Println("Error: Unable to install NPM: "+err.Error());
      }
    } else {
      fmt.Println("Could not download npm for node v"+version+".")
      fmt.Println("Please visit https://github.com/npm/cli/releases/tag/v"+npmv+" to download npm.")
      fmt.Println("It should be extracted to "+env.root+"\\v"+version)
    }

    // Reset the SSL verification
    env.verifyssl = true

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

  version = cleanVersion(version)

  // Determine if the version exists and skip if it doesn't
  if node.IsVersionInstalled(env.root,version,"32") || node.IsVersionInstalled(env.root,version,"64") {
    fmt.Printf("Uninstalling node v"+version+"...")
    v, _ := node.GetCurrentVersion()
    if v == version {
      runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`,
        filepath.Join(env.root, "elevate.cmd"),
        filepath.Clean(env.symlink)))
    }
    e := os.RemoveAll(filepath.Join(env.root, "v"+version))
    if e != nil {
      fmt.Println("Error removing node v"+version)
      fmt.Println("Manually remove " + filepath.Join(env.root, "v"+version) + ".")
    } else {
      fmt.Printf(" done")
    }
  } else {
    fmt.Println("node v"+version+" is not installed. Type \"nvm list\" to see what is installed.")
  }
  return
}

func findLatestSubVersion(version string) string {
	url := web.GetFullNodeUrl("latest-v" + version + ".x" + "/SHASUMS256.txt")
	content := web.GetRemoteTextFile(url)
	re := regexp.MustCompile("node-v(.+)+msi")
	reg := regexp.MustCompile("node-v|-x.+")
	latest := reg.ReplaceAllString(re.FindString(content), "")
	return latest
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

  // Remove symlink if it already exists
  sym, _ := os.Stat(env.symlink)
  if sym != nil {
    if !runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`,
      filepath.Join(env.root, "elevate.cmd"),
      filepath.Clean(env.symlink))) {
      return
    }
  }

  // Create new symlink
  if !runElevated(fmt.Sprintf(`"%s" cmd /C mklink /D "%s" "%s"`,
    filepath.Join(env.root, "elevate.cmd"),
    filepath.Clean(env.symlink),
    filepath.Join(env.root, "v"+version))) {
    return
  }

  // Use the assigned CPU architecture
  cpuarch = arch.Validate(cpuarch)
  nodepath   := filepath.Join(env.root, "v"+version, "node.exe")
  node32path := filepath.Join(env.root, "v"+version, "node32.exe")
  node64path := filepath.Join(env.root, "v"+version, "node64.exe")
  node32exists := file.Exists(node32path)
  node64exists := file.Exists(node64path)
  nodeexists   := file.Exists(nodepath)
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

    fmt.Println("\nThis is a partial list. For a complete list, visit https://nodejs.org/download/releases")
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
  if !runElevated(fmt.Sprintf(`"%s" cmd /C rmdir "%s"`,
    filepath.Join(env.root, "elevate.cmd"),
    filepath.Clean(env.symlink))) {
    return
  }

  fmt.Println("nvm disabled")
}

func help() {
  fmt.Println("\nRunning version "+NvmVersion+".")
  fmt.Println("\nUsage:")
  fmt.Println(" ")
  fmt.Println("  nvm arch                     : Show if node is running in 32 or 64 bit mode.")
  fmt.Println("  nvm install <version> [arch] : The version can be a node.js version, \"latest\" for the latest stable version, or \"lts\" for the latest LTS.")
  fmt.Println("                                 Optionally specify whether to install the 32 or 64 bit version (defaults to system arch).")
  fmt.Println("                                 Set [arch] to \"all\" to install 32 AND 64 bit versions.")
  fmt.Println("                                 Add --insecure to the end of this command to bypass SSL validation of the remote download server.")
  fmt.Println("  nvm list [available]         : List the node.js installations. Type \"available\" at the end to see what can be installed. Aliased as ls.")
  fmt.Println("  nvm on                       : Enable node.js version management.")
  fmt.Println("  nvm off                      : Disable node.js version management.")
  fmt.Println("  nvm proxy [url]              : Set a proxy to use for downloads. Leave [url] blank to see the current proxy.")
  fmt.Println("                                 Set [url] to \"none\" to remove the proxy.")
  fmt.Println("  nvm node_mirror [url]        : Set the node mirror. Defaults to https://nodejs.org/dist/. Leave [url] blank to use default url.")
  fmt.Println("  nvm npm_mirror [url]         : Set the npm mirror. Defaults to https://github.com/npm/cli/archive/. Leave [url] blank to default url.")
  fmt.Println("  nvm uninstall <version>      : The version must be a specific version.")
//  fmt.Println("  nvm update                   : Automatically update nvm to the latest version.")
  fmt.Println("  nvm use [version] [arch]     : Switch to use the specified version. Optionally specify 32/64bit architecture.")
  fmt.Println("                                 nvm use <arch> will continue using the selected version, but switch to 32/64 bit mode.")
  fmt.Println("  nvm root [path]              : Set the directory where nvm should store different versions of node.js.")
  fmt.Println("                                 If <path> is not set, the current root will be displayed.")
  fmt.Println("  nvm version                  : Displays the current running version of nvm for Windows. Aliased as v.")
  fmt.Println(" ")
}
// ===============================================================
// END | CLI functions
// ===============================================================

// ===============================================================
// BEGIN | Utility functions
// ===============================================================
func checkVersionExceedsLatest(version string) bool{
  //content := web.GetRemoteTextFile("http://nodejs.org/dist/latest/SHASUMS256.txt")
  url := web.GetFullNodeUrl("latest/SHASUMS256.txt");
  content := web.GetRemoteTextFile(url)
  re := regexp.MustCompile("node-v(.+)+msi")
  reg := regexp.MustCompile("node-v|-x.+")
  latest := reg.ReplaceAllString(re.FindString(content),"")
  var vArr = strings.Split(version,".")
  var lArr = strings.Split(latest, ".")
  for index := range lArr {
    lat,_ := strconv.Atoi(lArr[index])
    ver,_ := strconv.Atoi(vArr[index])
    //Should check for valid input (checking for conversion errors) but this tool is made to trust the user
    if ver < lat {
      return false
    } else if ver > lat {
      return true
    }
  }
  return false
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

  currentRoot := env.root
  env.root = filepath.Clean(path)

  // Copy command files
  os.Link(filepath.Clean(currentRoot + "/elevate.cmd"), filepath.Clean(env.root + "/elevate.cmd"))
  os.Link(filepath.Clean(currentRoot + "/elevate.vbs"), filepath.Clean(env.root + "/elevate.vbs"))

  saveSettings()

  if currentRoot != env.root {
    fmt.Println("\nRoot has been changed from " + currentRoot + " to " + path)
  }
}

func runElevated(command string) bool {
  c := exec.Command("cmd") // dummy executable that actually needs to exist but we'll overwrite using .SysProcAttr

  // Based on the official docs, syscall.SysProcAttr.CmdLine doesn't exist.
  // But it does and is vital:
  // https://github.com/golang/go/issues/15566#issuecomment-333274825
  // https://medium.com/@felixge/killing-a-child-process-and-all-of-its-children-in-go-54079af94773
  c.SysProcAttr = &syscall.SysProcAttr{CmdLine: command}

  var stderr bytes.Buffer
  c.Stderr = &stderr

  err := c.Run()
  if err != nil {
    fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
    return false
  }

  return true
}

func saveSettings() {
	content := "root: " + strings.Trim(env.root, " \n\r") + "\r\narch: " + strings.Trim(env.arch, " \n\r") + "\r\nproxy: " + strings.Trim(env.proxy, " \n\r") + "\r\noriginalpath: " + strings.Trim(env.originalpath, " \n\r") + "\r\noriginalversion: " + strings.Trim(env.originalversion, " \n\r")
	content = content + "\r\nnode_mirror: " + strings.Trim(env.node_mirror, " \n\r") + "\r\nnpm_mirror: " + strings.Trim(env.npm_mirror, " \n\r")
  ioutil.WriteFile(env.settings, []byte(content), 0644)
}

// NOT USED?
/*
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
*/
// ===============================================================
// END | Utility functions
// ===============================================================

func setup() {
  lines, err := file.ReadLines(env.settings)
  if err != nil {
    fmt.Println("\nERROR",err)
    os.Exit(1)
  }

  // Process each line and extract the value
  for _, line := range lines {
    line = strings.Trim(line, " \r\n")
    if strings.HasPrefix(line, "root:") {
      env.root = filepath.Clean(strings.TrimSpace(regexp.MustCompile("^root:").ReplaceAllString(line, "")))
    } else if strings.HasPrefix(line, "originalpath:") {
      env.originalpath = filepath.Clean(strings.TrimSpace(regexp.MustCompile("^originalpath:").ReplaceAllString(line, "")))
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
        web.SetProxy(env.proxy, env.verifyssl)
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
