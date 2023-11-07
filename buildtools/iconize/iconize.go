package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"syscall"

	fs "github.com/coreybutler/go-fsutil"
)

const (
	LR_LOADFROMFILE = 0x00000010
	LR_DEFAULTSIZE  = 0x00000040
	IMAGE_ICON      = 1
	LR_DEFAULTCOLOR = 0x00000000
	RT_ICON         = 3
)

var (
	modUser32               = syscall.NewLazyDLL("user32.dll")
	procDestroyIcon         = modUser32.NewProc("DestroyIcon")
	modKernel32             = syscall.NewLazyDLL("kernel32.dll")
	procUpdateResourceW     = modKernel32.NewProc("UpdateResourceW")
	procBeginUpdateResource = modKernel32.NewProc("BeginUpdateResourceW")
	procEndUpdateResource   = modKernel32.NewProc("EndUpdateResourceW")
	procLoadImageW          = modUser32.NewProc("LoadImageW")
)

func main() {
	if len(os.Args) != 3 {
		log.Println("Incorrect number of arguments. Expected 2: iconize <file> <icon>")
		os.Exit(1)
	}

	exePath := fs.Abs(os.Args[1])
	iconPath := fs.Abs(os.Args[2])

	if !fs.Exists(exePath) {
		log.Fatal(exePath + " does not exist")
	}

	if !fs.Exists(iconPath) {
		log.Fatal(iconPath + " does not exist")
	}

	// Run Resource Hacker command to modify the icon
	cmd := exec.Command("../ResourceHacker.exe", "-open", exePath, "-save", exePath, "-action", "modify", "-resource", iconPath, "-mask", "ICONGROUP,MAINICON,", "-log", "NUL")
	err := cmd.Run()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Icon associated with EXE file successfully!")
}
