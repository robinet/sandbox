<#
  .DESCRIPTION

  Install latest release of a GitHub repository (pre-compiled binaries) using the releases API: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
  TODO: Extend to non-zip releases (e.g. EXE, MSI, DEB, etc.)
  TODO: Explain usage of AssetMatch, KeepCurrentVersion and ProfileName
  TODO: Provide flexibility on folder to add into PATH (root vs bin vs custom)

  .EXAMPLE

  # Install 'protoc' for windows 64-bit
  .\Install-GitHubRelease.ps1 -Owner 'protocolbuffers' -Repo 'protobuf' -AssetMatch '/protoc-(?:[0-9\.]+)-win64.zip'

#>

param (
  [string] $Owner = $(throw 'Owner is required')
  , [string] $Repo = $(throw 'Repository is required')
  , [string] $AssetMatch = $(throw 'AssetMatch is required')
  , [switch] $KeepCurrentVersion
  , [string] $ProfileName = $null
)

<#-- Script Dependencies --#>

. "$PSScriptRoot/../Shared.ps1"

./Set-GitHubConnection.ps1 -ProfileName $ProfileName

<#-- Script Functions --#>

$GitHubReleasesRoot = '.github-releases'

function EnsureFolderExists([string] $relativeFolder) {
  $folder = Join-Path $HOME -ChildPath "$GitHubReleasesRoot/$relativeFolder"
  if (-not (Test-Path $folder)) {
    $folder = (New-Item -ItemType Directory -Path $folder).FullName
  }
  else {
    $folder = (Resolve-Path -Path $folder).Path
  }
  return $folder
}

<#-- Start of script --#>

Push-Location $PSScriptRoot
try {
  $endpoint = "/repos/$Owner/$Repo/releases/latest"
  $apiResult = $(gh api -X GET $endpoint 2>$null) | ConvertFrom-Json -Depth 100
  if (-not (Test-LastNativeCall)) {
    throw "GitHub API error: $apiResult. ENDPOINT: '$endpoint'."
  }
  $assets = $apiResult.assets | Where-Object -Property 'browser_download_url' -Match $AssetMatch
  if (-not $assets.Count -eq 1) {
    throw "Could not find a release asset matching '$AssetMatch' for '$endpoint'."
  }

  $downloadUrl = $assets.browser_download_url

  $pathParts = ([UriBuilder]::new($downloadUrl).Path.Trim('/') -split '/')
  $version = $pathParts[4]
  $extractFolder = [IO.Path]::GetFileNameWithoutExtension($pathParts[-1])
  $relativeFolder = "$Owner/$Repo/$version/$extractFolder"

  $destinationFolder = EnsureFolderExists $relativeFolder

  DownloadAndExpandArchive -downloadUrl $downloadUrl -destinationFolder $destinationFolder

  Write-Host "Installed '$relativeFolder' into '$destinationFolder'."

  if (-not $KeepCurrentVersion.IsPresent) {
    $binFolder = Join-Path $destinationFolder -ChildPath 'bin'
    $pathFolder = (Test-Path $binFolder) ? $binFolder : $destinationFolder

    # User update
    $userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User) -split [IO.Path]::PathSeparator `
    | Where-Object {
      $pathStartsWith = Join-Path -Path $HOME -ChildPath "$GitHubReleasesRoot/$Owner/$Repo"
      return -not $_.StartsWith($pathStartsWith)
    }
    $userPaths += $pathFolder
    $updatedPath = $userPaths -join [IO.Path]::PathSeparator
    [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::User)

    Write-Host "Updated '$($Env:USERNAME)' path. Added '$pathFolder'."

    # Process update
    $userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Process) -split [IO.Path]::PathSeparator `
    | Where-Object {
      $pathStartsWith = Join-Path -Path $HOME -ChildPath "$GitHubReleasesRoot/$Owner/$Repo"
      return -not $_.StartsWith($pathStartsWith)
    }
    $userPaths += $pathFolder
    $updatedPath = $userPaths -join [IO.Path]::PathSeparator
    [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::Process)

    Write-Host "Updated '$PSCommandPath' path. Added '$pathFolder'."
  }

}
finally {
  Pop-Location
}