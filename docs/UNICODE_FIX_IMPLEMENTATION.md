# Unicode Special Characters Fix - Implementation Guide

## Overview

This document provides a comprehensive guide for fixing the special character handling issue in nvm-windows where usernames containing accents, umlauts, or other non-ASCII characters cause installation and operation failures.

**Related Issues:** #887, #931, #726, #1282, #1006, #1097

## Root Cause

The problem occurs in three main areas:

1. **Settings File Writing**: The `settings.txt` file is written without proper UTF-8 encoding
2. **Settings File Reading**: File reading doesn't handle various encodings correctly
3. **Path Operations**: Corrupted path strings fail filesystem operations

## Changes Required in `src/nvm.go`

### 1. Update `setup()` Function

Replace the existing file reading code with the new UTF-8-aware function:

```go
func setup() {
	// Use the new UTF-8 aware reading function
	content, err := encoding.ReadFileUTF8(env.settings)
	if err != nil {
		fmt.Println("\nERROR", err)
		os.Exit(1)
	}

	lines := strings.Split(content, "\n")

	// Process each line and extract the value
	m := make(map[string]string)
	for _, line := range lines {
		line = strings.TrimSpace(line)
		line = os.ExpandEnv(line)
		res := strings.SplitN(line, ":", 2) // Use SplitN to handle colons in paths (e.g., C:)
		if len(res) < 2 {
			continue
		}
		key := strings.TrimSpace(res[0])
		value := strings.TrimSpace(res[1])
		m[key] = value
	}

	// Parse settings with validation
	if val, ok := m["root"]; ok {
		env.root = filepath.Clean(val)
		// Validate that the root path exists
		if _, err := os.Stat(env.root); os.IsNotExist(err) {
			fmt.Printf("WARNING: NVM root directory does not exist: %s\n", env.root)
		}
	}
	
	if val, ok := m["originalpath"]; ok {
		env.originalpath = val
	}
	if val, ok := m["originalversion"]; ok {
		env.originalversion = val
	}
	if val, ok := m["arch"]; ok {
		env.arch = val
	}
	if val, ok := m["node_mirror"]; ok {
		env.node_mirror = val
	}
	if val, ok := m["npm_mirror"]; ok {
		env.npm_mirror = val
	}

	if val, ok := m["proxy"]; ok {
		if val != "none" && val != "" {
			if !strings.HasPrefix(strings.ToLower(val), "http") {
				val = "http://" + val
			}
			res, err := url.Parse(val)
			if err == nil {
				web.SetProxy(res.String(), env.verifyssl)
				env.proxy = res.String()
			}
		}
	}

	web.SetMirrors(env.node_mirror, env.npm_mirror)
	env.arch = arch.Validate(env.arch)

	// Make sure the directories exist
	if _, e := os.Stat(env.root); e != nil {
		fmt.Println(env.root + " could not be found or does not exist. Exiting.")
		return
	}
}
```

### 2. Update `saveSettings()` Function

Replace the existing function with UTF-8 BOM writing:

```go
func saveSettings() {
	// Build content with proper UTF-8 encoding
	content := fmt.Sprintf("root: %s\r\narch: %s\r\nproxy: %s\r\noriginalpath: %s\r\noriginalversion: %s\r\nnode_mirror: %s\r\nnpm_mirror: %s\r\n",
		strings.TrimSpace(env.root),
		strings.TrimSpace(env.arch),
		strings.TrimSpace(env.proxy),
		strings.TrimSpace(env.originalpath),
		strings.TrimSpace(env.originalversion),
		strings.TrimSpace(env.node_mirror),
		strings.TrimSpace(env.npm_mirror))

	// Write with UTF-8 encoding (with BOM for Windows compatibility)
	err := encoding.WriteFileUTF8WithBOM(env.settings, content)
	if err != nil {
		writeToErrorLog(fmt.Sprintf("Failed to save settings: %v", err))
		fmt.Printf("WARNING: Failed to save settings to %s: %v\n", env.settings, err)
	}

	// Verify the write was successful
	if verifyErr := verifySettingsIntegrity(); verifyErr != nil {
		writeToErrorLog(fmt.Sprintf("Settings verification failed: %v", verifyErr))
		fmt.Printf("WARNING: Settings file may be corrupted: %v\n", verifyErr)
	}

	os.Setenv("NVM_HOME", strings.TrimSpace(env.root))
}
```

### 3. Add New Helper Functions

Add these functions to `nvm.go`:

```go
// verifySettingsIntegrity checks if settings file was written correctly
func verifySettingsIntegrity() error {
	content, err := encoding.ReadFileUTF8(env.settings)
	if err != nil {
		return fmt.Errorf("cannot read settings file: %w", err)
	}

	// Check if root path exists in the content
	if !strings.Contains(content, env.root) {
		return fmt.Errorf("root path not found or corrupted in settings file")
	}

	return nil
}

// Windows-specific path handling using syscall
var (
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	procGetShortPathNameW = kernel32.NewProc("GetShortPathNameW")
)

// GetShortPath converts a long Windows path to its 8.3 short format
// This is a fallback for paths with special characters
func GetShortPath(longPath string) (string, error) {
	longPathPtr, err := syscall.UTF16PtrFromString(longPath)
	if err != nil {
		return longPath, err
	}

	// First call to get required buffer size
	requiredSize, _, _ := procGetShortPathNameW.Call(
		uintptr(unsafe.Pointer(longPathPtr)),
		0,
		0,
	)

	if requiredSize == 0 {
		return longPath, fmt.Errorf("failed to get short path for: %s", longPath)
	}

	// Allocate buffer and get the short path
	shortPath := make([]uint16, requiredSize)
	ret, _, _ := procGetShortPathNameW.Call(
		uintptr(unsafe.Pointer(longPathPtr)),
		uintptr(unsafe.Pointer(&shortPath[0])),
		uintptr(requiredSize),
	)

	if ret == 0 {
		return longPath, fmt.Errorf("failed to convert to short path: %s", longPath)
	}

	return syscall.UTF16ToString(shortPath), nil
}

// GetSafePath attempts to return a path that works on Windows
// Priority: 1) Original path if valid, 2) Short path as fallback
func GetSafePath(path string) string {
	// First check if the original path works
	if _, err := os.Stat(path); err == nil {
		return path
	}

	// Try to get short path as fallback
	if shortPath, err := GetShortPath(path); err == nil {
		if _, err := os.Stat(shortPath); err == nil {
			utility.DebugLogf("Using short path: %s -> %s", path, shortPath)
			return shortPath
		}
	}

	// Return original path even if it doesn't exist
	// (might be a path that will be created later)
	return path
}
```

### 4. Remove Old `encode()` Function

The old `encode()` function is no longer needed and should be removed:

```go
// DELETE THIS FUNCTION:
// func encode(val string) string {
//     converted := encoding.ToUTF8(val)
//     return string(converted)
// }
```

## Dependencies Update

Update `go.mod` to include the required dependency:

```go
require (
    // ... existing dependencies ...
    golang.org/x/text v0.14.0
)
```

Run: `go get golang.org/x/text@v0.14.0`

## Testing

### Automated Tests

```bash
# Run encoding tests
cd src/encoding
go test -v

# Expected output: All tests pass
```

### Manual Testing

1. **Create test user with special characters**:
   ```powershell
   # As Administrator
   New-LocalUser -Name "TestMüller" -Password (ConvertTo-SecureString "TestPass123!" -AsPlainText -Force)
   ```

2. **Test installation**:
   ```cmd
   nvm install 20.11.0
   nvm use 20.11.0
   node --version
   ```

3. **Verify settings.txt**:
   ```powershell
   # Check file encoding
   Get-Content "$env:APPDATA\nvm\settings.txt" -Encoding UTF8
   # Should show proper characters, not �
   ```

4. **Test switching versions**:
   ```cmd
   nvm install 18.19.0
   nvm list
   nvm use 18.19.0
   node --version
   ```

## Migration Guide for Users

### For Users with Corrupted Settings

If you have an existing installation with corrupted settings:

1. **Backup current settings**:
   ```cmd
   copy %APPDATA%\nvm\settings.txt %APPDATA%\nvm\settings.txt.backup
   ```

2. **Update to new version**:
   - Download and install the fixed version

3. **Fix corrupted settings** (if needed):
   ```cmd
   nvm root %APPDATA%\nvm
   ```

4. **Verify fix**:
   ```cmd
   nvm list
   nvm use <version>
   ```

### Alternative: Use Short Path

If issues persist, use Windows 8.3 short path:

```cmd
# Get short path
dir /X %USERPROFILE%

# Example output: TESTM~1 -> TestMüller
# Then set:
nvm root C:\Users\TESTM~1\AppData\Roaming\nvm
```

## Known Limitations

1. **Very Long Paths (>260 chars)**: Enable long path support in Windows
2. **Emoji/Complex Unicode**: May have issues on some Windows versions
3. **Network Drives**: UNC paths with special characters need additional handling
4. **Legacy Windows (7/8)**: Limited UTF-8 support

## Rollback Procedure

If the fix causes issues:

1. **Keep backup**:
   ```cmd
   copy %APPDATA%\nvm\settings.txt.backup %APPDATA%\nvm\settings.txt
   ```

2. **Revert to previous version**:
   - Download previous nvm-windows version
   - Replace nvm.exe

3. **Report issue**: Create GitHub issue with details

## Contributing

When contributing to this fix:

1. Follow the [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines
2. Ensure all tests pass
3. Test with multiple special character sets
4. Update documentation as needed
5. Reference the related issues in commits

## References

- [Issue #887](https://github.com/coreybutler/nvm-windows/issues/887)
- [Issue #931](https://github.com/coreybutler/nvm-windows/issues/931)
- [Issue #726](https://github.com/coreybutler/nvm-windows/issues/726)
- [Windows UTF-8 Support](https://docs.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page)
- [Go Unicode Support](https://go.dev/blog/strings)
