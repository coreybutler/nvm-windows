# Special Characters in Usernames

## Overview

NVM for Windows now fully supports usernames containing special characters such as accents, umlauts, and other non-ASCII characters. This fix resolves issues where users with names like "Müller", "José", "René", or "Åsa" encountered failures during installation or when switching Node.js versions.

## Supported Characters

The following character types are now fully supported:

- **Western European**: à, á, â, ã, ä, å, ç, è, é, ê, ë, ì, í, î, ï, ñ, ò, ó, ô, õ, ö, ù, ú, û, ü
- **Northern European**: Å, Ä, Ö, å, ä, ö
- **Eastern European**: č, š, ž, ł, ń
- **Turkish**: ğ, ı, ş
- **Spaces and punctuation** in usernames (e.g., "Dr. Dennis W. Neder")

## How It Works

The fix implements proper UTF-8 encoding throughout nvm-windows:

1. **UTF-8 BOM Writing**: The `settings.txt` file is now written with UTF-8 encoding and a BOM (Byte Order Mark) for Windows compatibility
2. **Multi-encoding Reading**: The system can read files in UTF-8, UTF-16, and various Windows code pages
3. **Character Validation**: Ensures no replacement characters (�) appear in paths
4. **Short Path Fallback**: If Unicode paths fail, automatically falls back to Windows 8.3 short paths

## Troubleshooting

### Issue: nvm commands still show strange characters

If you see characters like `Anv�ndaren` or `M�ller` instead of proper accents:

**Solution 1: Verify Settings File**
```powershell
# Check the encoding of your settings.txt
Get-Content "$env:APPDATA\nvm\settings.txt" -Encoding UTF8
```

If the output shows `�` characters:

```cmd
# Manually fix the path
nvm root %APPDATA%\nvm
```

**Solution 2: Re-run Installation**

The fixed installer will automatically correct the encoding:

1. Download the latest nvm-windows installer
2. Run the installer (no need to uninstall first)
3. Use the same installation paths as before
4. Restart your terminal

### Issue: "path could not be found" errors

If you encounter errors like:
```
C:\Users\M�ller\AppData\Roaming\nvm could not be found or does not exist.
```

**Solution: Use Short Path**

Windows provides 8.3 short paths as a fallback:

```cmd
# Find your short path
dir /X %USERPROFILE%

# Example output:
# M�LLER~1    -> Müller

# Set nvm to use short path
nvm root C:\Users\MÜLLER~1\AppData\Roaming\nvm
```

### Issue: Settings file appears empty or corrupted

**Solution: Manual Recreation**

1. Backup existing settings:
   ```cmd
   copy %APPDATA%\nvm\settings.txt %APPDATA%\nvm\settings.txt.backup
   ```

2. Create new settings file with proper encoding:
   - Open Notepad
   - Type your settings:
     ```
     root: C:\Users\YourName\AppData\Roaming\nvm
     path: C:\Program Files\nodejs
     arch: 64
     proxy: none
     ```
   - Save As → Encoding: **UTF-8**
   - Save to: `%APPDATA%\nvm\settings.txt`

3. Test:
   ```cmd
   nvm list
   ```

## Verification

After applying the fix, verify it's working correctly:

### Check 1: Settings File

```powershell
# View settings content
Get-Content "$env:APPDATA\nvm\settings.txt" -Encoding UTF8

# Should show proper characters, not � symbols
```

### Check 2: File Encoding

```powershell
# Check if file has UTF-8 BOM
$bytes = [System.IO.File]::ReadAllBytes("$env:APPDATA\nvm\settings.txt")
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "✓ File has UTF-8 BOM" -ForegroundColor Green
} else {
    Write-Host "✗ File missing UTF-8 BOM" -ForegroundColor Red
}
```

### Check 3: Functionality Test

```cmd
# Full workflow test
nvm install 20.11.0
nvm use 20.11.0
node --version
npm --version

# Switch versions
nvm install 18.19.0
nvm use 18.19.0
node --version
```

All commands should complete without errors showing corrupted characters.

## Migration Guide

### For New Installations

No special steps needed! Just install nvm-windows normally. The installer will:
- Automatically detect your username
- Create settings.txt with proper UTF-8 encoding
- Configure all paths correctly

### For Existing Installations

**Option 1: In-Place Update (Recommended)**

1. Download latest nvm-windows installer
2. Run installer with same paths
3. Restart terminal
4. Verify with `nvm list`

**Option 2: Clean Reinstall**

If you want a completely fresh start:

1. **Backup node versions** (optional):
   ```cmd
   xcopy %APPDATA%\nvm %USERPROFILE%\nvm-backup /E /I
   ```

2. **Uninstall nvm-windows**:
   - Control Panel → Uninstall a Program
   - Select "NVM for Windows"
   - Uninstall

3. **Install new version**:
   - Download latest installer
   - Run with administrative privileges
   - Choose installation directory

4. **Restore nodes** (if backed up):
   ```cmd
   xcopy %USERPROFILE%\nvm-backup\v* %APPDATA%\nvm\ /E
   nvm list
   ```

## Known Limitations

### Very Long Paths (>260 characters)

Windows has a path length limitation. Enable long path support:

```powershell
# As Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

Restart required after this change.

### Emoji and Complex Unicode

Paths with emoji (😀) or complex scripts (Arabic, Chinese, Thai) may still have issues on some Windows versions. This is a Windows filesystem limitation, not an nvm-windows issue.

**Workaround**: Use short path fallback or create your user account with Latin characters.

### Network Drives (UNC Paths)

UNC paths like `\\server\share\Users\Müller` may need additional configuration:

```cmd
# Map network drive first
net use Z: \\server\share

# Then use mapped drive
nvm root Z:\Users\Mueller\AppData\Roaming\nvm
```

### Legacy Windows (7, 8, 8.1)

Full UTF-8 support may be limited on older Windows versions. Consider:
- Updating to Windows 10/11
- Using short path workaround
- Creating account with ASCII-only username

## Best Practices

### For System Administrators

When deploying nvm-windows in environments with international users:

1. **Test with various usernames** before broad deployment
2. **Document the short path workaround** for legacy systems
3. **Enable long path support** via Group Policy
4. **Use consistent installation paths** across all machines

### For Developers

When developing with nvm-windows:

1. **Test on real Windows accounts** with special characters
2. **Don't hardcode paths** - use environment variables
3. **Verify encoding** when reading/writing configuration files
4. **Report issues** with details about your specific character set

## Frequently Asked Questions

### Q: Do I need to reinstall Node.js versions?

**A:** No. Existing Node.js installations remain intact. Only the nvm-windows management layer is updated.

### Q: Will this fix work on Windows 7?

**A:** Partially. Windows 7 has limited UTF-8 support. The short path fallback should work, but we recommend Windows 10 or later.

### Q: Can I use this with WSL (Windows Subsystem for Linux)?

**A:** This fix is for Windows native nvm-windows. For WSL, use the original [nvm](https://github.com/nvm-sh/nvm) which already supports UTF-8.

### Q: What about spaces in usernames (e.g., "John Smith")?

**A:** Fully supported! Both spaces and special characters work correctly.

### Q: My company uses mandatory short usernames. Do I still benefit?

**A:** Yes! The fix improves overall path handling and encoding consistency, preventing future issues.

## Getting Help

If you encounter issues not covered here:

1. **Check Common Issues**: [Common Issues Wiki](https://github.com/coreybutler/nvm-windows/wiki/Common-Issues)
2. **Search Existing Issues**: [GitHub Issues](https://github.com/coreybutler/nvm-windows/issues?q=is%3Aissue+special+characters)
3. **Create New Issue**: Include:
   - Your Windows version
   - Your username (or example with similar characters)
   - Output of `nvm debug`
   - Contents of `settings.txt` (redact personal info)

## Related Issues

- [#887 - Issue with special characters in user folder breaks installation of npm](https://github.com/coreybutler/nvm-windows/issues/887)
- [#931 - nvm install crashes if userfolder has scandic](https://github.com/coreybutler/nvm-windows/issues/931)
- [#726 - "nvm could not be found" when user name has umlaut](https://github.com/coreybutler/nvm-windows/issues/726)
- [#1282 - nvm does not work when umlaut is in path](https://github.com/coreybutler/nvm-windows/issues/1282)

## Contributing

Found a character set that doesn't work? Help improve this fix:

1. Fork the repository
2. Add test cases for your character set
3. Submit a pull request with details

See [CONTRIBUTING.md](../CONTRIBUTING.md) for more information.
