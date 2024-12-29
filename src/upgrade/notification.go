package upgrade

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

type LastNotification struct {
	outpath string
	LTS     string `json:"lts,omitempty"`
	Current string `json:"current,omitempty"`
	NVM4W   string `json:"nvm4w,omitempty"`
	Author  string `json:"author,omitempty"`
}

func LoadNotices() *LastNotification {
	ln := &LastNotification{}
	noticedata, err := os.ReadFile(ln.File())
	if err != nil {
		if !os.IsNotExist(err) {
			abortOnError(err)
		}
	}

	if noticedata != nil {
		abortOnError(json.Unmarshal(noticedata, &ln))
	}

	return ln
}

func (ln *LastNotification) Path() string {
	if ln.outpath == "" {
		ln.outpath = filepath.Join(os.Getenv("APPDATA"), ".nvm")
	}
	return ln.outpath
}

func (ln *LastNotification) File() string {
	return filepath.Join(ln.Path(), ".updates.json")
}

func (ln *LastNotification) Save() {
	output, err := json.Marshal(ln)
	abortOnError(err)
	abortOnError(os.MkdirAll(ln.Path(), os.ModePerm))
	abortOnError(os.WriteFile(ln.File(), output, os.ModePerm))
	abortOnError(setHidden(ln.Path()))
}

func (ln *LastNotification) LastLTS() time.Time {
	if ln.LTS == "" {
		return time.Now()
	}

	t, _ := time.Parse("2006-01-02", ln.LTS)
	return t
}

func (ln *LastNotification) LastCurrent() time.Time {
	if ln.Current == "" {
		return time.Now()
	}

	t, _ := time.Parse("2006-01-02", ln.Current)
	return t
}
