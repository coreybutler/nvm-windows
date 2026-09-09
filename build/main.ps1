param(
	[ValidateSet("amd64", "arm64")]
	[string]$Architecture = "",
	[ValidateSet("All", "Cli", "Shims", "Sync")]
	[string]$Component = "All",
	[string]$BinRoot = "",
	[switch]$SkipInstaller,
	[switch]$DownloadSync,
	[string]$SyncReleaseTag = "",
	[string]$SyncReleaseRepo = "nvm-windows/nvm"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "common.ps1")

if ([string]::IsNullOrWhiteSpace($Architecture)) {
	$Architecture = Resolve-NvmHostArchitecture
}

$ctx = Initialize-NvmBuildContext -BinRoot $BinRoot
$stepRoot = Join-Path $PSScriptRoot "steps"
$commonArgs = @{
	Architecture = $Architecture
	BinRoot      = $ctx.BinRoot
}
$syncArgs = @{
	Architecture    = $Architecture
	BinRoot         = $ctx.BinRoot
	SyncReleaseTag  = $SyncReleaseTag
	SyncReleaseRepo = $SyncReleaseRepo
}
if ($DownloadSync) {
	$syncArgs["DownloadSync"] = $true
}

Write-Host "Community build"
Write-Host "  RepoRoot         -> $($ctx.RepoRoot)"
Write-Host "  BinRoot          -> $($ctx.BinRoot)"
Write-Host "  Architecture     -> $Architecture"
Write-Host "  Component        -> $Component"
Write-Host "  SkipInstaller    -> $SkipInstaller"
Write-Host "  DownloadSync     -> $DownloadSync"
if ($DownloadSync) {
	Write-Host "  SyncReleaseTag   -> $(if ([string]::IsNullOrWhiteSpace($SyncReleaseTag)) { '(from CLI manifest)' } else { $SyncReleaseTag })"
	Write-Host "  SyncReleaseRepo  -> $SyncReleaseRepo"
}
Write-Host "  CLI version      -> $($ctx.CliVersion)"
Write-Host "  Signing          -> Authenticode via Artifact Signing (Events.dll = message resource only)"

switch ($Component) {
	"All" {
		& (Join-Path $stepRoot "Build-Cli.ps1") @commonArgs
		& (Join-Path $stepRoot "Build-EventProvider.ps1") @commonArgs
		& (Join-Path $stepRoot "Build-Shims.ps1") @commonArgs
		& (Join-Path $stepRoot "Build-Sync.ps1") @syncArgs
	}
	"Cli" {
		& (Join-Path $stepRoot "Build-Cli.ps1") @commonArgs
		& (Join-Path $stepRoot "Build-EventProvider.ps1") @commonArgs
	}
	"Shims" {
		& (Join-Path $stepRoot "Build-Shims.ps1") @commonArgs
	}
	"Sync" {
		& (Join-Path $stepRoot "Build-Sync.ps1") @syncArgs
	}
}

$expected = Get-NvmExpectedExePaths -BinRoot $ctx.BinRoot -Component $Component
Write-NvmPayloadSummary -Paths $expected -Title "Executables" -DisplayRoot $ctx.BinRoot -SkipJobSummary

if ($Component -eq "All" -or $Component -eq "Cli") {
	$eventAssets = Get-NvmExpectedEventProviderPaths -BinRoot $ctx.BinRoot
	Write-NvmPayloadSummary -Paths $eventAssets -Title "Event provider" -DisplayRoot $ctx.BinRoot -SkipJobSummary
}

if ($Component -ne "All") {
	Write-Host "Skipping Inno Setup (requires -Component All; got $Component)." -ForegroundColor Yellow
}
elseif ($SkipInstaller) {
	Write-Host "Skipping Inno Setup (-SkipInstaller)." -ForegroundColor Yellow
}
else {
	& (Join-Path $stepRoot "Build-Installer.ps1") @commonArgs
	$setup = Get-NvmInstallerSetupPath -Version $ctx.CliVersion -Architecture $Architecture -DistRoot $ctx.DistRoot
	Write-NvmPayloadSummary -Paths @($setup) -Title "Installer" -DisplayRoot $ctx.RepoRoot
}

Write-Host "Build complete ($Component)."
