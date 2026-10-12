# Shared paths/helpers for community nvm/build.
# Dot-source from main.ps1 or step scripts; then call Initialize-NvmBuildContext.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script:NvmBuildDir = $PSScriptRoot
$script:NvmRepoRoot = Split-Path -Parent $script:NvmBuildDir

function Get-NvmRepoRoot {
	return $script:NvmRepoRoot
}

function Get-NvmBuildDir {
	return $script:NvmBuildDir
}

function Get-NvmDefaultBinRoot {
	return (Join-Path $script:NvmRepoRoot "bin")
}

function Get-NvmDistRoot {
	return (Join-Path $script:NvmRepoRoot ".dist")
}

function Format-NvmByteSize {
	param([long]$Bytes)

	if ($Bytes -ge 1GB) {
		return ("{0:N1} GB" -f ($Bytes / 1GB))
	}
	if ($Bytes -ge 1MB) {
		return ("{0:N1} MB" -f ($Bytes / 1MB))
	}
	if ($Bytes -ge 1KB) {
		return ("{0:N1} KB" -f ($Bytes / 1KB))
	}
	return "$Bytes B"
}

function Get-NvmCliManifestPath {
	return (Join-Path $script:NvmRepoRoot "cli\src\manifest.json")
}

function Get-NvmCliVersion {
	# GHA / packaging: set NVM_CLI_VERSION (e.g. prepare.outputs.version with hotfix stamp).
	$fromEnv = [Environment]::GetEnvironmentVariable("NVM_CLI_VERSION")
	if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
		return $fromEnv.Trim()
	}
	$manifestPath = Get-NvmCliManifestPath
	if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
		throw "CLI manifest not found: $manifestPath"
	}
	$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
	$version = [string]$manifest.version
	if ([string]::IsNullOrWhiteSpace($version)) {
		throw "CLI manifest does not define version: $manifestPath"
	}
	return $version
}

function Get-NvmLatestStableReleaseVersion {
	param(
		[string]$Repo = "nvm-windows/nvm"
	)

	$repo = $Repo.Trim()
	if ([string]::IsNullOrWhiteSpace($repo)) {
		throw "Get-NvmLatestStableReleaseVersion: Repo is empty"
	}

	$raw = & gh api --paginate "repos/$repo/releases?per_page=100"
	if ($LASTEXITCODE -ne 0) {
		throw "Get-NvmLatestStableReleaseVersion: gh api repos/$repo/releases failed with exit code $LASTEXITCODE"
	}
	if ([string]::IsNullOrWhiteSpace($raw)) {
		throw "Get-NvmLatestStableReleaseVersion: no GitHub releases for $repo. Fill in Hotfix base."
	}

	$releases = @($raw | ConvertFrom-Json)
	foreach ($rel in $releases) {
		if ($rel.prerelease -or $rel.draft) { continue }
		$tag = [string]$rel.tag_name
		if ($tag -match '^v?(?<ver>\d+\.\d+\.\d+)$') {
			return $Matches["ver"]
		}
	}

	throw "Get-NvmLatestStableReleaseVersion: no stable x.y.z release found for $repo. Fill in Hotfix base with a version such as 2.0.1."
}

function Resolve-NvmReleaseVersion {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ManifestVersion,
		[string]$Kind = "none",
		[string]$PrereleaseNumber = "",
		[string]$HotfixBase = ""
	)

	$manifest = $ManifestVersion.Trim()
	if ($manifest -notmatch '^\d+\.\d+\.\d+$') {
		throw ("Resolve-NvmReleaseVersion: manifest version '{0}' must be major.minor.patch." -f $manifest)
	}

	$kind = if ([string]::IsNullOrWhiteSpace($Kind)) { "none" } else { $Kind.Trim().ToLowerInvariant() }
	$allowed = @("none", "alpha", "beta", "rc", "hotfix")
	if ($allowed -notcontains $kind) {
		throw ("Resolve-NvmReleaseVersion: release kind '{0}' must be none, alpha, beta, rc, or hotfix." -f $kind)
	}

	$number = if ($null -eq $PrereleaseNumber) { "" } else { $PrereleaseNumber.Trim() }
	$hotfix = if ($null -eq $HotfixBase) { "" } else { $HotfixBase.Trim() }
	$hotfix = $hotfix -replace '^[vV]', ''

	if ($kind -eq "none") {
		if (-not [string]::IsNullOrWhiteSpace($number)) {
			throw "Resolve-NvmReleaseVersion: Prerelease number is only used for alpha, beta, rc, and hotfix. Leave it empty when Release kind is none."
		}
		return $manifest
	}

	if ($number -notmatch '^[1-9]\d*$') {
		throw ("Resolve-NvmReleaseVersion: Prerelease number is required when Release kind is {0}. Use a positive integer such as 1." -f $kind)
	}

	if ($kind -eq "hotfix") {
		if ([string]::IsNullOrWhiteSpace($hotfix)) {
			throw "Resolve-NvmReleaseVersion: Hotfix base is empty. Fill in a prior stable version such as 2.0.1, or leave the form empty so the latest non-prerelease release is used."
		}
		if ($hotfix -notmatch '^\d+\.\d+\.\d+$') {
			throw ("Resolve-NvmReleaseVersion: Hotfix base '{0}' must be major.minor.patch with no prerelease suffix." -f $hotfix)
		}
		return "{0}-hotfix.{1}" -f $hotfix, $number
	}

	return "{0}-{1}.{2}" -f $manifest, $kind, $number
}

function Resolve-NvmHotfixVersion {
	param(
		[Parameter(Mandatory = $true)]
		[string]$BaseVersion,
		# Optional prerelease stamp (workflow input name may be prerelease/hotfix).
		[Alias("Prerelease")]
		[string]$Hotfix = ""
	)

	$base = $BaseVersion.Trim()
	if ([string]::IsNullOrWhiteSpace($base)) {
		throw "Resolve-NvmHotfixVersion: BaseVersion is empty"
	}
	if ($base -notmatch '^\d+\.\d+\.\d+$') {
		throw ("Resolve-NvmHotfixVersion: base version '{0}' must be major.minor.patch (no prerelease). Stamp via workflow input instead." -f $base)
	}

	$raw = if ($null -eq $Hotfix) { "" } else { $Hotfix.Trim() }
	if ([string]::IsNullOrWhiteSpace($raw)) {
		return $base
	}

	# Allow accidental "-beta.1" / "vbeta.1" from copy-paste.
	$raw = $raw -replace '^[vV-]+', ''
	if ([string]::IsNullOrWhiteSpace($raw)) {
		return $base
	}

	$suffix = $null
	if ($raw -match '^\d+$') {
		# Bare digit keeps historical hotfix.N (WiX/Inno revision mapping).
		$suffix = "hotfix.$raw"
	}
	elseif ($raw -match '^[A-Za-z0-9][A-Za-z0-9.-]*$') {
		# Any semver-ish prerelease id: beta.1, hotfix.1, rc.1, preview.3, …
		$suffix = $raw
	}
	else {
		throw @"
Resolve-NvmHotfixVersion: invalid prerelease stamp '$raw'.
Use empty (manifest version), a digit (1 -> -hotfix.1), or a stamp like beta.1 / hotfix.1 / rc.1.
"@
	}

	return "{0}-{1}" -f $base, $suffix
}

function Set-NvmCliManifestVersion {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version
	)

	$ver = $Version.Trim()
	if ([string]::IsNullOrWhiteSpace($ver)) {
		throw "Set-NvmCliManifestVersion: Version is empty"
	}

	$manifestPath = Get-NvmCliManifestPath
	if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
		throw "CLI manifest not found: $manifestPath"
	}

	$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
	$before = [string]$manifest.version
	$manifest.version = $ver

	$json = $manifest | ConvertTo-Json -Depth 30
	$utf8NoBom = New-Object System.Text.UTF8Encoding $false
	[System.IO.File]::WriteAllText($manifestPath, ($json.TrimEnd() + "`n"), $utf8NoBom)

	Write-Host ("CLI manifest version -> {0} (was {1}) [{2}]" -f $ver, $before, $manifestPath)
}

function Use-NvmZigOnPath {
	$existing = Get-Command zig -ErrorAction SilentlyContinue
	if ($existing -and (Test-Path -LiteralPath $existing.Source -PathType Leaf)) {
		return $existing.Source
	}

	$wanted = ""
	$zigVersionFile = Join-Path $script:NvmRepoRoot "shim\.zigversion"
	if (Test-Path -LiteralPath $zigVersionFile -PathType Leaf) {
		$wanted = (Get-Content -LiteralPath $zigVersionFile -TotalCount 1).Trim()
	}

	$candidates = [System.Collections.Generic.List[string]]::new()
	if (-not [string]::IsNullOrWhiteSpace($wanted)) {
		$candidates.Add((Join-Path $env:LOCALAPPDATA "Programs\zig-$wanted\zig.exe"))
		$candidates.Add((Join-Path $env:LOCALAPPDATA "zig-$wanted\zig.exe"))
	}
	$candidates.Add((Join-Path $env:LOCALAPPDATA "Programs\zig\zig.exe"))

	foreach ($exe in $candidates) {
		if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
			continue
		}
		$dir = Split-Path -Parent $exe
		if ($env:Path -notlike "*$dir*") {
			$env:Path = "$dir;$env:Path"
		}
		Write-Host "zig (session PATH) -> $exe"
		return $exe
	}

	$hint = if ([string]::IsNullOrWhiteSpace($wanted)) { "zig" } else { "zig $wanted" }
	throw @"
$hint not on PATH. This PowerShell session was opened before Zig was installed.
Install from https://ziglang.org/download/ then reopen the terminal, or:
  `$env:Path = `"`$env:LOCALAPPDATA\Programs\zig-$wanted;`" + `$env:Path
"@
}

function Initialize-NvmBuildContext {
	param(
		[string]$BinRoot = "",
		[switch]$SkipZig
	)

	# Release version gate and manifest stamp run before setup-zig.
	if (-not $SkipZig) {
		Use-NvmZigOnPath | Out-Null
	}

	$resolvedBin = if ([string]::IsNullOrWhiteSpace($BinRoot)) {
		Get-NvmDefaultBinRoot
	}
	else {
		[System.IO.Path]::GetFullPath($BinRoot)
	}

	New-Item -ItemType Directory -Force -Path $resolvedBin | Out-Null
	New-Item -ItemType Directory -Force -Path (Join-Path $resolvedBin "utils") | Out-Null
	New-Item -ItemType Directory -Force -Path (Join-Path $resolvedBin ".shim") | Out-Null
	New-Item -ItemType Directory -Force -Path (Join-Path $resolvedBin ".sync") | Out-Null

	return [pscustomobject]@{
		RepoRoot   = $script:NvmRepoRoot
		BuildDir   = $script:NvmBuildDir
		BinRoot    = $resolvedBin
		DistRoot   = (Get-NvmDistRoot)
		CliVersion = (Get-NvmCliVersion)
	}
}

function Assert-NvmFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[string]$Label = "file"
	)

	$full = [System.IO.Path]::GetFullPath($Path)
	if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
		throw ("Expected {0} missing: {1}" -f $Label, $full)
	}
	return $full
}

function Get-NvmExpectedExePaths {
	param(
		[Parameter(Mandatory = $true)]
		[string]$BinRoot,
		[ValidateSet("All", "Cli", "Shims", "Sync")]
		[string]$Component = "All"
	)

	$paths = New-Object System.Collections.Generic.List[string]
	switch ($Component) {
		"Cli" {
			$paths.Add((Join-Path $BinRoot "nvm.exe"))
		}
		"Shims" {
			$paths.Add((Join-Path $BinRoot ".shim\node.exe"))
			$paths.Add((Join-Path $BinRoot "utils\proxy.exe"))
			$paths.Add((Join-Path $BinRoot "utils\reshim.exe"))
		}
		"Sync" {
			$paths.Add((Join-Path $BinRoot "utils\sync.exe"))
		}
		"All" {
			$paths.Add((Join-Path $BinRoot "nvm.exe"))
			$paths.Add((Join-Path $BinRoot ".shim\node.exe"))
			$paths.Add((Join-Path $BinRoot "utils\proxy.exe"))
			$paths.Add((Join-Path $BinRoot "utils\reshim.exe"))
			$paths.Add((Join-Path $BinRoot "utils\sync.exe"))
		}
	}
	return $paths.ToArray()
}

function Get-NvmExpectedEventProviderPaths {
	param(
		[Parameter(Mandatory = $true)]
		[string]$BinRoot
	)

	$manifestPath = Get-NvmCliManifestPath
	$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
	$manName = [string]$manifest.eventLabel
	if ([string]::IsNullOrWhiteSpace($manName)) {
		$manName = "NVMWindows.Events.man"
	}
	$dllName = [System.IO.Path]::ChangeExtension($manName, ".dll")
	return @(
		(Join-Path $BinRoot $manName),
		(Join-Path $BinRoot $dllName)
	)
}

function Get-NvmReleaseArchToken {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet("amd64", "arm64")]
		[string]$Architecture
	)
	# Go/build target stays amd64. Published installer and sync asset names use x64.
	if ($Architecture -eq "amd64") {
		return "x64"
	}
	return $Architecture
}

function Get-NvmInstallerSetupPath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version,
		[Parameter(Mandatory = $true)]
		[ValidateSet("amd64", "arm64")]
		[string]$Architecture,
		[string]$DistRoot = ""
	)

	if ([string]::IsNullOrWhiteSpace($DistRoot)) {
		$DistRoot = Get-NvmDistRoot
	}
	# Inno OutputBaseFilename: nvm-{version}-{x64|arm64}-setup
	$archToken = Get-NvmReleaseArchToken -Architecture $Architecture
	return (Join-Path $DistRoot ("nvm-{0}-{1}-setup.exe" -f $Version, $archToken))
}

function Get-NvmSyncReleaseAssetPath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version,
		[Parameter(Mandatory = $true)]
		[ValidateSet("amd64", "arm64")]
		[string]$Architecture,
		[string]$DistRoot = ""
	)

	if ([string]::IsNullOrWhiteSpace($DistRoot)) {
		$DistRoot = Get-NvmDistRoot
	}
	# Staged next to setup for GitHub Release upload / -DownloadSync fetch
	$archToken = Get-NvmReleaseArchToken -Architecture $Architecture
	return (Join-Path $DistRoot ("nvm-{0}-{1}-sync.exe" -f $Version, $archToken))
}

function Get-NvmSyncReleaseAssetName {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version,
		[Parameter(Mandatory = $true)]
		[ValidateSet("amd64", "arm64")]
		[string]$Architecture
	)
	$archToken = Get-NvmReleaseArchToken -Architecture $Architecture
	return ("nvm-{0}-{1}-sync.exe" -f $Version, $archToken)
}

function Add-NvmGitHubJobSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Markdown
	)

	if ([string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
		return
	}
	Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $Markdown -Encoding utf8
}

function Write-NvmJobSummaryTable {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Title,
		[AllowEmptyCollection()]
		[object[]]$Rows = @(),
		[string]$EmptyMessage = "_None._",
		[string]$Note = ""
	)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("## $Title")
	$lines.Add("")
	if (-not [string]::IsNullOrWhiteSpace($Note)) {
		$lines.Add($Note)
		$lines.Add("")
	}

	if ($null -eq $Rows -or $Rows.Count -eq 0) {
		$lines.Add($EmptyMessage)
		$lines.Add("")
		Add-NvmGitHubJobSummary -Markdown ($lines -join "`n")
		return
	}

	$lines.Add("| Status | Size | Path |")
	$lines.Add("| --- | --- | --- |")
	foreach ($row in $Rows) {
		$status = [string]$row.Status
		$size = [string]$row.Size
		$path = if ($row.PSObject.Properties["Display"] -and $row.Display) { [string]$row.Display } else { [string]$row.Output }
		$path = $path.Replace("|", "\|")
		$lines.Add(("| {0} | {1} | ``{2}`` |" -f $status, $size, $path))
	}
	$lines.Add("")
	Add-NvmGitHubJobSummary -Markdown ($lines -join "`n")
}

function Write-NvmPayloadSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Paths,
		[string]$Title = "Payload summary",
		[string]$DisplayRoot = "",
		[switch]$SkipThrowOnMissing,
		[switch]$SkipJobSummary
	)

	$rootFull = ""
	if (-not [string]::IsNullOrWhiteSpace($DisplayRoot)) {
		$rootFull = [System.IO.Path]::GetFullPath($DisplayRoot).TrimEnd('\', '/')
	}

	$rows = foreach ($path in $Paths) {
		$full = [System.IO.Path]::GetFullPath($path)
		$exists = Test-Path -LiteralPath $full -PathType Leaf
		$size = ""
		if ($exists) {
			$size = Format-NvmByteSize -Bytes (Get-Item -LiteralPath $full).Length
		}
		$display = $full
		if ($rootFull -and $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
			$rel = $full.Substring($rootFull.Length).TrimStart('\', '/')
			if (-not [string]::IsNullOrWhiteSpace($rel)) {
				$display = $rel -replace '\\', '/'
			}
		}
		[pscustomobject]@{
			Status  = if ($exists) { "OK" } else { "MISSING" }
			Size    = $size
			Output  = $full
			Display = $display
		}
	}

	Write-Host ""
	Write-Host $Title
	Write-Host ("=" * [Math]::Max(3, $Title.Length))
	$rows | Format-Table -AutoSize Status, Size, @{ Label = "Output"; Expression = { $_.Display } }

	if (-not $SkipJobSummary) {
		Write-NvmJobSummaryTable -Title $Title -Rows $rows
	}

	if (-not $SkipThrowOnMissing) {
		$missing = @($rows | Where-Object { $_.Status -eq "MISSING" })
		if ($missing.Count -gt 0) {
			throw ("Missing {0} expected payload path(s)." -f $missing.Count)
		}
	}
}

function Write-NvmBuildJobSummaryHeader {
	param(
		[string]$Version = "",
		[string]$Architecture = "",
		[string]$ZigVersion = ""
	)

	if ([string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
		return
	}

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# Community build")
	$lines.Add("")
	$lines.Add("| | |")
	$lines.Add("| --- | --- |")
	if (-not [string]::IsNullOrWhiteSpace($Version)) {
		$lines.Add("| Version | $Version |")
	}
	if (-not [string]::IsNullOrWhiteSpace($Architecture)) {
		$lines.Add("| Architecture | $Architecture |")
	}
	if (-not [string]::IsNullOrWhiteSpace($ZigVersion)) {
		$lines.Add("| Zig | $ZigVersion |")
	}
	$lines.Add("| Signing | Authenticode (Artifact Signing) |")
	$lines.Add("")
	Add-NvmGitHubJobSummary -Markdown ($lines -join "`n")
}

function Resolve-NvmHostArchitecture {
	if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
		return "arm64"
	}
	return "amd64"
}
