package utility

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

var debug bool = false
var exe string
var path string

const (
	// Enable virtual terminal processing on Windows (required to interpret ANSI escape codes)
	enableVirtualTerminalProcessing = 0x0004
	BOLD                            = "\033[38;2;255;165;0m"
	TEXT                            = "\033[38;2;255;200;100m"
	RESET                           = "\033[0m"
)

func enableANSI() {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	setConsoleMode := kernel32.NewProc("SetConsoleMode")
	stdout := syscall.Stdout
	// Get the current console mode
	var mode uint32
	err := syscall.GetConsoleMode(stdout, &mode)
	if err != nil {
		fmt.Println("Error getting console mode:", err)
		return
	}
	// Enable virtual terminal processing
	mode |= enableVirtualTerminalProcessing
	_, _, err = setConsoleMode.Call(uintptr(stdout), uintptr(mode))
	if err != nil && err.Error() != "The operation completed successfully." {
		fmt.Println("Error enabling ANSI:", err)
	}
}

func bold(text string) string {
	return BOLD + text + RESET
}

func text(txt string) string {
	return TEXT + txt + RESET
}

func EnableDebugLogs() {
	debug = true
	exe, _ = os.Executable()
	path = filepath.Join(filepath.Dir(exe), "..")
	enableANSI()
}

func DebugLog(args ...interface{}) {
	if debug {
		_, file, line, _ := runtime.Caller(1)
		for _, arg := range args {
			fmt.Printf(bold("[DEBUG] %v:%v")+" "+text("%v")+"\n", strings.Replace(filepath.ToSlash(file), filepath.ToSlash(path), "..", 1), line, arg)
		}
	}
}

func DebugLogf(tpl string, args ...interface{}) {
	if debug {
		_, file, line, _ := runtime.Caller(1)
		fmt.Printf(bold("[DEBUG] %v:%v")+" "+text("%v")+"\n", strings.Replace(filepath.ToSlash(file), filepath.ToSlash(path), "..", 1), line, fmt.Sprintf(tpl, args...))
	}
}

func DebugFn(fn func()) {
	if debug {
		fn()
	}
}
