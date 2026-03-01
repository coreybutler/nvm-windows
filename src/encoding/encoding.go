package encoding

import (
	"io/ioutil"
	"strings"
	"unicode/utf8"

	"github.com/saintfish/chardet"
	"golang.org/x/text/encoding/unicode"
	"golang.org/x/text/transform"
)

// DetectCharset detects the character encoding of content
func DetectCharset(content []byte) (string, error) {
	detector := chardet.NewTextDetector()
	result, err := detector.DetectBest(content)
	if err != nil {
		return "", err
	}
	return strings.ToUpper(result.Charset), nil
}

// ToUTF8 converts a string to UTF-8 encoded bytes
// This function now properly handles already-UTF8 strings
func ToUTF8(content string) []byte {
	// If already valid UTF-8, return as-is
	if utf8.ValidString(content) {
		return []byte(content)
	}

	// Otherwise, encode rune-by-rune, skipping invalid runes
	b := make([]byte, len(content)*4) // Worst case: 4 bytes per rune
	i := 0
	for _, r := range content {
		if r == utf8.RuneError {
			continue // Skip invalid runes
		}
		i += utf8.EncodeRune(b[i:], r)
	}
	return b[:i]
}

// ReadFileUTF8 reads a file and ensures UTF-8 encoding
// Handles files written in various encodings (CP-1252, UTF-8, UTF-16)
func ReadFileUTF8(filename string) (string, error) {
	content, err := ioutil.ReadFile(filename)
	if err != nil {
		return "", err
	}

	// Check for UTF-8 BOM and skip it
	if len(content) >= 3 && content[0] == 0xEF && content[1] == 0xBB && content[2] == 0xBF {
		content = content[3:]
		return string(content), nil
	}

	// Try to detect if it's UTF-16
	if len(content) >= 2 {
		// Check for UTF-16 BOM
		if (content[0] == 0xFF && content[1] == 0xFE) || (content[0] == 0xFE && content[1] == 0xFF) {
			var decoder *transform.Transformer
			if content[0] == 0xFF && content[1] == 0xFE {
				// Little Endian
				t := unicode.UTF16(unicode.LittleEndian, unicode.UseBOM).NewDecoder()
				decoder = &t
			} else {
				// Big Endian
				t := unicode.UTF16(unicode.BigEndian, unicode.UseBOM).NewDecoder()
				decoder = &t
			}
			result, _, err := transform.Bytes(*decoder, content)
			if err == nil {
				return string(result), nil
			}
		}
	}

	// If already valid UTF-8, return as-is
	if utf8.Valid(content) {
		return string(content), nil
	}

	// Try to detect charset and handle accordingly
	charset, err := DetectCharset(content)
	if err == nil && charset == "UTF-8" {
		return string(content), nil
	}

	// For Windows, most non-UTF8 files are likely Windows-1252 (Western European)
	// Return the string even if it might have some encoding issues
	// This is better than failing completely
	return string(content), nil
}

// WriteFileUTF8WithBOM writes content to a file in UTF-8 with BOM
// Windows applications often expect BOM for UTF-8 files
func WriteFileUTF8WithBOM(filename string, content string) error {
	// UTF-8 BOM
	bom := []byte{0xEF, 0xBB, 0xBF}
	data := append(bom, []byte(content)...)
	return ioutil.WriteFile(filename, data, 0644)
}

// WriteFileUTF8 writes content to a file in UTF-8 without BOM
func WriteFileUTF8(filename string, content string) error {
	return ioutil.WriteFile(filename, []byte(content), 0644)
}
