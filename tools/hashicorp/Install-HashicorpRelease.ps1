<#

.DESCRIPTION

Install a Hashicorp product (pre-compiled binaries) using the releases API: https://releases.hashicorp.com/docs/api/v1/
TODO: Extend terraform and packer installation to all hashicorp products

#>

param (
  [Validateset('terraform', 'packer')] [string] $Product = 'terraform'
  , [Validateset('windows', 'linux', 'darwin')] [string] $OS = 'windows' 
  , [string] $Version = 'latest'
  , [Validateset('386', 'amd64', 'arm64')] [string] $Arch = 'amd64'
  , [switch] $KeepCurrentVersion
)

<#-- Script Dependencies --#>

. "$PSScriptRoot/../Shared.ps1"

<#-- Script Functions --#>

# Retrieves a zip file URL
function GetDownloadMetadata() {
  # https://api.releases.hashicorp.com/v1/releases/terraform/latest

  $uri = "https://api.releases.hashicorp.com/v1/releases/$Product/$Version"
  $builds = (Invoke-RestMethod -Method Get -Uri $uri).builds
  $downloadMetadata = ($builds `
    | Where-Object {
      $_.os -eq $OS -and $_.arch -eq $Arch
    })
  if ($null -eq $downloadMetadata) {
    throw "Could not find a build for '$Product' (OS: $OS, VERSION: $Version, ARCH: $Arch)."
  }
  $downloadUrl = $downloadMetadata.url

  # Find specific version from download URL
  $matched = [UriBuilder]::new($downloadUrl).Path -match "^/$Product/([^/]+)/"
  if (-not $matched) {
    throw "Cannot find a specific version for '$Product' from URL '$downloadUrl' (OS: $OS, VERSION: $Version, ARCH: $Arch)."
  }

  # Update version using capture group 1 at script scope
  $Script:Version = $Matches.1
  $downloadMetadata | Add-Member NoteProperty -Name 'version' -Value $Version

  return $downloadMetadata
}

function EnsureProductFolderExists([string] $specificVersion) {
  $folder = Join-Path $HOME -ChildPath ".$Product/$specificVersion/$Arch"
  if (-not (Test-Path $folder)) {
    $folder = (New-Item -ItemType Directory -Path $folder).FullName
  }
  else {
    $folder = (Resolve-Path -Path $folder).Path
  }
  return $folder
}

<#-- Start of script --#>

# This function has side effects and may modify $Version
$downloadMetadata = GetDownloadMetadata

$destinationFolder = EnsureProductFolderExists -specificVersion $Version

DownloadAndExpandArchive -downloadUrl $downloadMetadata.url -destinationFolder $destinationFolder

Write-Host "Installed '$Product' into '$destinationFolder' (OS: $OS, VERSION: $Version, ARCH: $Arch)."

if (-not $KeepCurrentVersion.IsPresent) {
  # User update
  $userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User) -split [IO.Path]::PathSeparator `
  | Where-Object {
    $pathStartsWith = Join-Path -Path $HOME -ChildPath ".$Product"
    return -not $_.StartsWith($pathStartsWith)
  }
  $userPaths += $destinationFolder
  $updatedPath = $userPaths -join [IO.Path]::PathSeparator
  [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::User)

  Write-Host "Updated '$($Env:USERNAME)' path for '$Product' (OS: $OS, VERSION: $Version, ARCH: $Arch)."

  # Process update
  $userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Process) -split [IO.Path]::PathSeparator `
  | Where-Object {
    $pathStartsWith = Join-Path -Path $HOME -ChildPath ".$Product"
    return -not $_.StartsWith($pathStartsWith)
  }
  $updatedPath = $userPaths -join [IO.Path]::PathSeparator
  [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::Process)

  Write-Host "Updated '$PSCommandPath' path for '$Product' (OS: $OS, VERSION: $Version, ARCH: $Arch)."
}