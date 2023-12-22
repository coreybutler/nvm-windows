package web

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"archive/zip"
)

var client = &http.Client{}

// func DownloadText(url string) string {
// 	response, err := client.Get(url)
// 	if err != nil {
// 		fmt.Println("Error while downloading", url, "-", err)
// 		os.Exit(1)
// 	}
// 	defer response.Body.Close()

// 	body, err := ioutil.ReadAll(response.Body)
// 	if err != nil {
// 		fmt.Print(err)
// 		os.Exit(1)
// 	}
// 	return string(body)
// }

func Download(url string, target string) bool {
	output, err := os.Create(target)
	if err != nil {
		fmt.Println("Error while creating", target, "-", err)
		return false
	}
	defer output.Close()

	response, err := client.Get(url)
	if err != nil {
		fmt.Println("Error while downloading", url, "-", err)
	}
	defer response.Body.Close()
	c := make(chan os.Signal, 2)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		fmt.Println("Download interrupted.")
		output.Close()
		response.Body.Close()
	}()
	_, err = io.Copy(output, response.Body)
	if err != nil {
		fmt.Println("Error while downloading", url, "-", err)
		return false
	}
	if response.Status[0:3] != "200" {
		// fmt.Println("HTTP " + response.Status[0:3] + " " + url)
		// fmt.Println("Download failed. Rolling Back.")
		fmt.Println("ERROR: SOURCE NOT FOUND -> " + url)
		os.RemoveAll(target)
		return false
	}

	return true
}

func Unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer func() {
		if err := r.Close(); err != nil {
			panic(err)
		}
	}()

	os.MkdirAll(dest, 0755)

	// Closure to address file descriptors issue with all the deferred .Close() methods
	extractAndWriteFile := func(f *zip.File) error {
		rc, err := f.Open()
		if err != nil {
			return err
		}
		defer func() {
			if err := rc.Close(); err != nil {
				panic(err)
			}
		}()

		path := filepath.Join(dest, f.Name)

		// Check for ZipSlip (Directory traversal)
		if !strings.HasPrefix(path, filepath.Clean(dest)+string(os.PathSeparator)) {
			return fmt.Errorf("illegal file path: %s", path)
		}

		if f.FileInfo().IsDir() {
			os.MkdirAll(path, f.Mode())
		} else {
			os.MkdirAll(filepath.Dir(path), f.Mode())
			f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
			if err != nil {
				return err
			}
			defer func() {
				if err := f.Close(); err != nil {
					panic(err)
				}
			}()

			_, err = io.Copy(f, rc)
			if err != nil {
				return err
			}
		}
		return nil
	}

	for _, f := range r.File {
		err := extractAndWriteFile(f)
		if err != nil {
			return err
		}
	}

	return nil
}
