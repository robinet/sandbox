<#

.DESCRIPTION

Install terraform using the releases API: https://releases.hashicorp.com/docs/api/v1/
TODO: Extend terraform installation to all hashicorp products

#>

param (
  [string] $Version = 'latest'
  , [string] $Arch = 'amd64' # or 386
  , [switch] $KeepCurrentVersion
)

<#-- Script variables --#>

$Product = 'terraform'
$OS = 'windows'

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
    throw "Could not find a windows build for version '$Version' and arch '$Arch'"
  }
  $downloadUrl = $downloadMetadata.url

  # Find specific version from download URL
  $matched = [UriBuilder]::new($downloadUrl).Path -match "^/$Product/([^/]+)/"
  if (-not $matched) {
    throw "Cannot find specific version for product '$Product' from URL '$downloadUrl'"
  }

  # Update version using capture group 1 at script scope
  $Script:Version = $Matches.1
  $downloadMetadata | Add-Member NoteProperty -Name 'version' -Value $Version

  return $downloadMetadata
}

function EnsureTerraformFolderExists([string] $specificVersion) {
  $folder = Join-Path $HOME -ChildPath ".$Product/$specificVersion/$Arch"
  if (-not (Test-Path $folder)) {
    $folder = (New-Item -ItemType Directory -Path $folder).FullName
  }
  else {
    $folder = (Resolve-Path -Path $folder).Path
  }
  return $folder
}

function DownloadAndExpandArchive([string] $downloadUrl, [string] $destinationFolder) {
  # Download .zip into temp file and extract to destination folder
  $tmp = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
  $currentProgressPreference = $ProgressPreference
  try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -Method Get -OutFile $tmp
    $tmp | Expand-Archive -DestinationPath $destinationFolder -Force
  }
  finally {
    $ProgressPreference = $currentProgressPreference
    $tmp | Remove-Item 
  }
}

<#-- Start of script --#>

# This function has side effects and may modify $Version
$downloadMetadata = GetDownloadMetadata

$destinationFolder = EnsureTerraformFolderExists -specificVersion $Version

DownloadAndExpandArchive -downloadUrl $downloadMetadata.url -destinationFolder $destinationFolder

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

  # Process update
  $userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Process) -split [IO.Path]::PathSeparator `
  | Where-Object {
    $pathStartsWith = Join-Path -Path $HOME -ChildPath ".$Product"
    return -not $_.StartsWith($pathStartsWith)
  }
  $updatedPath = $userPaths -join [IO.Path]::PathSeparator
  [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::Process)
}