package arch

import (
	//"regexp"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func SearchBytesInFile( path string, match string, limit int) bool {
  // Transform to byte array the string
  toMatch, err := hex.DecodeString(match);
  if (err != nil) {
    return false;
  }
  
  // Opening the file and checking if there is an error
  file, err := os.Open(path)
  if err != nil {
    return false;
  }

  // Close file upon return
  defer file.Close()

  // Allocate 1 byte array to perform the match
  bit := make([]byte, 1);
  j := 0
  for i := 0; i < limit; i++ {
    file.Read(bit);

    if bit[0] != toMatch[j] {
      j = 0;
    }
    if bit[0] == toMatch[j] {
      j++;
      if (j >= len(toMatch)) {
        file.Close();
        return true;
      }
    }
  }
  file.Close();
  return false;
}

func Bit(path string) string {
  isarm64 := SearchBytesInFile(path, "5045000064AA", 400)
  is64 := SearchBytesInFile(path, "504500006486", 400);
  is32 := SearchBytesInFile(path, "504500004C", 400);
  if isarm64 {
	return "arm64";
  } else if is64 {
    return "64";
  } else if is32 {
    return "32";
  }
  return "?";
}

func Validate(str string) (string){
  osArch, err := GetOSArchitecture()
  if err != nil {
  	fmt.Println("Failed to get OS architecture:", err)
  }  
  if str == "" {
    str = strings.ToLower(os.Getenv("PROCESSOR_ARCHITECTURE"))
  }
  if strings.Contains(str, "arm64") || strings.Contains(strings.ToLower(osArch), "arm") {
	  return "arm64"
  }
  if strings.Contains(str, "64") {
    return "64"
  } 
  return "32"
}

func GetOSArchitecture() (string, error) {
	cmd := exec.Command("wmic", "os", "get", "osarchitecture")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.Contains(line, "OSArchitecture") {
			continue
		}
		return line, nil
	}
	return "", fmt.Errorf("failed to find OS architecture")
}
