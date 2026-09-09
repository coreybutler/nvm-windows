# Ensures Azure.CodeSigning.Dlib.dll is available for community Authenticode signing.
# Adapted from certified/enhanced/scripts/Ensure-Dependencies.ps1 (-SigningOnly).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-EnvOrEmpty {
	param([string]$Name)
	$value = [Environment]::GetEnvironmentVariable($Name)
	if ($null -eq $value) { return "" }
	return $value.Trim()
}

function Get-ArtifactSigningToolsRoot {
	$fromEnv = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_TOOLS_DIR"
	if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
		return [System.IO.Path]::GetFullPath($fromEnv)
	}
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	return [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".tools\artifact-signing"))
}

function Get-ArtifactSigningClientVersion {
	$fromEnv = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_CLIENT_VERSION"
	if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
		return $fromEnv.Trim()
	}
	return "1.0.95"
}

function Find-ArtifactSigningDlib {
	$fromEnv = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_DLIB"
	if ([string]::IsNullOrWhiteSpace($fromEnv)) {
		$fromEnv = Get-EnvOrEmpty -Name "TRUSTED_SIGNING_DLIB"
	}
	if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
		$full = [System.IO.Path]::GetFullPath($fromEnv)
		if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
			throw "ARTIFACT_SIGNING_DLIB path missing: $full"
		}
		return $full
	}

	$toolsRoot = Get-ArtifactSigningToolsRoot
	$known = @(
		(Join-Path $toolsRoot "bin\x64\Azure.CodeSigning.Dlib.dll"),
		(Join-Path $toolsRoot "Azure.CodeSigning.Dlib.dll"),
		(Join-Path $toolsRoot "x64\Azure.CodeSigning.Dlib.dll"),
		(Join-Path $env:LOCALAPPDATA "Microsoft\MicrosoftArtifactSigningClientTools\Azure.CodeSigning.Dlib.dll"),
		(Join-Path $env:LOCALAPPDATA "Microsoft\MicrosoftArtifactSigningClientTools\x64\Azure.CodeSigning.Dlib.dll")
	)
	foreach ($candidate in $known) {
		if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
			return $candidate
		}
	}

	if (Test-Path -LiteralPath $toolsRoot -PathType Container) {
		$hit = Get-ChildItem -LiteralPath $toolsRoot -Recurse -Filter "Azure.CodeSigning.Dlib.dll" -ErrorAction SilentlyContinue |
			Where-Object { $_.FullName -match '(?i)[\\/]x64[\\/]' } |
			Select-Object -First 1
		if ($null -ne $hit) { return $hit.FullName }
		$hit = Get-ChildItem -LiteralPath $toolsRoot -Recurse -Filter "Azure.CodeSigning.Dlib.dll" -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($null -ne $hit) { return $hit.FullName }
	}
	return $null
}

function Install-ArtifactSigningClientTools {
	$toolsRoot = Get-ArtifactSigningToolsRoot
	$version = Get-ArtifactSigningClientVersion
	New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null

	$existing = Find-ArtifactSigningDlib
	if (-not [string]::IsNullOrWhiteSpace($existing) -and $existing.StartsWith($toolsRoot, [StringComparison]::OrdinalIgnoreCase)) {
		Write-Host "Artifact Signing client already present -> $existing"
		return
	}

	$nupkgPath = Join-Path $toolsRoot "client.nupkg"
	$extractRoot = Join-Path $toolsRoot "pkg"
	$url = "https://www.nuget.org/api/v2/package/Microsoft.Trusted.Signing.Client/$version"
	Write-Host "Downloading Microsoft.Trusted.Signing.Client $version..."
	$prev = $ProgressPreference
	$ProgressPreference = "SilentlyContinue"
	try {
		Invoke-WebRequest -Uri $url -OutFile $nupkgPath -UseBasicParsing
	}
	finally {
		$ProgressPreference = $prev
	}

	if (Test-Path -LiteralPath $extractRoot) {
		Remove-Item -LiteralPath $extractRoot -Recurse -Force
	}
	New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
	$zipPath = Join-Path $toolsRoot "client.zip"
	Copy-Item -LiteralPath $nupkgPath -Destination $zipPath -Force
	Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

	$dlib = Get-ChildItem -LiteralPath $extractRoot -Recurse -Filter "Azure.CodeSigning.Dlib.dll" -File -ErrorAction SilentlyContinue |
		Where-Object { $_.FullName -match '(?i)[\\/](bin[\\/])?x64[\\/]' } |
		Select-Object -First 1
	if ($null -eq $dlib) {
		$dlib = Get-ChildItem -LiteralPath $extractRoot -Recurse -Filter "Azure.CodeSigning.Dlib.dll" -File -ErrorAction SilentlyContinue |
			Select-Object -First 1
	}
	if ($null -eq $dlib) {
		throw "Azure.CodeSigning.Dlib.dll not found in NuGet package"
	}

	$binOut = Join-Path $toolsRoot "bin\x64"
	New-Item -ItemType Directory -Force -Path $binOut | Out-Null
	Copy-Item -LiteralPath $dlib.FullName -Destination (Join-Path $binOut "Azure.CodeSigning.Dlib.dll") -Force
	Get-ChildItem -LiteralPath $dlib.Directory.FullName -File -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -ne "Azure.CodeSigning.Dlib.dll" } |
		ForEach-Object { Copy-Item $_.FullName (Join-Path $binOut $_.Name) -Force }

	$env:ARTIFACT_SIGNING_DLIB = Join-Path $binOut "Azure.CodeSigning.Dlib.dll"
	Write-Host "Staged Artifact Signing dlib -> $($env:ARTIFACT_SIGNING_DLIB)"
	Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
}

$found = Find-ArtifactSigningDlib
if ([string]::IsNullOrWhiteSpace($found)) {
	Install-ArtifactSigningClientTools
	$found = Find-ArtifactSigningDlib
}
if ([string]::IsNullOrWhiteSpace($found)) {
	throw "Artifact Signing dlib still missing after install"
}
$env:ARTIFACT_SIGNING_DLIB = $found
Write-Host "ARTIFACT_SIGNING_DLIB -> $found"
