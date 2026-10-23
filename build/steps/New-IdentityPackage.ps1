param(
	[string]$Architecture = "amd64",
	[string]$BinRoot = "",
	[string]$NvmExe = "",
	[string]$Version = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\common.ps1")
$ctx = Initialize-NvmBuildContext -BinRoot $BinRoot

$installerRoot = Join-Path $ctx.RepoRoot "installer"
$template = Join-Path $installerRoot "identity\AppxManifest.xml.template"
if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
	throw "Identity manifest template missing: $template"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
	$Version = $ctx.CliVersion
}
if ([string]::IsNullOrWhiteSpace($NvmExe)) {
	$NvmExe = Join-Path $ctx.BinRoot "nvm.exe"
}

function ConvertTo-AppxVersion([string]$Raw) {
	$v = $Raw.Trim().TrimStart("v", "V")
	$core = $v
	$pre = ""
	if ($v.Contains("-")) {
		$bits = $v.Split("-", 2)
		$core = $bits[0]
		$pre = $bits[1]
	}
	$parts = $core.Split(".")
	$maj = 0; $min = 0; $pat = 0; $rev = 0
	if ($parts.Count -ge 1) { [void][int]::TryParse($parts[0], [ref]$maj) }
	if ($parts.Count -ge 2) { [void][int]::TryParse($parts[1], [ref]$min) }
	if ($parts.Count -ge 3) { [void][int]::TryParse($parts[2], [ref]$pat) }
	if (-not [string]::IsNullOrWhiteSpace($pre)) {
		$digits = ($pre -replace "[^\d]", "")
		[void][int]::TryParse($digits, [ref]$rev)
	}
	return "{0}.{1}.{2}.{3}" -f $maj, $min, $pat, $rev
}

function Get-PublisherFromSignedExe([string]$Exe) {
	if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
		return "CN=Author Software Inc."
	}
	$sig = Get-AuthenticodeSignature -LiteralPath $Exe
	if ($null -eq $sig -or $null -eq $sig.SignerCertificate) {
		return "CN=Author Software Inc."
	}
	$subject = [string]$sig.SignerCertificate.Subject
	if ([string]::IsNullOrWhiteSpace($subject)) {
		return "CN=Author Software Inc."
	}
	return $subject
}

function Resolve-MakeAppx {
	$fromPath = Get-Command makeappx -ErrorAction SilentlyContinue
	if ($null -ne $fromPath) {
		return [string]$fromPath.Source
	}
	$kitRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
	if (-not (Test-Path -LiteralPath $kitRoot -PathType Container)) {
		return ""
	}
	$candidate = Get-ChildItem -LiteralPath $kitRoot -Directory -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
		Sort-Object { [version]$_.Name } -Descending |
		ForEach-Object { Join-Path $_.FullName "x64\makeappx.exe" } |
		Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
		Select-Object -First 1
	if ($null -eq $candidate) {
		return ""
	}
	return [string]$candidate
}

$staging = Join-Path $ctx.BinRoot "identity-staging"
$outDir = Join-Path $ctx.BinRoot "identity"
New-Item -ItemType Directory -Force -Path $staging | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$publisher = Get-PublisherFromSignedExe -Exe $NvmExe
$appxVersion = ConvertTo-AppxVersion -Raw $Version
$manifestText = Get-Content -LiteralPath $template -Raw -Encoding UTF8
$manifestText = $manifestText.Replace("{{NAME}}", "AuthorSoftware.NVMWindows")
$manifestText = $manifestText.Replace("{{PUBLISHER}}", $publisher)
$manifestText = $manifestText.Replace("{{VERSION}}", $appxVersion)
$manifestText = $manifestText.Replace("{{DISPLAY}}", "NVM for Windows")
[System.IO.File]::WriteAllText((Join-Path $staging "AppxManifest.xml"), $manifestText, [System.Text.UTF8Encoding]::new($false))

$png = Join-Path $staging "StoreLogo.png"
$ico = Join-Path $installerRoot "assets\nvm.ico"
try {
	Add-Type -AssemblyName System.Drawing
	$icon = New-Object System.Drawing.Icon($ico, 50, 50)
	$bmp = $icon.ToBitmap()
	$bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
	$icon.Dispose()
} catch {
	Write-Warning "Could not rasterize nvm.ico; writing a 50x50 placeholder PNG"
	# 50x50 transparent PNG
	$bytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAIBJREFUeNrszTENACAQDLBwgP8/FhYgARL+F5CZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZkZ/gQYAPvwBFxuVfGxAAAAAElFTkSuQmCC")
	[System.IO.File]::WriteAllBytes($png, $bytes)
}

$makeappx = Resolve-MakeAppx
if ([string]::IsNullOrWhiteSpace($makeappx)) {
	Write-Warning "makeappx.exe not found; skipping identity .msix (toasts fail-open to AUMID)"
	return
}

$msix = Join-Path $outDir "NVMWindows.msix"
if (Test-Path -LiteralPath $msix) {
	Remove-Item -LiteralPath $msix -Force
}
& $makeappx pack /d $staging /p $msix /nv
if ($LASTEXITCODE -ne 0) {
	Write-Warning "makeappx pack failed ($LASTEXITCODE); skipping identity .msix"
	return
}
Write-Host "Identity package -> $msix (publisher $publisher version $appxVersion)"
return $msix
