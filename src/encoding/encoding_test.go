package encoding

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestUnicodePathHandling(t *testing.T) {
	testCases := []struct {
		name     string
		content  string
		expected string
	}{
		{
			name:     "German umlaut",
			content:  "root: C:\\\\Users\\\\Müller\\\\AppData\\\\Roaming\\\\nvm",
			expected: "Müller",
		},
		{
			name:     "French accent",
			content:  "root: C:\\\\Users\\\\René\\\\AppData\\\\Roaming\\\\nvm",
			expected: "René",
		},
		{
			name:     "Spanish tilde",
			content:  "root: C:\\\\Users\\\\José\\\\AppData\\\\Roaming\\\\nvm",
			expected: "José",
		},
		{
			name:     "Scandinavian characters",
			content:  "root: C:\\\\Users\\\\Åsa\\\\AppData\\\\Roaming\\\\nvm",
			expected: "Åsa",
		},
		{
			name:     "Mixed special chars",
			content:  "root: C:\\\\Users\\\\Silvère LESTANG\\\\AppData\\\\Roaming\\\\nvm",
			expected: "Silvère",
		},
		{
			name:     "Turkish characters",
			content:  "root: C:\\\\Users\\\\İşçi\\\\AppData\\\\Roaming\\\\nvm",
			expected: "İşçi",
		},
		{
			name:     "Polish characters",
			content:  "root: C:\\\\Users\\\\Łukasz\\\\AppData\\\\Roaming\\\\nvm",
			expected: "Łukasz",
		},
		{
			name:     "Czech characters",
			content:  "root: C:\\\\Users\\\\Vojtěch\\\\AppData\\\\Roaming\\\\nvm",
			expected: "Vojtěch",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Create temporary file
			tmpDir := t.TempDir()
			tmpFile := filepath.Join(tmpDir, "settings.txt")

			// Write with UTF-8 BOM
			err := WriteFileUTF8WithBOM(tmpFile, tc.content)
			if err != nil {
				t.Fatalf("Failed to write test file: %v", err)
			}

			// Read back
			content, err := ReadFileUTF8(tmpFile)
			if err != nil {
				t.Fatalf("Failed to read test file: %v", err)
			}

			// Check if special characters are preserved
			if !strings.Contains(content, tc.expected) {
				t.Errorf("Expected content to contain '%s', got: %s", tc.expected, content)
			}

			// Verify no replacement characters (�)
			if strings.Contains(content, "�") {
				t.Errorf("Content contains replacement character (�): %s", content)
			}
		})
	}
}

func TestToUTF8ValidString(t *testing.T) {
	input := "Hello Wörld - José René Müller Łukasz"
	result := ToUTF8(input)

	if string(result) != input {
		t.Errorf("ToUTF8 modified valid UTF-8 string. Expected: %s, Got: %s", input, string(result))
	}
}

func TestToUTF8WithInvalidRunes(t *testing.T) {
	// Create a string with invalid UTF-8 sequences
	invalidBytes := []byte{0xFF, 0xFE, 0xFD}
	input := string(invalidBytes) + "valid text"

	result := ToUTF8(input)

	// Result should be valid UTF-8
	if !strings.Contains(string(result), "valid text") {
		t.Errorf("ToUTF8 did not preserve valid part of string")
	}
}

func TestReadFileUTF8WithBOM(t *testing.T) {
	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "test_bom.txt")

	expectedContent := "root: C:\\\\Users\\\\Müller\\\\AppData\\\\Roaming\\\\nvm"

	// Write with BOM
	err := WriteFileUTF8WithBOM(tmpFile, expectedContent)
	if err != nil {
		t.Fatalf("Failed to write file with BOM: %v", err)
	}

	// Read and verify BOM is handled
	content, err := ReadFileUTF8(tmpFile)
	if err != nil {
		t.Fatalf("Failed to read file with BOM: %v", err)
	}

	if content != expectedContent {
		t.Errorf("BOM not properly handled. Expected: %s, Got: %s", expectedContent, content)
	}

	// Verify the file actually has BOM
	rawContent, _ := ioutil.ReadFile(tmpFile)
	if len(rawContent) < 3 || rawContent[0] != 0xEF || rawContent[1] != 0xBB || rawContent[2] != 0xBF {
		t.Error("File was not written with UTF-8 BOM")
	}
}

func TestReadFileUTF8WithoutBOM(t *testing.T) {
	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "test_no_bom.txt")

	expectedContent := "root: C:\\\\Users\\\\José\\\\AppData\\\\Roaming\\\\nvm"

	// Write without BOM
	err := WriteFileUTF8(tmpFile, expectedContent)
	if err != nil {
		t.Fatalf("Failed to write file without BOM: %v", err)
	}

	// Read and verify
	content, err := ReadFileUTF8(tmpFile)
	if err != nil {
		t.Fatalf("Failed to read file without BOM: %v", err)
	}

	if content != expectedContent {
		t.Errorf("Content mismatch. Expected: %s, Got: %s", expectedContent, content)
	}
}

func TestWriteReadCycle(t *testing.T) {
	// Test full write-read cycle with various special characters
	specialContents := []string{
		"root: C:\\\\Users\\\\Müller\\\\nvm",
		"root: C:\\\\Users\\\\Silvère\\\\nvm",
		"root: C:\\\\Users\\\\Åsa Öberg\\\\nvm",
		"root: C:\\\\Users\\\\Dr. José María\\\\nvm",
		"root: C:\\\\Users\\\\Łukasz Vojtěch\\\\nvm",
	}

	for i, expected := range specialContents {
		t.Run("Cycle_"+string(rune(i)), func(t *testing.T) {
			tmpDir := t.TempDir()
			tmpFile := filepath.Join(tmpDir, "settings.txt")

			// Write
			err := WriteFileUTF8WithBOM(tmpFile, expected)
			if err != nil {
				t.Fatalf("Failed to write: %v", err)
			}

			// Read
			actual, err := ReadFileUTF8(tmpFile)
			if err != nil {
				t.Fatalf("Failed to read: %v", err)
			}

			// Compare
			if actual != expected {
				t.Errorf("Write-read cycle failed. Expected: %s, Got: %s", expected, actual)
			}
		})
	}
}

func TestDetectCharset(t *testing.T) {
	utf8Content := []byte("Hello UTF-8 世界")
	charset, err := DetectCharset(utf8Content)
	if err != nil {
		t.Fatalf("Failed to detect charset: %v", err)
	}

	if charset != "UTF-8" {
		t.Errorf("Expected UTF-8, got: %s", charset)
	}
}

func TestReadNonExistentFile(t *testing.T) {
	_, err := ReadFileUTF8("/nonexistent/path/file.txt")
	if err == nil {
		t.Error("Expected error when reading non-existent file")
	}
	if !os.IsNotExist(err) {
		t.Errorf("Expected IsNotExist error, got: %v", err)
	}
}
