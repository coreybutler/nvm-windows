package utility

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
)

func Rename(old, new string) error {
	old_drive := filepath.VolumeName(old)
	new_drive := filepath.VolumeName(new)

	if old_drive == new_drive {
		return os.Rename(old, new)
	}

	// Get file or directory info
	info, err := os.Stat(old)
	if err != nil {
		return fmt.Errorf("failed to stat source: %w", err)
	}

	// If old is a directory, copy recursively
	if info.IsDir() {
		err = copyDir(old, new)
		if err != nil {
			return fmt.Errorf("failed to copy directory: %w", err)
		}
	} else {
		// Otherwise, copy a single file
		err = copyFile(old, new)
		if err != nil {
			return fmt.Errorf("failed to copy file: %w", err)
		}
	}

	// Remove the original source
	err = os.RemoveAll(old)
	if err != nil {
		return fmt.Errorf("failed to remove source: %w", err)
	}

	return nil
}

// copyFile copies a single file from source (old) to destination (new).
func copyFile(old, new string) error {
	srcFile, err := os.Open(old)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer srcFile.Close()

	// Ensure destination directory exists
	destDir := filepath.Dir(new)
	err = os.MkdirAll(destDir, os.ModePerm)
	if err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	destFile, err := os.Create(new)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, srcFile)
	if err != nil {
		return fmt.Errorf("failed to copy data: %w", err)
	}

	// Copy file permissions
	info, err := srcFile.Stat()
	if err != nil {
		return fmt.Errorf("failed to get source file info: %w", err)
	}
	err = os.Chmod(new, info.Mode())
	if err != nil {
		return fmt.Errorf("failed to set permissions on destination file: %w", err)
	}

	return nil
}

// copyDir recursively copies a directory from old path to new path.
func copyDir(old, new string) error {
	entries, err := os.ReadDir(old)
	if err != nil {
		return fmt.Errorf("failed to read source directory: %w", err)
	}

	// Ensure destination directory exists
	err = os.MkdirAll(new, os.ModePerm)
	if err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	for _, entry := range entries {
		srcPath := filepath.Join(old, entry.Name())
		destPath := filepath.Join(new, entry.Name())

		if entry.IsDir() {
			err = copyDir(srcPath, destPath)
			if err != nil {
				return fmt.Errorf("failed to copy subdirectory: %w", err)
			}
		} else {
			err = copyFile(srcPath, destPath)
			if err != nil {
				return fmt.Errorf("failed to copy file: %w", err)
			}
		}
	}

	return nil
}
