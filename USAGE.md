
# NVM for Windows Usage Instructions

## Overview

NVM for Windows is a Node.js version manager designed specifically for Windows. It allows you to install, manage, and switch between multiple versions of Node.js easily. This tool is not the same as the original nvm for macOS/Linux; it uses a different architecture tailored for Windows.

**Important Note:** NVM for Windows requires administrative privileges to run certain commands, such as `nvm use` or `nvm install`, because it manages symlinks. Always run your command prompt or PowerShell as an Administrator.

## Installation

### Prerequisites
- Uninstall any existing Node.js installations to avoid conflicts. Delete directories like `C:\Program Files\nodejs` and clear related environment variables.
- Backup any global npm configurations (e.g., `%AppData%\npm\etc\npmrc`) or copy them to your user config (`%UserProfile%\.npmrc`).

### Steps
1. Download the latest installer from the [releases page](https://github.com/coreybutler/nvm-windows/releases).
2. Run the installer as an Administrator.
3. Follow the on-screen instructions. Accept the default paths unless you have a specific reason to change them:
   - NVM Home: `C:\nvm` (where Node.js versions are stored).
   - Symlink: `C:\Program Files\nodejs` (or a custom path like `C:\nvm\node` to avoid conflicts).
4. After installation, restart your terminal or PowerShell.
5. Verify installation by running `nvm version`.

If you encounter issues, refer to the [Common Issues Wiki](https://github.com/coreybutler/nvm-windows/wiki/Common-Issues).

## Upgrading NVM for Windows

To upgrade:
1. Download the latest installer.
2. Run it as an Administrator. It will overwrite necessary files without affecting your installed Node.js versions.
3. Use the same installation paths as before.

As of version 1.1.8, you can use the built-in upgrade utility if available.

## Basic Commands

Run these in an Administrator-elevated Command Prompt or PowerShell. Type `nvm` for a list of commands.

### nvm arch [32|64]
- **Description:** Displays or sets the architecture (32-bit or 64-bit) for Node.js.
- **Examples:**
  - `nvm arch` – Shows the current architecture.
  - `nvm arch 64` – Sets to 64-bit mode.

### nvm debug
- **Description:** Checks for common problems in your NVM setup, such as PATH conflicts.
- **Example:** `nvm debug`

### nvm current
- **Description:** Displays the currently active Node.js version.
- **Example:** `nvm current`

### nvm install <version> [arch]
- **Description:** Installs a specific Node.js version. Use "latest" for the newest release, "lts" for the latest LTS version. Optionally specify architecture (32 or 64). Add `--insecure` to bypass SSL checks if needed.
- **Examples:**
  - `nvm install latest` – Installs the latest Node.js version.
  - `nvm install lts` – Installs the latest LTS version.
  - `nvm install 20.10.0 64` – Installs version 20.10.0 in 64-bit.
  - `nvm install 18.0.0 all` – Installs both 32-bit and 64-bit versions.

### nvm list [available]
- **Description:** Lists installed Node.js versions. Add "available" to list downloadable versions.
- **Examples:**
  - `nvm list` – Lists installed versions.
  - `nvm list available` – Lists available versions for download.

### nvm on
- **Description:** Enables NVM version management.
- **Example:** `nvm on`

### nvm off
- **Description:** Disables NVM version management (does not uninstall Node.js).
- **Example:** `nvm off`

### nvm proxy [url]
- **Description:** Sets or views the proxy for downloads. Use "none" to remove.
- **Examples:**
  - `nvm proxy` – Shows current proxy.
  - `nvm proxy http://proxy.example.com:8080` – Sets a proxy.
  - `nvm proxy none` – Removes the proxy.

### nvm uninstall <version>
- **Description:** Uninstalls a specific Node.js version.
- **Example:** `nvm uninstall 14.17.0`

### nvm use <version> [arch]
- **Description:** Switches to the specified version. Use "latest", "lts", or "newest" (latest installed). Optionally specify architecture.
- **Examples:**
  - `nvm use latest` – Switches to the latest version.
  - `nvm use lts` – Switches to the latest LTS.
  - `nvm use 20.10.0 32` – Switches to 32-bit version 20.10.0.
- **Note:** This updates across all open consoles and persists after reboot.

### nvm root <path>
- **Description:** Sets or displays the directory where Node.js versions are stored.
- **Examples:**
  - `nvm root` – Shows current root.
  - `nvm root C:\custom\nvm` – Sets a new root.

### nvm version
- **Description:** Displays the NVM for Windows version.
- **Example:** `nvm version`

### nvm node_mirror <url>
- **Description:** Sets a custom mirror for Node.js downloads (useful in regions like China).
- **Example:** `nvm node_mirror https://npmmirror.com/mirrors/node/`

### nvm npm_mirror <url>
- **Description:** Sets a custom mirror for npm downloads.
- **Example:** `nvm npm_mirror https://npmmirror.com/mirrors/npm/`

## Common Tasks

### Switching Node.js Versions
1. Install versions: `nvm install 18` and `nvm install 20`.
2. Switch: `nvm use 18`.
3. Verify: `node -v`.

### Managing Global Packages
Global packages are not shared between versions. Reinstall for each:
- `nvm use 18`
- `npm install -g yarn`
- `nvm use 20`
- `npm install -g yarn`

### Using .nvmrc for Project-Specific Versions
Create a `.nvmrc` file in your project root with the version (e.g., `18`). Then run `nvm use` in that directory.

## Troubleshooting
- **Permission Issues:** Run as Administrator.
- **PATH Conflicts:** Run `nvm debug` and uninstall conflicting Node.js installations.
- **Antivirus Interference:** Temporarily disable antivirus if issues arise (e.g., McAfee).
- **Symlink Problems:** Ensure the symlink path is not an existing directory.
- For more, see the [Common Issues Wiki](https://github.com/coreybutler/nvm-windows/wiki/Common-Issues).

## Additional Resources
- [GitHub Repository](https://github.com/coreybutler/nvm-windows)
- [Discussions](https://github.com/coreybutler/nvm-windows/discussions)
- [Contributing](CONTRIBUTING.md)
- [Support](SUPPORT.md)

This document is based on NVM for Windows version 1.1.11+. Check for updates in the README.md. 