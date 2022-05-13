package arch

import (
  //"regexp"
  "os"
  //"os/exec"
  "strings"
  //"fmt"
  "encoding/hex"
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
  is64 := SearchBytesInFile(path, "504500006486", 400);
  is32 := SearchBytesInFile(path, "504500004C", 400);
  if is64 {
    return "64";
  } else if is32 {
    return "32";
  }
  return "?";
}

func Validate(str string) (string){
  if str == "" {
    str = os.Getenv("PROCESSOR_ARCHITECTURE")
  }
  if strings.ContainsAny("64",str) {
    return "64"
  } else {
    return "32"
  }
}
