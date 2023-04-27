package file

import (
	"archive/zip"
	"bufio"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
)

// Function courtesy http://stackoverflow.com/users/1129149/swtdrgn
func Unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		if !strings.Contains(f.Name, "..") {
			rc, err := f.Open()
			if err != nil {
				return err
			}
			defer rc.Close()

			fpath := filepath.Join(dest, f.Name)
			if f.FileInfo().IsDir() {
				os.MkdirAll(fpath, f.Mode())
			} else {
				var fdir string
				if lastIndex := strings.LastIndex(fpath, string(os.PathSeparator)); lastIndex > -1 {
					fdir = fpath[:lastIndex]
				}

				err = os.MkdirAll(fdir, f.Mode())
				if err != nil {
					log.Fatal(err)
					return err
				}
				f, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
				if err != nil {
					return err
				}
				defer f.Close()

				_, err = io.Copy(f, rc)
				if err != nil {
					return err
				}
			}
		} else {
			log.Printf("failed to extract file: %s (cannot validate)\n", f.Name)
		}
	}

	return nil
}

func ReadLines(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	return lines, scanner.Err()
}

func Exists(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}
