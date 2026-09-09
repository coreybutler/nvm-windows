param(
	[Parameter(Mandatory = $true)]
	[string[]]$Path,

	[string]$Endpoint = "",
	[string]$AccountName = "",
	[string]$CertificateProfileName = "",
	[string]$TimestampUrl = "http://timestamp.acs.microsoft.com",
	[string]$SignToolPath = "",
	[string]$DlibPath = "",
	[string]$MetadataPath = "",
	[string]$CorrelationId = "",
	# default | environment | azure-cli
	[string]$AuthMode = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-EnvOrEmpty {
	param([string]$Name)
	$value = [Environment]::GetEnvironmentVariable($Name)
	if ($null -eq $value) {
		return ""
	}
	return $value.Trim()
}

function Resolve-SignToolPath {
	param([string]$ExplicitPath)

	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		$full = [System.IO.Path]::GetFullPath($ExplicitPath)
		if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
			throw "SignTool not found at $full"
		}
		return $full
	}

	$fromPath = Get-Command signtool -ErrorAction SilentlyContinue
	if ($null -ne $fromPath -and -not [string]::IsNullOrWhiteSpace([string]$fromPath.Source)) {
		return [string]$fromPath.Source
	}

	$kitRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
	if (-not (Test-Path -LiteralPath $kitRoot -PathType Container)) {
		throw "SignTool not found on PATH and Windows Kits bin root missing: $kitRoot"
	}

	$candidate = Get-ChildItem -LiteralPath $kitRoot -Directory -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
		Sort-Object { [version]$_.Name } -Descending |
		ForEach-Object { Join-Path $_.FullName "x64\signtool.exe" } |
		Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
		Select-Object -First 1

	if ([string]::IsNullOrWhiteSpace([string]$candidate)) {
		throw "Unable to locate x64 signtool.exe under $kitRoot"
	}
	return [string]$candidate
}

function Resolve-ArtifactSigningDlibPath {
	param([string]$ExplicitPath)

	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		$full = [System.IO.Path]::GetFullPath($ExplicitPath)
		if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
			throw "Artifact Signing dlib not found at $full"
		}
		return $full
	}

	$fromEnv = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_DLIB"
	if ([string]::IsNullOrWhiteSpace($fromEnv)) {
		$fromEnv = Get-EnvOrEmpty -Name "TRUSTED_SIGNING_DLIB"
	}
	if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
		$full = [System.IO.Path]::GetFullPath($fromEnv)
		if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
			throw "Artifact Signing dlib from env not found: $full"
		}
		return $full
	}

	$searchRoots = @(
		${env:ProgramFiles},
		${env:ProgramFiles(x86)},
		(Join-Path $env:LOCALAPPDATA "Microsoft")
	) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Container) }

	$candidates = foreach ($root in $searchRoots) {
		Get-ChildItem -LiteralPath $root -Recurse -Filter "Azure.CodeSigning.Dlib.dll" -ErrorAction SilentlyContinue
	}
	if ($null -eq $candidates) {
		throw @"
Artifact Signing dlib (Azure.CodeSigning.Dlib.dll) not found.

Install client tools:
  winget install -e --id Microsoft.Azure.ArtifactSigningClientTools

Or set ARTIFACT_SIGNING_DLIB to Azure.CodeSigning.Dlib.dll path.
"@
	}

	$preferred = @($candidates | Where-Object { $_.FullName -match '(?i)[\\/]x64[\\/]' } | Select-Object -First 1)
	if ($preferred.Count -gt 0) {
		return $preferred[0].FullName
	}
	return (@($candidates | Select-Object -First 1))[0].FullName
}

function Get-ExcludeCredentialsForAuthMode {
	param([string]$Mode)

	$normalized = $Mode.Trim().ToLowerInvariant()
	switch ($normalized) {
		"" { return @() }
		"default" { return @() }
		"environment" {
			return @(
				"ManagedIdentityCredential",
				"WorkloadIdentityCredential",
				"SharedTokenCacheCredential",
				"VisualStudioCredential",
				"VisualStudioCodeCredential",
				"AzureCliCredential",
				"AzurePowerShellCredential",
				"AzureDeveloperCliCredential",
				"InteractiveBrowserCredential"
			)
		}
		"azure-cli" {
			return @(
				"ManagedIdentityCredential",
				"EnvironmentCredential",
				"WorkloadIdentityCredential",
				"SharedTokenCacheCredential",
				"VisualStudioCredential",
				"VisualStudioCodeCredential",
				"AzurePowerShellCredential",
				"AzureDeveloperCliCredential",
				"InteractiveBrowserCredential"
			)
		}
		default {
			throw "Unsupported AuthMode '$Mode'. Use default, environment, or azure-cli."
		}
	}
}

function Format-SignToolFailureHint {
	param([string]$LogText)

	$hints = New-Object System.Collections.Generic.List[string]
	if ($LogText -match 'Status:\s*403') {
		$hints.Add("Azure returned 403 Forbidden. Grant the signing identity 'Artifact Signing Certificate Profile Signer' on account '$AccountName' (profile '$CertificateProfileName').")
		$hints.Add("If AZURE_CLIENT_ID/SECRET are set, dlib uses that service principal first — role must be on the SP, not only your user.")
		$hints.Add("Confirm Endpoint region matches the Artifact Signing account region.")
	}
	if ($LogText -match 'AADSTS50173|grant has expired|TokensValidFrom') {
		$hints.Add("Azure CLI grant expired/revoked. Re-auth for Artifact Signing scope:")
		$hints.Add('  az logout')
		$hints.Add('  az login --scope "https://codesigning.azure.net/.default"')
		$hints.Add("Then set ARTIFACT_SIGNING_AUTH=azure-cli (or -AuthMode azure-cli) so SP env vars are ignored.")
	}
	if ($LogText -match 'CredentialUnavailableException' -and $LogText -match 'AzureCliCredential') {
		$hints.Add("AzureCliCredential unavailable. Run az login with codesigning scope, or use AuthMode=environment with a correctly permissioned SP.")
	}
	return ($hints -join [Environment]::NewLine)
}

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
	$Endpoint = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_ENDPOINT"
	if ([string]::IsNullOrWhiteSpace($Endpoint)) {
		$Endpoint = Get-EnvOrEmpty -Name "TRUSTED_SIGNING_ENDPOINT"
	}
}
if ([string]::IsNullOrWhiteSpace($AccountName)) {
	$AccountName = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_ACCOUNT"
	if ([string]::IsNullOrWhiteSpace($AccountName)) {
		$AccountName = Get-EnvOrEmpty -Name "TRUSTED_SIGNING_ACCOUNT"
	}
}
if ([string]::IsNullOrWhiteSpace($CertificateProfileName)) {
	$CertificateProfileName = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_CERTIFICATE_PROFILE"
	if ([string]::IsNullOrWhiteSpace($CertificateProfileName)) {
		$CertificateProfileName = Get-EnvOrEmpty -Name "TRUSTED_SIGNING_CERTIFICATE_PROFILE"
	}
}
if ([string]::IsNullOrWhiteSpace($CorrelationId)) {
	$CorrelationId = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_CORRELATION_ID"
}
if ([string]::IsNullOrWhiteSpace($AuthMode)) {
	$AuthMode = Get-EnvOrEmpty -Name "ARTIFACT_SIGNING_AUTH"
	if ([string]::IsNullOrWhiteSpace($AuthMode)) {
		$AuthMode = "default"
	}
}

if ([string]::IsNullOrWhiteSpace($Endpoint) -or [string]::IsNullOrWhiteSpace($AccountName) -or [string]::IsNullOrWhiteSpace($CertificateProfileName)) {
	throw @"
Artifact Signing configuration incomplete.

Provide -Endpoint / -AccountName / -CertificateProfileName, or set:
  ARTIFACT_SIGNING_ENDPOINT
  ARTIFACT_SIGNING_ACCOUNT
  ARTIFACT_SIGNING_CERTIFICATE_PROFILE

(Legacy TRUSTED_SIGNING_* env names also accepted.)
"@
}

$signTool = Resolve-SignToolPath -ExplicitPath $SignToolPath
$dlib = Resolve-ArtifactSigningDlibPath -ExplicitPath $DlibPath
$excludeCredentials = @(Get-ExcludeCredentialsForAuthMode -Mode $AuthMode)

$metadataFile = $MetadataPath
$tempMetadata = $false
if ([string]::IsNullOrWhiteSpace($metadataFile)) {
	$metadataFile = Join-Path ([System.IO.Path]::GetTempPath()) ("artifact-signing-{0}.json" -f [guid]::NewGuid().ToString("N"))
	$tempMetadata = $true
}

$metadata = [ordered]@{
	Endpoint = $Endpoint.TrimEnd("/")
	CodeSigningAccountName = $AccountName
	CertificateProfileName = $CertificateProfileName
}
if (-not [string]::IsNullOrWhiteSpace($CorrelationId)) {
	$metadata["CorrelationId"] = $CorrelationId
}
if ($excludeCredentials.Count -gt 0) {
	$metadata["ExcludeCredentials"] = $excludeCredentials
}

$metadataJson = ($metadata | ConvertTo-Json -Depth 5)
[System.IO.File]::WriteAllText($metadataFile, $metadataJson, [System.Text.UTF8Encoding]::new($false))

$files = New-Object System.Collections.Generic.List[string]
foreach ($item in $Path) {
	if ([string]::IsNullOrWhiteSpace($item)) {
		continue
	}
	$full = [System.IO.Path]::GetFullPath($item)
	if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
		throw "File not found for signing: $full"
	}
	$ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
	# Authenticode: .exe product binaries + .msi packages.
	# Worker .dll = COSE Sign1 (Sign-SyncWorkers). .intunewin = container around signed MSI (not Authenticode).
	if ($ext -ne ".exe" -and $ext -ne ".msi") {
		throw "Only .exe/.msi signed here (worker .dll COSE = Sign-SyncWorkers.ps1): $full"
	}
	$files.Add($full)
}

if ($files.Count -eq 0) {
	throw "No .exe/.msi files provided for Artifact Signing."
}

$spEnvSet = -not [string]::IsNullOrWhiteSpace((Get-EnvOrEmpty -Name "AZURE_CLIENT_ID"))

Write-Host "Artifact Signing via SignTool"
Write-Host "  SignTool -> $signTool"
Write-Host "  Dlib     -> $dlib"
Write-Host "  Endpoint -> $($metadata.Endpoint)"
Write-Host "  Account  -> $AccountName"
Write-Host "  Profile  -> $CertificateProfileName"
Write-Host "  AuthMode -> $AuthMode"
Write-Host ("  SP env   -> {0}" -f $(if ($spEnvSet) { "AZURE_CLIENT_ID set" } else { "not set" }))
Write-Host ("  Files    -> {0}" -f $files.Count)

try {
	foreach ($file in $files) {
		Write-Host "Signing -> $file"
		$logFile = Join-Path ([System.IO.Path]::GetTempPath()) ("signtool-{0}.log" -f [guid]::NewGuid().ToString("N"))
		try {
			& $signTool sign `
				/v `
				/debug `
				/fd SHA256 `
				/tr $TimestampUrl `
				/td SHA256 `
				/dlib $dlib `
				/dmdf $metadataFile `
				$file *>&1 |
				Tee-Object -FilePath $logFile |
				ForEach-Object { Write-Host "$_" }

			if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
				$logText = ""
				if (Test-Path -LiteralPath $logFile -PathType Leaf) {
					$logText = Get-Content -LiteralPath $logFile -Raw -ErrorAction SilentlyContinue
				}
				$hint = Format-SignToolFailureHint -LogText $logText
				$msg = "SignTool failed for $file with exit code $LASTEXITCODE"
				if (-not [string]::IsNullOrWhiteSpace($hint)) {
					$msg = "$msg`n$hint"
				}
				throw $msg
			}

			$signature = Get-AuthenticodeSignature -LiteralPath $file
			if ($signature.Status -ne "Valid") {
				throw ("Authenticode status for {0} is {1}: {2}" -f $file, $signature.Status, $signature.StatusMessage)
			}
			Write-Host ("Signed OK -> {0} ({1})" -f $file, $signature.SignerCertificate.Subject)
		}
		finally {
			Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue
		}
	}
}
finally {
	if ($tempMetadata -and (Test-Path -LiteralPath $metadataFile -PathType Leaf)) {
		Remove-Item -LiteralPath $metadataFile -Force -ErrorAction SilentlyContinue
	}
}

return $files.ToArray()
