package main

import (
  "io"
  "os"
  "github.com/olekukonko/tablewriter"
)

const (
  AppName = "switch"
  AppVersion = "1.0.0"
  Description = ""
)

func main() {
  help()
}

func log(msg string) {
  io.WriteString(os.Stdout, msg)
}

func cmd(subcmd string) string {
  return AppName + " " + subcmd
}

func xcmd(subcmd string) string {
  return "[X] " + AppName + " " + subcmd
}

func help() {
  log("\nRunning " + AppName + " v" + AppVersion + ".")
  log("\n\nUsage:\n\n")

  data := [][]string{
    []string{xcmd("install <version> [arch]"), "The <version> can be a specific Node.js semantic version number, \"latest\" for the latest available release, or \"lts\" for the latest LTS release. Optionally specify whether to install the 32 or 64 bit version (defaults to system arch). Set [arch] to \"all\" to install 32 AND 64 bit versions."},
    []string{xcmd("uninstall <version>"), "Must be a specific version (x.x.x)."},
  }

  table := tablewriter.NewWriter(os.Stdout)
  table.SetBorder(false)
  table.SetCenterSeparator("")
  table.SetColumnSeparator("")
  table.SetColWidth(40)
  table.AppendBulk(data)
  table.Render()

  log("\n\nCopyright (c) 2017 Author.io and Contributors.\n\n")
}
