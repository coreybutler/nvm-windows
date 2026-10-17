param(
	[ValidateSet("run", "dialog", "submit", "budget")]
	[string]$Action = "run",

	[string]$Exe = "",

	[string]$Arguments = "",

	[string]$ArgumentsFile = "",

	[string]$Arg1 = "",

	[string]$Arg2 = "",

	[string]$Arg3 = "",

	[string]$Arg4 = "",

	[string]$Arg5 = "",

	[string]$Arg6 = "",

	[int]$TimeoutSec = 180,

	[string]$Code = "",

	[string]$Message = "",

	[switch]$SoftFail,

	[switch]$RunAs,

	[string]$RollbackProductCode = "",

	[string]$RollbackCommandLog = "",

	[string]$ReportDirectory = "",

	[ValidateSet("step", "copy", "adopt", "elevated", "uninstall", "walk")]
	[string]$BudgetKind = "step",

	[int]$VersionCount = 0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-InstallerStepBudgetSeconds {
	param(
		[ValidateSet("step", "copy", "adopt", "elevated", "uninstall", "walk")]
		[string]$Kind,
		[int]$Count = 0
	)
	# Budgets are hang limits. A slow machine should finish well under them.
	if ($Kind -eq "adopt") {
		return 900
	}
	if ($Kind -eq "uninstall") {
		return 600
	}
	if ($Kind -eq "elevated") {
		return 300
	}
	if ($Kind -eq "copy") {
		if ($Count -le 0) {
			return 0
		}
		return 300
	}
	if ($Kind -eq "walk") {
		if ($Count -lt 1) {
			$Count = 1
		}
		$budget = 120 * $Count
		if ($budget -lt 600) {
			return 600
		}
		if ($budget -gt 1800) {
			return 1800
		}
		return $budget
	}
	return 180
}

function Get-InstallerReportDirectory {
	param([string]$Override = "")
	if (-not [string]::IsNullOrWhiteSpace($Override)) {
		return $Override
	}
	$programData = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
	if ([string]::IsNullOrWhiteSpace($programData)) {
		$programData = Join-Path $env:SystemDrive "ProgramData"
	}
	return Join-Path $programData "Author Software"
}

function ConvertTo-RedactedInstallerText {
	param(
		[string]$Text,
		[string]$UserName = "",
		[string]$ComputerName = "",
		[string]$DomainName = "",
		[string]$DnsDomain = ""
	)
	if ($null -eq $Text) {
		return ""
	}
	$redacted = $Text
	if ([string]::IsNullOrWhiteSpace($UserName)) {
		$UserName = [Environment]::UserName
	}
	if ([string]::IsNullOrWhiteSpace($ComputerName)) {
		$ComputerName = [Environment]::MachineName
	}
	if ([string]::IsNullOrWhiteSpace($DomainName)) {
		$DomainName = [Environment]::UserDomainName
	}
	if ([string]::IsNullOrWhiteSpace($DnsDomain)) {
		$DnsDomain = [Environment]::GetEnvironmentVariable("USERDNSDOMAIN")
		if ([string]::IsNullOrWhiteSpace($DnsDomain)) {
			try {
				$DnsDomain = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
			} catch {
				$DnsDomain = ""
			}
		}
	}

	$redacted = [regex]::Replace($redacted, '(?i)([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@', '$1<credentials>@')
	$redacted = [regex]::Replace($redacted, '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '<email>')
	$redacted = [regex]::Replace($redacted, '(?i)\\\\[^\\\s]+\\[^\\\s]+', '\\<server>\<share>')
	$redacted = [regex]::Replace($redacted, '(?i)([A-Za-z]:\\Users\\)(?!(?:Public|Default User|Default|All Users)(?=\\|$))[^\\\r\n]+', '$1<user>')
	$redacted = [regex]::Replace($redacted, '(?i)OneDrive - [^\\\r\n]+', 'OneDrive - <organization>')

	foreach ($token in @($DnsDomain, $DomainName, $ComputerName, $UserName)) {
		if ([string]::IsNullOrWhiteSpace($token) -or $token.Length -lt 2) {
			continue
		}
		$marker = '<user>'
		if ($token -eq $ComputerName) {
			$marker = '<computer>'
		} elseif (($token -eq $DomainName) -or ($token -eq $DnsDomain)) {
			$marker = '<domain>'
		}
		$escaped = [regex]::Escape($token)
		$redacted = [regex]::Replace($redacted, "(?i)(?<![A-Za-z0-9])$escaped(?![A-Za-z0-9])", $marker)
	}
	$redacted = [regex]::Replace($redacted, "S-1-5-21-\d+(?:-\d+)+", '<sid>')
	return $redacted
}

function Get-InstallerReportExcerpt {
	param(
		[string]$Text,
		[int]$MaxChars = 32768
	)
	if ($null -eq $Text) {
		return ""
	}
	if ($Text.Length -le $MaxChars) {
		return $Text
	}
	return $Text.Substring($Text.Length - $MaxChars)
}

function Write-InstallerFailureRecord {
	param(
		[Parameter(Mandatory = $true)]
		[string]$FailureCode,
		[Parameter(Mandatory = $true)]
		[string]$FailureMessage,
		[string]$Directory = ""
	)
	$dir = Get-InstallerReportDirectory $Directory
	New-Item -ItemType Directory -Force -Path $dir | Out-Null
	$logPath = Join-Path $dir "nvm-setup.log"
	$oneLine = ($FailureMessage -replace "[\r\n]+", " ").Trim()
	$stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
	$line = "$stamp $FailureCode $oneLine"
	[System.IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
	$recordPath = Join-Path $dir "nvm-setup-failure.txt"
	$body = $FailureCode + "`n" + $oneLine + "`n" + $logPath + "`n"
	[System.IO.File]::WriteAllText($recordPath, $body, [System.Text.UTF8Encoding]::new($false))
	if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path -LiteralPath $PSCommandPath)) {
		Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $dir "InstallerReport.ps1") -Force
	}
	return $logPath
}

function Invoke-InstallerProductRollback {
	param(
		[string]$ProductCode,
		[string]$CommandLog = ""
	)
	if ([string]::IsNullOrWhiteSpace($ProductCode)) {
		return
	}
	$rendered = "msiexec.exe /x $ProductCode /qn /norestart"
	if (-not [string]::IsNullOrWhiteSpace($CommandLog)) {
		[System.IO.File]::WriteAllText($CommandLog, $rendered)
		return
	}
	$delayed = "ping -n 8 127.0.0.1 >nul & $rendered"
	Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList @("/c", $delayed) -WindowStyle Hidden | Out-Null
}

function Invoke-InstallerTimedProcess {
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath,
		[string]$ArgumentText = "",
		[int]$Seconds = 60,
		[string]$FailureCode = "",
		[string]$FailureMessage = "",
		[switch]$AllowNonZero,
		[switch]$Elevate,
		[string]$ProductCode = "",
		[string]$ProductRollbackLog = "",
		[string]$Directory = ""
	)
	if ($Seconds -lt 1) {
		$msg = $FailureMessage
		if ([string]::IsNullOrWhiteSpace($msg)) {
			$msg = "The setup step exceeded its time limit."
		}
		Write-InstallerFailureRecord -FailureCode $FailureCode -FailureMessage $msg -Directory $Directory | Out-Null
		Invoke-InstallerProductRollback -ProductCode $ProductCode -CommandLog $ProductRollbackLog
		return 1460
	}

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $FilePath
	$psi.Arguments = $ArgumentText
	if ($Elevate) {
		$psi.UseShellExecute = $true
		$psi.Verb = "RunAs"
		$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
	} else {
		$psi.UseShellExecute = $false
		$psi.CreateNoWindow = $true
	}
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = $psi
	try {
		[void]$process.Start()
	} catch {
		if ($Elevate) {
			return 1223
		}
		throw
	}
	if (-not $process.WaitForExit($Seconds * 1000)) {
		try {
			$process.Kill()
		} catch {
		}
		try {
			[void]$process.WaitForExit(5000)
		} catch {
		}
		$msg = $FailureMessage
		if ([string]::IsNullOrWhiteSpace($msg)) {
			$msg = "The setup step exceeded its time limit."
		}
		Write-InstallerFailureRecord -FailureCode $FailureCode -FailureMessage $msg -Directory $Directory | Out-Null
		Invoke-InstallerProductRollback -ProductCode $ProductCode -CommandLog $ProductRollbackLog
		return 1460
	}
	$code = $process.ExitCode
	if ((-not $AllowNonZero) -and $code -ne 0 -and $code -ge 8) {
		$msg = $FailureMessage
		if ([string]::IsNullOrWhiteSpace($msg)) {
			$msg = "The setup step failed with exit code $code."
		}
		Write-InstallerFailureRecord -FailureCode $FailureCode -FailureMessage $msg -Directory $Directory | Out-Null
		Invoke-InstallerProductRollback -ProductCode $ProductCode -CommandLog $ProductRollbackLog
	}
	return $code
}

function Read-InstallerFailureRecord {
	param([string]$Directory = "")
	$candidates = @()
	if (-not [string]::IsNullOrWhiteSpace($Directory)) {
		$candidates += (Join-Path $Directory "nvm-setup-failure.txt")
	}
	$candidates += (Join-Path (Get-InstallerReportDirectory "") "nvm-setup-failure.txt")
	$local = Join-Path $env:LOCALAPPDATA "Author Software\nvm-setup-failure.txt"
	$candidates += $local
	foreach ($path in $candidates) {
		if (Test-Path -LiteralPath $path) {
			$lines = [System.IO.File]::ReadAllLines($path)
			$code = if ($lines.Length -gt 0) { $lines[0] } else { "" }
			$msg = if ($lines.Length -gt 1) { $lines[1] } else { "" }
			$log = if ($lines.Length -gt 2) { $lines[2] } else { "" }
			return [pscustomobject]@{ Code = $code; Message = $msg; Log = $log }
		}
	}
	return $null
}

function Get-InstallerIssueReport {
	param(
		[string]$FailureCode,
		[string]$FailureMessage,
		[string]$LogPath
	)
	$logText = ""
	if (-not [string]::IsNullOrWhiteSpace($LogPath) -and (Test-Path -LiteralPath $LogPath)) {
		$logText = [System.IO.File]::ReadAllText($LogPath)
	}
	$redacted = ConvertTo-RedactedInstallerText -Text $logText
	$excerpt = Get-InstallerReportExcerpt -Text $redacted
	$summary = @"
Install code: $FailureCode

$FailureMessage

autosubmission

The redacted log is on the clipboard. Paste it below this line.

"@
	return [pscustomobject]@{
		Summary = $summary.TrimEnd()
		Excerpt = $excerpt
		Clipboard = ($summary + "`r`n" + $excerpt).TrimEnd()
	}
}

function Open-InstallerIssue {
	param([string]$Directory = "")
	$record = Read-InstallerFailureRecord -Directory $Directory
	if ($null -eq $record) {
		throw "No installer failure record was found."
	}
	$report = Get-InstallerIssueReport -FailureCode $record.Code -FailureMessage $record.Message -LogPath $record.Log
	Set-Clipboard -Value $report.Clipboard
	$existing = ""
	try {
		$query = [uri]::EscapeDataString("repo:nvm-windows/nvm is:issue is:open `"$($record.Code)`" in:body")
		$search = Invoke-RestMethod -Uri "https://api.github.com/search/issues?q=$query&per_page=1" -Headers @{ "User-Agent" = "nvm-windows-setup" }
		if ($search.total_count -gt 0 -and $search.items) {
			$existing = [string]$search.items[0].html_url
		}
	} catch {
		$existing = ""
	}
	if (-not [string]::IsNullOrWhiteSpace($existing)) {
		Start-Process $existing | Out-Null
		return $existing
	}
	$title = [uri]::EscapeDataString("$($record.Code) installer failure")
	$body = [uri]::EscapeDataString($report.Summary)
	$labels = [uri]::EscapeDataString("autosubmission,$($record.Code)")
	$url = "https://github.com/nvm-windows/nvm/issues/new?title=$title&body=$body&labels=$labels"
	Start-Process $url | Out-Null
	return $url
}

function Show-InstallerFailureDialog {
	param([string]$Directory = "")
	$script:InstallerDialogDirectory = $Directory
	$record = Read-InstallerFailureRecord -Directory $Directory
	if ($null -eq $record) {
		return
	}
	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "NVM for Windows Setup"
	$form.Width = 560
	$form.Height = 240
	$form.StartPosition = "CenterScreen"
	$form.FormBorderStyle = "FixedDialog"
	$form.MaximizeBox = $false
	$form.MinimizeBox = $false
	$label = New-Object System.Windows.Forms.Label
	$label.Left = 16
	$label.Top = 16
	$label.Width = 510
	$label.Height = 72
	$label.Text = "$($record.Code)`r`n$($record.Message)`r`n`r`nLog:"
	$path = New-Object System.Windows.Forms.TextBox
	$path.Left = 16
	$path.Top = 96
	$path.Width = 510
	$path.ReadOnly = $true
	$path.Text = $record.Log
	$close = New-Object System.Windows.Forms.Button
	$close.Text = "Close"
	$close.Left = 340
	$close.Top = 150
	$close.Width = 80
	$close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$submit = New-Object System.Windows.Forms.Button
	$submit.Text = "Submit Issue"
	$submit.Left = 430
	$submit.Top = 150
	$submit.Width = 100
	$submit.Add_Click({
		try {
			Open-InstallerIssue -Directory $script:InstallerDialogDirectory | Out-Null
		} catch {
			[System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "NVM for Windows Setup")
		}
		$form.Close()
	})
	$form.Controls.AddRange(@($label, $path, $close, $submit))
	$form.AcceptButton = $close
	$form.CancelButton = $close
	[void]$form.ShowDialog()
}

if ($MyInvocation.InvocationName -eq ".") {
	return
}

switch ($Action) {
	"budget" {
		Write-Output (Get-InstallerStepBudgetSeconds -Kind $BudgetKind -Count $VersionCount)
		exit 0
	}
	"dialog" {
		Show-InstallerFailureDialog -Directory $ReportDirectory
		exit 0
	}
	"submit" {
		Open-InstallerIssue -Directory $ReportDirectory | Out-Null
		exit 0
	}
	default {
		$argumentText = $Arguments
		if (-not [string]::IsNullOrWhiteSpace($ArgumentsFile)) {
			$argumentText = [System.IO.File]::ReadAllText($ArgumentsFile)
		}
		if ([string]::IsNullOrWhiteSpace($argumentText)) {
			$parts = @($Arg1, $Arg2, $Arg3, $Arg4, $Arg5, $Arg6) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
			$argumentText = ($parts | ForEach-Object {
				if (($_ -match '\s') -and ($_ -notmatch '"')) { '"{0}"' -f $_ } else { $_ }
			}) -join ' '
		}
		$exitCode = Invoke-InstallerTimedProcess -FilePath $Exe -ArgumentText $argumentText -Seconds $TimeoutSec -FailureCode $Code -FailureMessage $Message -AllowNonZero:$SoftFail -Elevate:$RunAs -ProductCode $RollbackProductCode -ProductRollbackLog $RollbackCommandLog -Directory $ReportDirectory
		exit $exitCode
	}
}
