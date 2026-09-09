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

function Resolve-NvmHotfixVersion {
	param(
		[Parameter(Mandatory = $true)]
		[string]$BaseVersion,
		[string]$Hotfix = ""
	)

	$base = $BaseVersion.Trim()
	if ([string]::IsNullOrWhiteSpace($base)) {
		throw "Resolve-NvmHotfixVersion: BaseVersion is empty"
	}

	$raw = if ($null -eq $Hotfix) { "" } else { $Hotfix.Trim() }
	if ([string]::IsNullOrWhiteSpace($raw)) {
		return $base
	}

	$suffix = $null
	if ($raw -match '^\d+$') {
		$suffix = "hotfix.$raw"
	}
	elseif ($raw -match '^(?i)hotfix\.(\d+)$') {
		$suffix = "hotfix.$($Matches[1])"
	}
	else {
		throw @"
Resolve-NvmHotfixVersion: invalid hotfix input '$raw'.
Use empty (no override), a digit run (e.g. 1 -> -hotfix.1), or hotfix.N (e.g. hotfix.1).
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

function Initialize-NvmBuildContext {
	param([string]$BinRoot = "")

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
	# Inno OutputBaseFilename: {manifest.name}-{version}-{arch}-setup
	return (Join-Path $DistRoot ("nvm-{0}-{1}-setup.exe" -f $Version, $Architecture))
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
	return (Join-Path $DistRoot ("nvm-{0}-{1}-sync.exe" -f $Version, $Architecture))
}

function Get-NvmSyncReleaseAssetName {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version,
		[Parameter(Mandatory = $true)]
		[ValidateSet("amd64", "arm64")]
		[string]$Architecture
	)
	return ("nvm-{0}-{1}-sync.exe" -f $Version, $Architecture)
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
