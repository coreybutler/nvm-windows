param(
	[ValidateSet("amd64", "arm64")]
	[string]$Architecture = "amd64",
	[string]$BinRoot = "",
	[switch]$IncludeInstaller,
	[switch]$InstallerOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\common.ps1")
$ctx = Initialize-NvmBuildContext -BinRoot $BinRoot

$signScript = Join-Path $PSScriptRoot "..\scripts\Sign-Executables.ps1"
if (-not (Test-Path -LiteralPath $signScript -PathType Leaf)) {
	throw "Sign-Executables.ps1 not found: $signScript"
}

$ensureScript = Join-Path $PSScriptRoot "..\scripts\Ensure-ArtifactSigning.ps1"
if (Test-Path -LiteralPath $ensureScript -PathType Leaf) {
	& $ensureScript *>&1 | ForEach-Object { Write-Host "$_" }
}

$signable = New-Object System.Collections.Generic.List[string]
if (-not $InstallerOnly) {
	foreach ($path in (Get-NvmExpectedExePaths -BinRoot $ctx.BinRoot -Component All)) {
		Assert-NvmFile -Path $path -Label ([System.IO.Path]::GetFileName($path)) | Out-Null
		$signable.Add($path)
	}
}

if ($IncludeInstaller -or $InstallerOnly) {
	$setup = Get-NvmInstallerSetupPath -Version $ctx.CliVersion -Architecture $Architecture -DistRoot $ctx.DistRoot
	$syncAsset = Get-NvmSyncReleaseAssetPath -Version $ctx.CliVersion -Architecture $Architecture -DistRoot $ctx.DistRoot
	Assert-NvmFile -Path $setup -Label ([System.IO.Path]::GetFileName($setup)) | Out-Null
	Assert-NvmFile -Path $syncAsset -Label ([System.IO.Path]::GetFileName($syncAsset)) | Out-Null
	$signable.Add($setup)
	$signable.Add($syncAsset)
}

if ($signable.Count -eq 0) {
	throw "No community artifacts selected for signing"
}

$correlation = [Environment]::GetEnvironmentVariable("ARTIFACT_SIGNING_CORRELATION_ID")
if ([string]::IsNullOrWhiteSpace($correlation) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) {
	$correlation = "gha-community-{0}-{1}" -f $env:GITHUB_RUN_ID, $env:GITHUB_RUN_ATTEMPT
}

$signArgs = @{ Path = $signable.ToArray() }
$dlibFromEnv = [Environment]::GetEnvironmentVariable("ARTIFACT_SIGNING_DLIB")
if (-not [string]::IsNullOrWhiteSpace($dlibFromEnv) -and (Test-Path -LiteralPath $dlibFromEnv -PathType Leaf)) {
	$signArgs["DlibPath"] = $dlibFromEnv
}
if (-not [string]::IsNullOrWhiteSpace($correlation)) {
	$signArgs["CorrelationId"] = $correlation
}

Write-Host "Signing community artifacts ($($signable.Count) file(s))..."
& $signScript @signArgs
