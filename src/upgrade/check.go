package upgrade

import (
	"encoding/json"
	"fmt"
	"nvm/node"
	"nvm/semver"
	"nvm/web"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dustin/go-humanize"
	"github.com/go-toast/toast"
)

func Check(root string, nvmversion string) {
	// Store the recognized version to prevent duplicates
	notices := LoadNotices()
	defer notices.Save()

	reg := LoadRegistration(os.Args[2:]...)

	// Check for Node.js updates
	if reg.LTS || reg.Current {
		buf, err := get(web.GetFullNodeUrl("index.json"))
		abortOnError(err)

		var data = make([]map[string]interface{}, 0)
		abortOnError(json.Unmarshal([]byte(buf), &data))

		lastLTS := notices.LastLTS()
		lastCurrent := notices.LastCurrent()
		installed := node.GetInstalled(root)
		changes := 0
		for _, value := range data {
			switch value["lts"].(type) {
			// LTS versions always have the lts attribute as a string
			case string:
				if reg.LTS {
					versionDate, _ := time.Parse("2006-01-02", value["date"].(string))
					if versionDate.After(lastLTS) && versionDate.After(time.Now().AddDate(0, -1, 0)) && !in(strings.Replace(value["version"].(string), "v", "", 1), installed) {
						abortOnError(alertRelease(value))
						changes++
					}
				}
			// Current versions always have the lts attribute as a false boolean
			case bool:
				if reg.Current && !value["lts"].(bool) {
					versionDate, _ := time.Parse("2006-01-02", value["date"].(string))
					if versionDate.After(lastCurrent) && versionDate.After(time.Now().AddDate(0, -1, 0)) && !in(strings.Replace(value["version"].(string), "v", "", 1), installed) {
						abortOnError(alertRelease(value))
						changes++
					}
				}
			}
		}

		if changes == 0 {
			noupdate()
			return
		}
	}

	// Check for NVM for Windows updates
	if reg.NVM4W {
		buf, err := get("https://api.github.com/repos/coreybutler/nvm-windows/releases/latest")
		abortOnError(err)

		var data map[string]interface{}
		abortOnError(json.Unmarshal([]byte(buf), &data))

		current, err := semver.New(nvmversion)
		abortOnError(err)
		next, err := semver.New(data["tag_name"].(string))
		abortOnError(err)

		notices.NVM4W = current.String()
		if !next.GT(current) {
			alertNvmRelease(current, next, data)
			notices.NVM4W = next.String()
		}
	}

	now := time.Now().Format("2006-01-02")
	if reg.LTS {
		notices.LTS = now
	}
	if reg.Current {
		notices.Current = now
	}
}

func alertNvmRelease(current, next *semver.Version, data map[string]interface{}) {
	exe, _ := os.Executable()
	path := filepath.Dir(exe)
	iconPath := filepath.Join(path, "nodejs.ico")
	pubDate, _ := time.Parse("2006-01-02T15:04:05Z", data["published_at"].(string))
	age := humanize.Time(pubDate)

	notification := toast.Notification{
		AppID:   "NVM for Windows",
		Title:   "NVM for Windows Update Available",
		Message: fmt.Sprintf("Version %s is was released %s.\n(currently using v%s)", next.String(), age, current.String()),
		Icon:    iconPath,
		Actions: []toast.Action{
			{"protocol", "Install", "nvm://launch?action=upgrade"},
			{"protocol", "View", data["html_url"].(string)},
		},
	}

	// Display the notification
	err := notification.Push()
	if err != nil {
		abortOnError(err)
	}
}

func in(item string, set []string) bool {
	for _, i := range set {
		if i == item {
			return true
		}
	}
	return false
}

func noupdate() {
	fmt.Println("no new releases detected")
}

func UpgradeCompleteAlert(version string) {
	exe, _ := os.Executable()
	path := filepath.Dir(exe)
	iconPath := filepath.Join(path, "checkmark.ico")

	notification := toast.Notification{
		AppID:   "NVM for Windows",
		Title:   "Upgrade Complete",
		Message: fmt.Sprintf("The upgrade to NVM for Windows v%s completed successfully.", version),
		Icon:    iconPath,
		Actions: []toast.Action{
			{"protocol", "Open PowerShell", "nvm://launch?action=open_terminal&amp;type=pwsh"},
			{"protocol", "Open CMD Prompt", "nvm://launch?action=open_terminal&amp;type=cmd"},
		},
	}

	// Display the notification
	err := notification.Push()
	if err != nil {
		abortOnError(err)
	}
}

func alertRelease(data map[string]interface{}) error {
	version, err := semver.New(data["version"].(string))
	if err != nil {
		return err
	}
	exe, _ := os.Executable()
	path := filepath.Dir(exe)
	iconPath := filepath.Join(path, "nodejs.ico")
	releaseName := ""
	releaseDate, err := time.Parse("2006-01-02", data["date"].(string))
	if err != nil {
		return err
	}

	age := humanize.Time(releaseDate)
	msg := fmt.Sprintf("with npm v%s & V8 v%s\nReleased %s.", data["npm"].(string), data["v8"].(string), age)

	switch data["lts"].(type) {
	case string:
		releaseName = " (LTS " + data["lts"].(string) + ")"
	}

	if data["security"].(bool) {
		msg += "\nThis is a security release."
	}

	title := fmt.Sprintf("Node.js v%s Available%s", version.String(), releaseName)

	notification := toast.Notification{
		AppID:   "NVM for Windows",
		Title:   title,
		Message: msg,
		Icon:    iconPath,
	}

	// Display the notification
	err = notification.Push()
	if err != nil {
		return err
	}

	return nil
}
