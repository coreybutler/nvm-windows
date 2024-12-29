package author

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/coreybutler/go-fsutil"
	"golang.org/x/sys/windows"
)

const (
	// Constants for SetWindowPos
	SWP_NOMOVE     = 0x0002
	SWP_NOZORDER   = 0x0004
	SWP_SHOWWINDOW = 0x0040
	SW_HIDE        = 0 // Hide the window (for the main console window)
)

var (
	modkernel32    = syscall.NewLazyDLL("kernel32.dll")
	moduser32      = syscall.NewLazyDLL("user32.dll")
	procGetConsole = modkernel32.NewProc("GetConsoleWindow")
	procShowWindow = moduser32.NewProc("ShowWindow")
)

// Hide the main console window (the one running the Go app)
func hideConsole() {
	hwnd, _, _ := procGetConsole.Call()
	if hwnd != 0 {
		procShowWindow.Call(hwnd, uintptr(SW_HIDE)) // Hide the main console window
	}
}

func Bridge(args ...string) {
	exe, _ := os.Executable()
	bridge := filepath.Join(filepath.Dir(exe), "author-nvm.exe")
	if !fsutil.Exists(bridge) {
		fmt.Println("error: author bridge not found")
		os.Exit(1)
	}

	if len(args) < 2 {
		fmt.Printf("error: invalid number of arguments passed to author bridge: %d\n", len(args))
		os.Exit(1)
	}

	command := args[0]
	args = args[1:]

	// fmt.Printf("running author bridge: %s %v\n", command, args)

	hideConsole()

	cmd := exec.Command(bridge, append([]string{command}, args...)...)
	cmd.SysProcAttr = &windows.SysProcAttr{
		CreationFlags: windows.CREATE_NEW_PROCESS_GROUP | windows.DETACHED_PROCESS | windows.CREATE_NO_WINDOW,
	}
	// Create pipes for Stdout and Stderr
	stdoutPipe, _ := cmd.StdoutPipe()
	stderrPipe, _ := cmd.StderrPipe()

	// Start the command
	if err := cmd.Start(); err != nil {
		fmt.Println("error starting bridge command:", err)
		os.Exit(1)
	}

	// Stream Stdout
	go func() {
		scanner := bufio.NewScanner(stdoutPipe)
		for scanner.Scan() {
			fmt.Println(scanner.Text())
		}
	}()

	// Stream Stderr
	go func() {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			fmt.Println(scanner.Text())
		}
	}()

	if command == "upgrade" {
		for _, arg := range args {
			if strings.Contains(arg, "--rollback") {
				fmt.Println("exiting to rollback nvm.exe...")
				time.Sleep(1 * time.Second)
				os.Exit(0)
			}
		}
	}

	// Wait for the command to finish
	if err := cmd.Wait(); err != nil {
		fmt.Println("bridge command finished with error:", err)
	}
}
