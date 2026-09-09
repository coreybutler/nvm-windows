# Community build

Authenticode-signed Inno Setup pipeline for NVM for Windows (core / community). No COSE worker signing, no SBOM, no SLSA, no ADMX, no MSI/Intune.

Produces `nvm.exe`, ETW event provider assets (`NVMWindows.Events.man` + `NVMWindows.Events.dll`), shims (`node` / `proxy` / `reshim`), `sync.exe`, and one Inno Setup `.exe`. Sync worker DLLs come from the certified release CDN (`assets.nvm-windows.com`) — this build does not compile them (CDN workers are already COSE Sign1'd by the certified pipeline).

`NVMWindows.Events.dll` is a wevtutil message/resource DLL only. Same as certified: **not** Authenticode-signed (Artifact Signing covers `.exe`/`.msi`) and **not** COSE-signed (COSE is for sync workers).

The `sync` Git submodule is **private**. Maintainers/CI compile it from source. Public from-source builds use `-DownloadSync` to fetch the matching release asset.

## Local

Requires: Go (see `cli/src/go.mod`), [qgo](https://github.com/quikdev/go), Zig (`shim/.zigversion`), [Inno Setup](https://jrsoftware.org/isdl.php) 6.7.1+, `go-winres`.

```powershell
# Maintainer / CI (sync submodule present)
.\build\main.ps1
.\build\main.ps1 -Architecture amd64
.\build\main.ps1 -Architecture arm64 -SkipInstaller
.\build\main.ps1 -Component Cli

# Public clone (no sync source): download prebuilt sync.exe from the GitHub Release
.\build\main.ps1 -DownloadSync
.\build\main.ps1 -DownloadSync -SyncReleaseTag v2.0.0
.\build\main.ps1 -Component Sync -DownloadSync
```

`.\build.ps1` still forwards to `.\build\main.ps1`.

| Flag | Purpose |
|------|---------|
| `-DownloadSync` | Fetch `nvm-<version>-<arch>-sync.exe` from GitHub Releases instead of compiling sync |
| `-SyncReleaseTag` | Override release tag (default: `v` + `cli/src/manifest.json` version) |
| `-SyncReleaseRepo` | Override `owner/repo` (default: `nvm-windows/nvm`) |

Output:

- Executables → `bin\`
- Event provider → `bin\NVMWindows.Events.man`, `bin\NVMWindows.Events.dll` (shipped next to `nvm.exe` in the installer)
- Installer → `.dist\nvm-<version>-<arch>-setup.exe`
- Staged sync release asset → `.dist\nvm-<version>-<arch>-sync.exe`

Requires Windows SDK (`mc.exe` / `rc.exe`) and Visual Studio `link.exe` for the event resource DLL.

## GHA

Workflow: [Release Community Build](../.github/workflows/release.yml) (`workflow_dispatch`).

| Input | Default | Purpose |
|-------|---------|---------|
| `architecture` | `both` | `amd64`, `arm64`, or both |
| `publish_release` | true | Draft → upload assets → publish |
| `override_existing_release` | false | Replace setup.exe **and** sync.exe on existing tag |
| `hotfix` | _(empty)_ | Optional stamp: `1` or `hotfix.1` → `{manifest}-hotfix.N` without committing `cli/src/manifest.json` |

GitHub Release assets per architecture:

- `nvm-<version>-<arch>-setup.exe` — Inno Setup installer
- `nvm-<version>-<arch>-sync.exe` — prebuilt sync for `-DownloadSync`

Tag = `v` + effective version (`cli/src/manifest.json` version, plus optional `hotfix` stamp). Runner patches manifest before CLI/Inno build so embeds and `AppVersion` match. Inno `VersionInfoVersion` already maps `-hotfix.N` → fourth numeric field (`2.0.1-hotfix.1` → `2.0.1.1`). Hotfix stamps mark the GitHub Release as **`--prerelease`**.

### WinGet

Workflow: [Publish to WinGet](../.github/workflows/winget.yml) (`workflow_dispatch`).

Use it only after a public GitHub Release has both `amd64` and `arm64` setup assets. It:

1. Downloads release installers.
2. Generates `AuthorSoftware.NVMforWindows` manifests and SHA256 values.
3. Verifies anonymous public release URLs produce matching hashes.
4. Runs `winget validate`.
5. By default, runs a silent install smoke test from the downloaded amd64 setup asset, runs `nvm --version`, then uninstalls.
6. Uploads the generated manifests as a workflow artifact.
7. When `dry_run` is **false**, runs `wingetcreate submit` against `microsoft/winget-pkgs` (needs package already present under that ID).

`dry_run` defaults to **true** (validate only). Live submit needs secret `WINGET_CREATE_GITHUB_TOKEN` (classic PAT with `public_repo` on a fork of `microsoft/winget-pkgs`).

Inputs:

| Input | Default | Purpose |
|-------|---------|---------|
| `release` | `latest` | `latest` = newest stable GitHub Release (no drafts/pre-releases). `custom` = use `release_tag`. |
| `release_tag` | empty | Tag for `custom` (e.g. `v2.0.0-alpha.2`). Ignored when `release=latest`. |
| `dry_run` | true | **On:** generate manifest, `winget validate`, upload artifact — no PR. **Off:** submit to `microsoft/winget-pkgs` (public repo + `WINGET_CREATE_GITHUB_TOKEN`). |
| `install_test` | true | Silent install smoke test via local `release-assets` installer (not `winget install`). 4 min process timeout + 5 min step cap. Warns/skips on failure; never fails dry-run. |
| `verify_public_urls` | true | Anonymous GitHub release download + SHA256 must match manifest hashes. Fails workflow on mismatch (dry-run or publish). |

### Secrets

| Name | Purpose |
|------|---------|
| `GH_APP_CLIENT_ID` | GitHub App client ID (submodule checkout) |
| `GH_APP_PRIVATE_KEY` | App private key PEM |
| `WINGET_CREATE_GITHUB_TOKEN` | Classic PAT (`public_repo`) for WinGet submit when `dry_run=false` |

App install on `nvm-windows` must include **nvm**, **cli**, **common**, **shim**, **sync** (or all repos), **Contents: Read**. Inno Setup lives in-repo at `installer/` (not a submodule). Release publish uses `github.token` (`contents: write`).

Immutable releases: published tag locks forever. Bump manifest version, or turn immutable off and set `override_existing_release`.
