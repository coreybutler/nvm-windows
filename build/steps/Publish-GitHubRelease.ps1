# Gate or publish a GitHub Release for the community Inno Setup build.
# Version comes from cli/src/manifest.json.
# Uploads per architecture:
#   nvm-<version>-<arch>-setup.exe
#   nvm-<version>-<arch>-sync.exe   (prebuilt sync for public -DownloadSync builds)
#
# Modes:
#   Gate    — fail fast before long build if tag burned / already complete
#   Publish — draft → upload assets → publish
#
# Requires: gh CLI, GH_TOKEN with contents:write (workflow github.token).

param(
	[Parameter(Mandatory = $true)]
	[ValidateSet("Gate", "Publish")]
	[string]$Mode,

	[Parameter(Mandatory = $true)]
	[ValidateSet("amd64", "arm64")]
	[string[]]$Architectures,

	[switch]$OverrideExisting,

	[bool]$Enabled = $true,

	[string]$Version = "",

	[string]$AssetRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "..\common.ps1")

function ConvertTo-StringArray {
	param(
		[AllowNull()]
		$Items
	)
	if ($null -eq $Items) {
		return , [string[]]@()
	}
	if ($Items -is [string]) {
		return , [string[]]@($Items)
	}
	if ($Items -is [System.Collections.Generic.List[string]]) {
		return , [string[]]$Items.ToArray()
	}
	if ($Items -is [System.Array]) {
		return , [string[]]@($Items | ForEach-Object { [string]$_ })
	}
	return , [string[]]@($Items | ForEach-Object { [string]$_ })
}

$architectures = @(
	$Architectures |
		ForEach-Object { $_.Trim().ToLowerInvariant() } |
		Where-Object { $_ -in @("amd64", "arm64") } |
		Select-Object -Unique
)
if ($architectures.Count -eq 0) {
	throw "Architectures must include amd64 and/or arm64"
}

$version = $Version.Trim()
if ([string]::IsNullOrWhiteSpace($version)) {
	$ctx = Initialize-NvmBuildContext
	$version = [string]$ctx.CliVersion
}

function Get-NvmReleaseTag {
	param([string]$Version)
	$v = $Version.Trim()
	if ([string]::IsNullOrWhiteSpace($v)) {
		throw "CLI version is empty"
	}
	if ($v.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) {
		return $v
	}
	return "v$v"
}

function Clear-NativeExitCode {
	$global:LASTEXITCODE = 0
}

function Invoke-GhCapture {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$GhArgs
	)
	$prevEap = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$lines = @(& gh @GhArgs 2>&1)
		$code = $LASTEXITCODE
	}
	finally {
		$ErrorActionPreference = $prevEap
		Clear-NativeExitCode
	}
	return [pscustomobject]@{
		ExitCode = $code
		Text     = (($lines | ForEach-Object { "$_" }) -join "`n").Trim()
	}
}

function Test-ReleaseExists {
	param([string]$Tag)

	$view = Invoke-GhCapture -GhArgs @("release", "view", $Tag, "--json", "databaseId")
	if ($view.ExitCode -eq 0) {
		return $true
	}

	$api = Invoke-GhCapture -GhArgs @("api", "repos/{owner}/{repo}/releases/tags/$Tag", "--silent")
	return ($api.ExitCode -eq 0)
}

function Get-ReleaseView {
	param(
		[string]$Tag,
		[string]$JsonFields = "databaseId,url,isDraft,tagName"
	)
	$result = Invoke-GhCapture -GhArgs @("release", "view", $Tag, "--json", $JsonFields)
	if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text) -or ($result.Text -notmatch '^\s*\{')) {
		return $null
	}
	return ($result.Text | ConvertFrom-Json)
}

function Test-ReleaseIsDraft {
	param([string]$Tag)
	$view = Get-ReleaseView -Tag $Tag -JsonFields "isDraft"
	if ($null -eq $view) {
		return $false
	}
	return [bool]$view.isDraft
}

function Get-ReleaseAssetNames {
	param([string]$Tag)
	$names = New-Object System.Collections.Generic.List[string]
	$view = Get-ReleaseView -Tag $Tag -JsonFields "assets"
	if ($null -eq $view -or $null -eq $view.assets) {
		return ConvertTo-StringArray $names
	}
	foreach ($a in @($view.assets)) {
		$n = [string]$a.name
		if (-not [string]::IsNullOrWhiteSpace($n)) {
			$names.Add($n)
		}
	}
	return ConvertTo-StringArray $names
}

function Test-ReleaseAssetNameMatchesArchitecture {
	param(
		[string]$Name,
		[string]$Architecture,
		[ValidateSet("setup", "sync", "any")]
		[string]$Kind = "any"
	)
	$arch = [regex]::Escape($Architecture)
	switch ($Kind) {
		"setup" { return ($Name -match ("-{0}-setup\.exe$" -f $arch)) }
		"sync" { return ($Name -match ("-{0}-sync\.exe$" -f $arch)) }
		default { return ($Name -match ("-{0}-(setup|sync)\.exe$" -f $arch)) }
	}
}

function Get-ReleaseAssetsForArchitecture {
	param(
		[string]$Tag,
		[string]$Architecture,
		[ValidateSet("setup", "sync", "any")]
		[string]$Kind = "any"
	)
	$matched = New-Object System.Collections.Generic.List[string]
	foreach ($name in (Get-ReleaseAssetNames -Tag $Tag)) {
		if (Test-ReleaseAssetNameMatchesArchitecture -Name $name -Architecture $Architecture -Kind $Kind) {
			$matched.Add($name)
		}
	}
	return ConvertTo-StringArray $matched
}

function Write-ReleaseEnv {
	param(
		[string]$Version,
		[string]$Tag
	)
	if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
		Add-Content -LiteralPath $env:GITHUB_ENV -Value "CLI_VERSION=$Version"
		Add-Content -LiteralPath $env:GITHUB_ENV -Value "RELEASE_TAG=$Tag"
	}
	if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
		Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "version=$Version"
		Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "tag=$Tag"
	}
	Write-Host "CLI version -> $Version"
	Write-Host "Release tag -> $Tag"
	Write-Host ("Architectures -> {0}" -f ($architectures -join ", "))
}

function Get-ImmutableTagBurnHint {
	param([string]$Tag)
	return @"
Tag $Tag may be permanently reserved if it was ever published while immutable releases were enabled.
Deleting the release does NOT free the tag name in that case.

Bump ``cli/src/manifest.json`` version and re-run.
Preferred flow: create --draft → upload assets → edit --draft=false
"@
}

function Get-NvmReleaseNotesFooter {
	return @"

- https://nvm-windows.com
- https://docs.nvm-windows.com

> [!IMPORTANT]
> **`sync.exe` is only necessary when [building from source](https://docs.nvm-windows.com/install/source).**
"@
}

function Get-NvmGitHubRepository {
	if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
		return $env:GITHUB_REPOSITORY.Trim()
	}
	$remote = Invoke-GhCapture -GhArgs @("repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner")
	if ($remote.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote.Text)) {
		return $remote.Text.Trim()
	}
	return "nvm-windows/nvm"
}

function Get-NvmReleaseHeadRef {
	if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA)) {
		return $env:GITHUB_SHA.Trim()
	}
	$git = Get-Command git -ErrorAction SilentlyContinue
	if ($null -ne $git) {
		$head = (& git rev-parse HEAD 2>$null)
		if (-not [string]::IsNullOrWhiteSpace($head)) {
			return $head.Trim()
		}
	}
	return $null
}

function Get-NvmPreviousPublishedReleaseTag {
	param([string]$CurrentTag)

	$list = Invoke-GhCapture -GhArgs @("release", "list", "--limit", "100", "--json", "tagName,isDraft,publishedAt")
	if ($list.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($list.Text)) {
		return $null
	}
	$releases = @($list.Text | ConvertFrom-Json) |
		Where-Object { -not $_.isDraft -and -not [string]::IsNullOrWhiteSpace([string]$_.tagName) } |
		Sort-Object { [datetime]$_.publishedAt } -Descending

	foreach ($release in $releases) {
		$tagName = [string]$release.tagName
		if ($tagName -eq $CurrentTag) {
			continue
		}
		return $tagName
	}
	return $null
}

function Get-NvmGitHubCommitRefSha {
	param(
		[string]$Repository,
		[string]$Ref
	)
	if ([string]::IsNullOrWhiteSpace($Repository) -or [string]::IsNullOrWhiteSpace($Ref)) {
		return $null
	}
	$encoded = [uri]::EscapeDataString($Ref)
	$result = Invoke-GhCapture -GhArgs @("api", "repos/$Repository/commits/$encoded", "-q", ".sha")
	if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text)) {
		return $null
	}
	return $result.Text.Trim()
}

function Get-NvmSubmoduleCommitAtRef {
	param(
		[string]$Repository,
		[string]$Ref,
		[string]$SubmodulePath
	)
	$commitSha = Get-NvmGitHubCommitRefSha -Repository $Repository -Ref $Ref
	if ([string]::IsNullOrWhiteSpace($commitSha)) {
		return $null
	}
	$treeSha = (Invoke-GhCapture -GhArgs @("api", "repos/$Repository/commits/$commitSha", "-q", ".commit.tree.sha")).Text.Trim()
	if ([string]::IsNullOrWhiteSpace($treeSha)) {
		return $null
	}
	$treeJson = Invoke-GhCapture -GhArgs @("api", "repos/$Repository/git/trees/$treeSha")
	if ($treeJson.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($treeJson.Text)) {
		return $null
	}
	$tree = $treeJson.Text | ConvertFrom-Json
	foreach ($entry in @($tree.tree)) {
		if ([string]$entry.path -eq $SubmodulePath -and [string]$entry.type -eq "commit") {
			return [string]$entry.sha
		}
	}
	return $null
}

function Format-NvmReleaseCommitLine {
	param(
		[string]$Repository,
		$Commit
	)
	$sha = [string]$Commit.sha
	if ([string]::IsNullOrWhiteSpace($sha)) {
		return $null
	}
	$short = if ($sha.Length -gt 7) { $sha.Substring(0, 7) } else { $sha }
	$message = [string]$Commit.commit.message
	$subject = ($message -split "`r?`n", 2)[0].Trim()
	if ([string]::IsNullOrWhiteSpace($subject)) {
		$subject = "commit"
	}
	$author = [string]$Commit.commit.author.name
	if ([string]::IsNullOrWhiteSpace($author)) {
		$author = [string]$Commit.author.login
	}
	if ([string]::IsNullOrWhiteSpace($author)) {
		$author = "unknown"
	}
	$url = [string]$Commit.html_url
	if ([string]::IsNullOrWhiteSpace($url)) {
		$url = "https://github.com/$Repository/commit/$sha"
	}
	return "* [``$short``]($url) $subject ($author)"
}

function Get-NvmCompareCommitLines {
	param(
		[string]$Repository,
		[string]$BaseRef,
		[string]$HeadRef
	)
	if ([string]::IsNullOrWhiteSpace($Repository) -or [string]::IsNullOrWhiteSpace($BaseRef) -or [string]::IsNullOrWhiteSpace($HeadRef)) {
		return , [string[]]@()
	}
	if ($BaseRef -eq $HeadRef) {
		return , [string[]]@()
	}
	$range = "$BaseRef...$HeadRef"
	$result = Invoke-GhCapture -GhArgs @("api", "repos/$Repository/compare/$range")
	if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text)) {
		Write-Host ("Release notes: unable to compare {0} ({1})" -f $Repository, $result.Text)
		return , [string[]]@()
	}
	$compare = $result.Text | ConvertFrom-Json
	$lines = New-Object System.Collections.Generic.List[string]
	foreach ($commit in @($compare.commits)) {
		$line = Format-NvmReleaseCommitLine -Repository $Repository -Commit $commit
		if (-not [string]::IsNullOrWhiteSpace($line)) {
			$lines.Add($line)
		}
	}
	return ConvertTo-StringArray $lines
}

function Get-NvmReleaseCompareRepoSections {
	param(
		[string]$Tag,
		[string]$HeadRef
	)
	$mainRepo = Get-NvmGitHubRepository
	$owner = ($mainRepo -split "/", 2)[0]
	if ([string]::IsNullOrWhiteSpace($owner)) {
		$owner = "nvm-windows"
	}
	$previousTag = Get-NvmPreviousPublishedReleaseTag -CurrentTag $Tag
	$previousHead = if ([string]::IsNullOrWhiteSpace($previousTag)) { $null } else { Get-NvmGitHubCommitRefSha -Repository $mainRepo -Ref $previousTag }
	$currentHead = if (-not [string]::IsNullOrWhiteSpace($HeadRef)) {
		$HeadRef
	}
	else {
		Get-NvmGitHubCommitRefSha -Repository $mainRepo -Ref $Tag
	}

	$repoSections = New-Object System.Collections.Generic.List[object]
	if (-not [string]::IsNullOrWhiteSpace($previousHead) -and -not [string]::IsNullOrWhiteSpace($currentHead)) {
		$repoSections.Add([pscustomobject]@{
			Label      = $mainRepo
			Repository = $mainRepo
			Base       = $previousHead
			Head       = $currentHead
		})
	}
	foreach ($sub in @("cli", "common", "shim", "sync")) {
		$subRepo = "$owner/$sub"
		$prevSub = if ($previousHead) { Get-NvmSubmoduleCommitAtRef -Repository $mainRepo -Ref $previousHead -SubmodulePath $sub } else { $null }
		$headSub = if ($currentHead) { Get-NvmSubmoduleCommitAtRef -Repository $mainRepo -Ref $currentHead -SubmodulePath $sub } else { $null }
		if ([string]::IsNullOrWhiteSpace($headSub) -or [string]::IsNullOrWhiteSpace($prevSub)) {
			continue
		}
		$repoSections.Add([pscustomobject]@{
			Label      = $subRepo
			Repository = $subRepo
			Base       = $prevSub
			Head       = $headSub
		})
	}

	return [pscustomobject]@{
		PreviousTag = $previousTag
		Sections    = @($repoSections.ToArray())
	}
}

function Get-NvmCompareCommits {
	param(
		[string]$Repository,
		[string]$BaseRef,
		[string]$HeadRef
	)
	if ([string]::IsNullOrWhiteSpace($Repository) -or [string]::IsNullOrWhiteSpace($BaseRef) -or [string]::IsNullOrWhiteSpace($HeadRef)) {
		return @()
	}
	if ($BaseRef -eq $HeadRef) {
		return @()
	}
	$range = "$BaseRef...$HeadRef"
	$result = Invoke-GhCapture -GhArgs @("api", "repos/$Repository/compare/$range")
	if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text)) {
		Write-Host ("Release notes: unable to compare {0} ({1})" -f $Repository, $result.Text)
		return @()
	}
	$compare = $result.Text | ConvertFrom-Json
	return @($compare.commits)
}

function Test-NvmAuthorHasPriorCommits {
	param(
		[string]$Repository,
		[string]$Login,
		[string]$BeforeSha
	)
	if ([string]::IsNullOrWhiteSpace($Repository) -or [string]::IsNullOrWhiteSpace($Login) -or [string]::IsNullOrWhiteSpace($BeforeSha)) {
		return $true
	}
	$encodedLogin = [uri]::EscapeDataString($Login)
	$path = "repos/$Repository/commits?author=$encodedLogin&sha=$BeforeSha&per_page=1"
	$result = Invoke-GhCapture -GhArgs @("api", $path)
	if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text)) {
		return $true
	}
	$commits = @($result.Text | ConvertFrom-Json)
	return ($commits.Count -gt 0)
}

function Get-NvmReleaseCommitSummarySection {
	param(
		[string]$Tag,
		[string]$HeadRef
	)
	$compare = Get-NvmReleaseCompareRepoSections -Tag $Tag -HeadRef $HeadRef
	$previousTag = [string]$compare.PreviousTag
	$sections = New-Object System.Collections.Generic.List[string]

	foreach ($section in @($compare.Sections)) {
		if ($null -eq $section -or [string]::IsNullOrWhiteSpace([string]$section.Head) -or [string]::IsNullOrWhiteSpace([string]$section.Base)) {
			continue
		}
		$lines = Get-NvmCompareCommitLines -Repository $section.Repository -BaseRef $section.Base -HeadRef $section.Head
		if ($lines.Count -eq 0) {
			continue
		}
		$sections.Add("### $($section.Label)")
		foreach ($line in $lines) {
			$sections.Add($line)
		}
		$sections.Add("")
	}

	if ($sections.Count -eq 0) {
		if ([string]::IsNullOrWhiteSpace($previousTag)) {
			return "## Commits`n`n_No previous published release to compare._"
		}
		return "## Commits`n`n_No commits since $previousTag._"
	}
	while ($sections.Count -gt 0 -and [string]::IsNullOrWhiteSpace($sections[$sections.Count - 1])) {
		$sections.RemoveAt($sections.Count - 1)
	}
	return ("## Commits`n`n" + ($sections -join "`n"))
}

function Get-NvmReleaseContributorLogins {
	param(
		[string]$Tag,
		[string]$HeadRef
	)
	$compare = Get-NvmReleaseCompareRepoSections -Tag $Tag -HeadRef $HeadRef
	$logins = New-Object System.Collections.Generic.List[string]
	$seen = @{}
	foreach ($section in @($compare.Sections)) {
		if ($null -eq $section -or [string]::IsNullOrWhiteSpace([string]$section.Head) -or [string]::IsNullOrWhiteSpace([string]$section.Base)) {
			continue
		}
		$commits = Get-NvmCompareCommits -Repository $section.Repository -BaseRef $section.Base -HeadRef $section.Head
		foreach ($commit in $commits) {
			$login = [string]$commit.author.login
			if ([string]::IsNullOrWhiteSpace($login)) {
				continue
			}
			if ($login -match '\[bot\]$' -or $login -eq "dependabot" -or $login -eq "renovate") {
				continue
			}
			$key = $login.ToLowerInvariant()
			if ($seen.ContainsKey($key)) {
				continue
			}
			$seen[$key] = $true
			$logins.Add($login)
		}
	}
	return , [string[]]@($logins.ToArray())
}

function Get-NvmReleaseNewContributorsSection {
	param(
		[string]$Tag,
		[string]$HeadRef
	)
	$compare = Get-NvmReleaseCompareRepoSections -Tag $Tag -HeadRef $HeadRef
	if ([string]::IsNullOrWhiteSpace([string]$compare.PreviousTag)) {
		return ""
	}

	# login -> first contribution url in this release window
	$newByLogin = [ordered]@{}
	foreach ($section in @($compare.Sections)) {
		if ($null -eq $section -or [string]::IsNullOrWhiteSpace([string]$section.Head) -or [string]::IsNullOrWhiteSpace([string]$section.Base)) {
			continue
		}
		$commits = Get-NvmCompareCommits -Repository $section.Repository -BaseRef $section.Base -HeadRef $section.Head
		foreach ($commit in $commits) {
			$login = [string]$commit.author.login
			if ([string]::IsNullOrWhiteSpace($login)) {
				continue
			}
			if ($login -match '\[bot\]$' -or $login -eq "dependabot" -or $login -eq "renovate") {
				continue
			}
			if ($newByLogin.Contains($login)) {
				continue
			}
			if (Test-NvmAuthorHasPriorCommits -Repository $section.Repository -Login $login -BeforeSha $section.Base) {
				continue
			}
			$url = [string]$commit.html_url
			if ([string]::IsNullOrWhiteSpace($url)) {
				$sha = [string]$commit.sha
				$url = "https://github.com/$($section.Repository)/commit/$sha"
			}
			$newByLogin[$login] = $url
		}
	}

	if ($newByLogin.Count -eq 0) {
		return ""
	}

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("## New Contributors")
	$lines.Add("")
	foreach ($login in $newByLogin.Keys) {
		$lines.Add("* @$login made their first contribution in $($newByLogin[$login])")
	}
	return ($lines -join "`n")
}

function Get-NvmReleaseContributorsIconsSection {
	param(
		[string]$Tag,
		[string]$HeadRef
	)
	$logins = @(Get-NvmReleaseContributorLogins -Tag $Tag -HeadRef $HeadRef)
	if ($logins.Count -eq 0) {
		return ""
	}

	# Avatar row similar to common OSS release notes (GitHub serves /{user}.png).
	$icons = New-Object System.Collections.Generic.List[string]
	foreach ($login in $logins) {
		$href = "https://github.com/$login"
		$src = "https://github.com/$login.png?size=64"
		$icons.Add("<a href=`"$href`"><img src=`"$src`" width=`"48`" height=`"48`" alt=`"@$login`" title=`"@$login`"/></a>")
	}
	return ("## Contributors`n`n" + ($icons -join " "))
}

function Build-NvmReleaseNotesBody {
	param(
		[string]$Tag,
		[string]$Version
	)
	$noteArches = ($architectures -join ", ")
	$headRef = Get-NvmReleaseHeadRef
	$intro = @"
# NVM for Windows $Tag

Unsigned community build from ``cli/src/manifest.json`` version ``$Version``.
Architectures: $noteArches.

Assets per arch: Inno Setup installer (``*-setup.exe``) and prebuilt ``sync.exe`` (``*-sync.exe``) for public ``-DownloadSync`` builds.
"@
	if ($Version -match '(?i)-hotfix\.\d+') {
		$intro += "`n`nHotfix stamp applied at build time via the Community Release ``hotfix`` workflow input (manifest base left unchanged in git)."
	}
	$commits = Get-NvmReleaseCommitSummarySection -Tag $Tag -HeadRef $headRef
	$newContributors = Get-NvmReleaseNewContributorsSection -Tag $Tag -HeadRef $headRef
	$contributorIcons = Get-NvmReleaseContributorsIconsSection -Tag $Tag -HeadRef $headRef
	$footer = Get-NvmReleaseNotesFooter
	$body = $intro.TrimEnd() + "`n`n" + $commits.TrimEnd()
	if (-not [string]::IsNullOrWhiteSpace($newContributors)) {
		$body += "`n`n" + $newContributors.TrimEnd()
	}
	if (-not [string]::IsNullOrWhiteSpace($contributorIcons)) {
		$body += "`n`n" + $contributorIcons.TrimEnd()
	}
	return ($body + $footer)
}

function Set-NvmReleaseNotes {
	param(
		[string]$Tag,
		[string]$Version
	)
	$notes = Build-NvmReleaseNotesBody -Tag $Tag -Version $Version
	$notesFile = Join-Path ([System.IO.Path]::GetTempPath()) ("nvm-release-notes-{0}.md" -f ([guid]::NewGuid().ToString("n")))
	try {
		[System.IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding $false))
		$edit = Invoke-GhCapture -GhArgs @("release", "edit", $Tag, "--notes-file", $notesFile)
		if ($edit.ExitCode -ne 0) {
			throw ("gh release edit {0} --notes-file failed with exit code {1}: {2}" -f $Tag, $edit.ExitCode, $edit.Text)
		}
	}
	finally {
		if (Test-Path -LiteralPath $notesFile) {
			Remove-Item -LiteralPath $notesFile -Force -ErrorAction SilentlyContinue
		}
	}
}

function New-NvmDraftRelease {
	param(
		[string]$Tag,
		[string]$Version
	)

	$notesFile = Join-Path ([System.IO.Path]::GetTempPath()) ("nvm-release-notes-{0}.md" -f ([guid]::NewGuid().ToString("n")))
	try {
		$notesBody = Build-NvmReleaseNotesBody -Tag $Tag -Version $Version
		[System.IO.File]::WriteAllText($notesFile, $notesBody, (New-Object System.Text.UTF8Encoding $false))
		$createArgs = @(
			"release", "create", $Tag,
			"--draft",
			"--title", $Tag,
			"--notes-file", $notesFile
		)
		# hotfix stamps are intentional GitHub prereleases (validation drops, not "latest").
		if ($Version -match '(?i)(alpha|beta|rc|preview|pre|hotfix)') {
			$createArgs += "--prerelease"
		}

		Write-Host ("Creating draft release {0}..." -f $Tag)
		$created = Invoke-GhCapture -GhArgs $createArgs
		if ($created.ExitCode -eq 0) {
			if (-not [string]::IsNullOrWhiteSpace($created.Text)) {
				Write-Host $created.Text
			}
			return
		}

		if (Test-ReleaseExists -Tag $Tag) {
			Write-Host ("Release {0} already exists after create exit {1}; continuing." -f $Tag, $created.ExitCode)
			return
		}

		if ($created.Text -match '(?i)Resource not accessible by integration|HTTP 403') {
			throw ("{0}`n`nGH_TOKEN cannot create releases (403). Use github.token with contents:write." -f $created.Text)
		}

		if ($created.Text -match '(?i)immutable|tag_name was used') {
			throw ("{0}`n`n{1}" -f $created.Text, (Get-ImmutableTagBurnHint -Tag $Tag))
		}

		if ($created.Text -match '(?i)creations being restricted|Repository rule') {
			throw ("{0}`n`nRuleset blocked tag/ref creation. Allow github-actions to create tags, or bypass for this repo." -f $created.Text)
		}

		throw ("gh release create --draft {0} failed with exit code {1}: {2}" -f $Tag, $created.ExitCode, $created.Text)
	}
	finally {
		if (Test-Path -LiteralPath $notesFile) {
			Remove-Item -LiteralPath $notesFile -Force -ErrorAction SilentlyContinue
		}
	}
}

function Get-ReleaseUploadState {
	param([string]$Tag)

	$view = Get-ReleaseView -Tag $Tag -JsonFields "isDraft,url,databaseId"
	if ($null -eq $view) {
		throw ("Release {0} not visible to GH_TOKEN. Check contents:write on github.token." -f $Tag)
	}
	return [pscustomobject]@{
		IsDraft    = [bool]$view.isDraft
		Url        = [string]$view.url
		DatabaseId = [string]$view.databaseId
	}
}

function Publish-NvmDraftRelease {
	param([string]$Tag)

	Write-Host ("Publishing draft release {0}..." -f $Tag)
	$pub = Invoke-GhCapture -GhArgs @("release", "edit", $Tag, "--draft=false")
	if ($pub.ExitCode -ne 0) {
		throw ("gh release edit {0} --draft=false failed with exit code {1}: {2}" -f $Tag, $pub.ExitCode, $pub.Text)
	}
}

function Remove-ReleaseAssetsForArchitecture {
	param(
		[string]$Tag,
		[string]$Architecture
	)
	$names = Get-ReleaseAssetsForArchitecture -Tag $Tag -Architecture $Architecture -Kind "any"
	if ($names.Count -eq 0) {
		Write-Host ("No existing {0} setup/sync assets on {1} to remove." -f $Architecture, $Tag)
		return
	}
	foreach ($name in $names) {
		Write-Host ("Removing release asset {0}..." -f $name)
		$del = Invoke-GhCapture -GhArgs @("release", "delete-asset", $Tag, $name, "--yes")
		if ($del.ExitCode -ne 0) {
			throw "gh release delete-asset $Tag $name failed with exit code $($del.ExitCode): $($del.Text)"
		}
	}
}

function Get-NvmReleaseUploadPaths {
	param(
		[string]$Architecture,
		[string]$SearchRoot,
		[ValidateSet("setup", "sync")]
		[string]$Kind
	)

	$paths = New-Object System.Collections.Generic.List[string]
	if (-not (Test-Path -LiteralPath $SearchRoot -PathType Container)) {
		return ConvertTo-StringArray $paths
	}

	Get-ChildItem -LiteralPath $SearchRoot -File -Recurse -ErrorAction SilentlyContinue |
		Where-Object {
			$_.Extension -ieq ".exe" -and
			(Test-ReleaseAssetNameMatchesArchitecture -Name $_.Name -Architecture $Architecture -Kind $Kind)
		} |
		ForEach-Object { $paths.Add($_.FullName) }

	$byName = @{}
	foreach ($p in $paths) {
		$name = [System.IO.Path]::GetFileName($p)
		if (-not $byName.ContainsKey($name)) {
			$byName[$name] = $p
		}
		else {
			Write-Host ("Release upload: skip duplicate name {0} ({1})" -f $name, $p)
		}
	}
	$unique = New-Object System.Collections.Generic.List[string]
	foreach ($name in ($byName.Keys | Sort-Object)) {
		$unique.Add([string]$byName[$name])
	}
	return ConvertTo-StringArray $unique
}

$tag = Get-NvmReleaseTag -Version $version
Write-ReleaseEnv -Version $version -Tag $tag

if (-not $Enabled) {
	Write-Host "GitHub Release publish disabled (publish_release unchecked)." -ForegroundColor Yellow
	Clear-NativeExitCode
	return
}

if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN) -and [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
	throw "GH_TOKEN or GITHUB_TOKEN required for release Gate/Publish"
}

$repoRoot = Get-NvmRepoRoot
$defaultSearchRoot = if (-not [string]::IsNullOrWhiteSpace($AssetRoot)) {
	[System.IO.Path]::GetFullPath($AssetRoot)
}
else {
	$repoRoot
}

switch ($Mode) {
	"Gate" {
		if (-not (Test-ReleaseExists -Tag $tag)) {
			Write-Host ("Probing draft create for {0}..." -f $tag)
			New-NvmDraftRelease -Tag $tag -Version $version
			Write-Host ("Draft {0} ready — build may proceed." -f $tag)
			Clear-NativeExitCode
			return
		}

		$isDraft = Test-ReleaseIsDraft -Tag $tag
		$missing = New-Object System.Collections.Generic.List[string]
		$conflicts = New-Object System.Collections.Generic.List[string]

		foreach ($arch in $architectures) {
			$setupAssets = Get-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch -Kind "setup"
			$syncAssets = Get-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch -Kind "sync"
			$complete = ($setupAssets.Count -gt 0 -and $syncAssets.Count -gt 0)

			if (-not $complete) {
				$missing.Add($arch) | Out-Null
				Write-Host ("Release {0} ({1}) incomplete for {2}: setup={3} sync={4}." -f $tag, $(if ($isDraft) { "draft" } else { "published" }), $arch, $setupAssets.Count, $syncAssets.Count)
				continue
			}
			if ($OverrideExisting) {
				Write-Host ("Release {0} has complete {1} assets; override_existing_release=true — will replace after build:" -f $tag, $arch)
				@($setupAssets) + @($syncAssets) | ForEach-Object { Write-Host ("  - {0}" -f $_) }
				continue
			}
			foreach ($name in (@($setupAssets) + @($syncAssets))) {
				$conflicts.Add("${arch}: $name") | Out-Null
			}
		}

		if ($conflicts.Count -gt 0) {
			throw @"
Release $tag already has setup+sync assets for selected architecture(s):
$($conflicts | ForEach-Object { "  - $_" } | Out-String)
Re-run with override_existing_release=true to replace them (immutable must be OFF), or bump cli/src/manifest.json version.
"@
		}

		if ($missing.Count -eq 0 -and -not $OverrideExisting) {
			throw @"
Release $tag already has setup.exe + sync.exe for all selected architecture(s): $($architectures -join ', ').
Nothing to build/publish. Bump cli/src/manifest.json version, or re-run with override_existing_release=true (immutable must be OFF).
"@
		}

		if (-not $isDraft -and $missing.Count -gt 0) {
			Write-Host ("Published release {0} missing {1} — will upload after build (requires immutable OFF)." -f $tag, ($missing -join ", ")) -ForegroundColor Yellow
		}
	}

	"Publish" {
		if (-not (Test-ReleaseExists -Tag $tag)) {
			New-NvmDraftRelease -Tag $tag -Version $version
		}

		$state = Get-ReleaseUploadState -Tag $tag
		if ($state.IsDraft) {
			Write-Host ("Target release {0} is draft — upload setup+sync then publish." -f $tag)
		}
		else {
			Write-Host ("Target release {0} is already published — uploading with --clobber (immutable must be OFF)." -f $tag) -ForegroundColor Yellow
		}

		foreach ($arch in $architectures) {
			$setupAssets = Get-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch -Kind "setup"
			$syncAssets = Get-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch -Kind "sync"
			$hasAny = ($setupAssets.Count -gt 0 -or $syncAssets.Count -gt 0)
			$complete = ($setupAssets.Count -gt 0 -and $syncAssets.Count -gt 0)

			if ($complete -and -not $OverrideExisting) {
				throw ("Release {0} already has complete {1} setup+sync assets and override_existing_release is false." -f $tag, $arch)
			}
			if ($hasAny -and $OverrideExisting) {
				Remove-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch
			}
			elseif ($hasAny -and -not $complete) {
				Write-Host ("Release {0} incomplete for {1} (setup={2} sync={3}) — uploading missing assets without purge." -f $tag, $arch, $setupAssets.Count, $syncAssets.Count) -ForegroundColor Yellow
			}
		}

		$upload = New-Object System.Collections.Generic.List[string]
		$uploadSeenPath = @{}
		$uploadSeenName = @{}
		foreach ($arch in $architectures) {
			foreach ($kind in @("setup", "sync")) {
				$existingKind = Get-ReleaseAssetsForArchitecture -Tag $tag -Architecture $arch -Kind $kind
				if ($existingKind.Count -gt 0 -and -not $OverrideExisting) {
					Write-Host ("Keeping existing {0} asset(s) for {1}; skip upload of that kind." -f $kind, $arch)
					continue
				}
				$found = Get-NvmReleaseUploadPaths -Architecture $arch -SearchRoot $defaultSearchRoot -Kind $kind
				if ($found.Count -eq 0) {
					throw ("No {0}-{1}.exe found under {2}" -f $arch, $kind, $defaultSearchRoot)
				}
				if ($found.Count -gt 1) {
					Write-Host ("WARNING: multiple {0}-{1}.exe matches; uploading first unique names only." -f $arch, $kind) -ForegroundColor Yellow
				}
				foreach ($p in $found) {
					$base = [System.IO.Path]::GetFileName($p)
					if ($uploadSeenPath.ContainsKey($p) -or $uploadSeenName.ContainsKey($base)) {
						continue
					}
					$uploadSeenPath[$p] = $true
					$uploadSeenName[$base] = $true
					$upload.Add($p)
				}
			}
		}

		if ($upload.Count -eq 0) {
			throw ("Nothing to upload for {0} (all setup+sync assets already present)." -f $tag)
		}

		Write-Host ("Uploading {0} asset(s) to {1}..." -f $upload.Count, $tag)
		$upload | ForEach-Object { Write-Host ("  + {0}" -f $_) }

		$up = Invoke-GhCapture -GhArgs (@("release", "upload", $tag) + @($upload.ToArray()) + @("--clobber"))
		if ($up.ExitCode -ne 0) {
			throw "gh release upload $tag failed with exit code $($up.ExitCode): $($up.Text)"
		}

		Set-NvmReleaseNotes -Tag $tag -Version $version

		if ($state.IsDraft) {
			Publish-NvmDraftRelease -Tag $tag
		}
		else {
			Write-Host ("Release {0} was already published — skipped draft→publish." -f $tag)
		}

		$view = Get-ReleaseView -Tag $tag -JsonFields "url,databaseId,isDraft"
		if ($null -eq $view -or [string]::IsNullOrWhiteSpace([string]$view.databaseId)) {
			throw "Unable to read GitHub release databaseId for $tag after publish"
		}
		$url = [string]$view.url
		$releaseId = [string]$view.databaseId
		Write-Host ("Release ready -> {0} (id {1}, draft={2})" -f $url, $releaseId, $view.isDraft)
		if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
			$archList = $architectures -join ", "
			Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ("## GitHub Release`n`n[{0}]({1})`n`nArchitectures: {2}`n`nRelease ID: ``{3}```n`nAssets: ``*-setup.exe`` + ``*-sync.exe``" -f $tag, $url, $archList, $releaseId)
		}
	}
}

Clear-NativeExitCode
