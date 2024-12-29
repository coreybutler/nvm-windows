package upgrade

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	NODE_LTS_SCHEDULE_NAME     = "NVM for Windows Node.js LTS Update Check"
	NODE_CURRENT_SCHEDULE_NAME = "NVM for Windows Node.js Current Update Check"
	NVM4W_SCHEDULE_NAME        = "NVM for Windows Update Check"
	AUTHOR_SCHEDULE_NAME       = "NVM for Windows Author Update Check"
)

type Registration struct {
	LTS     bool
	Current bool
	NVM4W   bool
	Author  bool
}

func LoadRegistration(args ...string) *Registration {
	reg := &Registration{
		LTS:     false,
		Current: false,
		NVM4W:   false,
		Author:  false,
	}

	for _, arg := range args {
		arg = strings.ToLower(strings.ReplaceAll(arg, "--", ""))
		switch arg {
		case "lts":
			reg.LTS = true
		case "current":
			reg.Current = true
		case "nvm4w":
			reg.NVM4W = true
		case "author":
			reg.Author = true
		}
	}

	return reg
}

func abortOnError(err error) {
	if err != nil {
		fmt.Println(err)
		os.WriteFile("./error.log", []byte(err.Error()), os.ModePerm)
		os.Exit(1)
	}
}

func logError(err error) {
	fmt.Println(err)
	if err != nil {
		os.WriteFile("./error.log", []byte(err.Error()), os.ModePerm)
	}
}

func Register() {
	reg := LoadRegistration(os.Args[2:]...)
	exe, _ := os.Executable()

	if reg.LTS {
		abortOnError(ScheduleTask(NODE_LTS_SCHEDULE_NAME, fmt.Sprintf(`"%s" checkForUpdates lts`, exe), "HOURLY", "00:30"))
	}
	if reg.Current {
		abortOnError(ScheduleTask(NODE_CURRENT_SCHEDULE_NAME, fmt.Sprintf(`"%s" checkForUpdates current`, exe), "HOURLY", "00:25"))
	}
	if reg.NVM4W {
		abortOnError(ScheduleTask(NVM4W_SCHEDULE_NAME, fmt.Sprintf(`"%s" checkForUpdates nvm4w`, exe), "HOURLY", "00:15"))
	}
	if reg.Author {
		abortOnError(ScheduleTask(AUTHOR_SCHEDULE_NAME, fmt.Sprintf(`"%s" checkForUpdates author`, exe), "HOURLY", "00:45"))
	}
}

func Unregister() {
	reg := LoadRegistration(os.Args[2:]...)

	if reg.LTS {
		abortOnError(UnscheduleTask(NODE_LTS_SCHEDULE_NAME))
	}
	if reg.Current {
		abortOnError(UnscheduleTask(NODE_CURRENT_SCHEDULE_NAME))
	}
	if reg.NVM4W {
		abortOnError(UnscheduleTask(NVM4W_SCHEDULE_NAME))
	}
	if reg.Author {
		abortOnError(UnscheduleTask(AUTHOR_SCHEDULE_NAME))
	}
}

// interval can be:
// MINUTE	Runs the task every N minutes. Requires /MO (modifier) to specify the interval.
// HOURLY	Runs the task every N hours. Requires /MO to specify the interval.
// DAILY	Runs the task every N days. Requires /MO to specify the interval.
// WEEKLY	Runs the task every N weeks. Requires /MO and /D (days of the week) to specify the schedule.
// MONTHLY	Runs the task on specific days of the month. Requires /MO, /D, or /M for further specifics.
// ONCE	Runs the task only once at the specified time. Requires /ST (start time).
// ONSTART	Runs the task every time the system starts.
// ONLOGON	Runs the task every time the user logs on.
// ONIDLE	Runs the task when the system is idle for a specified amount of time.
// EVENT	Runs the task when a specific event is triggered. Requires /EC (event log) and /ID (event ID).
func ScheduleTask(name string, command string, interval string, startTime ...string) error {
	switch strings.ToUpper(interval) {
	case "MINUTE":
		fallthrough
	case "HOURLY":
		fallthrough
	case "DAILY":
		fallthrough
	case "WEEKLY":
		fallthrough
	case "MONTHLY":
		fallthrough
	case "ONCE":
		fallthrough
	case "ONSTART":
		fallthrough
	case "ONLOGON":
		fallthrough
	case "ONIDLE":
		fallthrough
	case "EVENT":
		interval = strings.ToUpper(interval)
	default:
		return fmt.Errorf("scheduling error: invalid interval %q", interval)
	}

	start := "00:00"
	if len(startTime) > 0 {
		start = startTime[0]
	}

	tmp, err := os.MkdirTemp("", "nvm4w-regitration-*")
	if err != nil {
		return fmt.Errorf("scheduling error: %v", err)
	}
	defer os.RemoveAll(tmp)

	script := fmt.Sprintf(`
@echo off
set errorlog="error.log"
set output="%s\output.log"
schtasks /create /tn "%s" /tr "cmd.exe /c %s" /sc %s /st %s /F > %%output%% 2>&1
if not errorlevel 0 (
	echo ERROR: Failed to create scheduled task: exit code: %%errorlevel%% >> %%errorlog%%
	type %%output%% >> %%errorlog%%
	exit /b %%errorlevel%%
)
	`, tmp, name, escapeBackslashes(command), strings.ToLower(interval), start)

	err = os.WriteFile(filepath.Join(tmp, "schedule.bat"), []byte(script), os.ModePerm)
	if err != nil {
		return fmt.Errorf("scheduling error: %v", err)
	}

	cmd := exec.Command(filepath.Join(tmp, "schedule.bat"))

	// Capture standard output and standard error
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("scheduling error: %v\n%s", err, out)
	}

	// fmt.Sprintf(`"%s" task scheduled successfully!`, name)

	return nil
}

func UnscheduleTask(name string) error {
	tmp, err := os.MkdirTemp("", "nvm4w-registration-*")
	if err != nil {
		return fmt.Errorf("scheduling error: %v", err)
	}
	defer os.RemoveAll(tmp)

	script := fmt.Sprintf(`
@echo off
set errorlog="error.log"
set output="%s\output.log"
schtasks /delete /tn "%s" /f > %%output%% 2>&1
if not errorlevel 0 (
	echo failed to remove scheduled task: exit code: %%errorlevel%% >> %%errorlog%%
	type %%output%% >> %%errorlog%%
	exit /b %%errorlevel%%
)
	`, tmp, name)

	err = os.WriteFile(filepath.Join(tmp, "unschedule.bat"), []byte(script), os.ModePerm)
	if err != nil {
		return fmt.Errorf("unscheduling error: %v", err)
	}

	cmd := exec.Command(filepath.Join(tmp, "unschedule.bat"))

	// Capture standard output and standard error
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("unscheduling error: %v\n%s", err, out)
	}

	return nil
}
