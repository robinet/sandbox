<#
.EXAMPLE

./Set-GitHubConnection.ps1

./Set-GitHubConnection.ps1 -Override

./Set-GitHubConnection.ps1 -ProfileName '<profile-name>'

./Set-GitHubConnection.ps1 -ProfileName '<profile-name>' -Override
#>

param (
  [string] $ProfileName,
  [switch] $Override
)

<#-- Script Dependencies --#>

. "$PSScriptRoot/../Shared.ps1"

<#-- Script Parameters --#>

$GitHubHost = 'github.com'

<#-- Script Functions --#>

function IsLoggedIn() {
  $(gh auth status -h $GitHubHost 2>$null) | Out-Null
  return Test-LastNativeCall
}

function LoginInteractively() {
  # Do not use '| Out-Null' here. We'll be using device-code login
  gh auth login --hostname $GitHubHost --web
  if (-not (Test-LastNativeCall)) {
    throw 'GitHub login has been canceled or failed (interactive login).'
  }
}

function Logout() {
  $(gh auth logout --hostname $GitHubHost 2>$null) | Out-Null
  return Test-LastNativeCall
}

function GetProfileFile([string] $name) {
  if ([string]::IsNullOrWhiteSpace($name)) {
    throw 'Profile name cannot be empty.'
  }
  return Join-Path -Path $HOME -ChildPath ".com.github.$name.json"
}

function LoadConfigFromFile ([string] $name) {
  $file = GetProfileFile -name $name
  if (-not [System.IO.File]::Exists($file)) {
    return $null
  }
  return Get-Content $file -Raw | ConvertFrom-Json
}

function SaveConfigToFile ([pscustomobject] $config) {
  $file = GetProfileFile -name $config.User
  ConvertTo-Json $config | Set-Content $file | Out-Null
}

function GetCurrentConfig() {
  if (-not (IsLoggedIn)) {
    return $null
  }
  $token = $(gh config get -h $GitHubHost oauth_token 2>$null)
  if (-not (Test-LastNativeCall)) {
    throw "Could not get 'oauth_token' from current config."
  }
  $user = $(gh config get user -h $GitHubHost 2>$null)
  if (-not (Test-LastNativeCall)) {
    throw "Could not get 'user' from current config."
  }
  $config = @{
    User           = $user
    EncryptedToken = ConvertTo-SecureString $token -AsPlainText | ConvertFrom-SecureString
  }
  $editor = $(gh config get editor -h $GitHubHost 2>$null)
  if ((Test-LastNativeCall)) {
    $config.Add('Editor', $editor)
  }
  $protocol = $(gh config get git_protocol -h $GitHubHost 2>$null)
  if ((Test-LastNativeCall)) {
    $config.Add('Protocol', $protocol)
  }
  return [pscustomobject]$config
}

function SetCurrentConfig([pscustomobject] $config) {
  $user = $config.User
  if (-not [string]::IsNullOrWhiteSpace($user)) {
    $(gh config set user $user -h $GitHubHost 2>$null) | Out-Null
    if (-not (Test-LastNativeCall)) {
      throw "Setting 'user' property in current config failed."
    }
  }
  $editor = $config.Editor
  if (-not [string]::IsNullOrWhiteSpace($editor)) {
    $(gh config set editor $editor -h $GitHubHost 2>$null) | Out-Null
  }
  $protocol = $config.Protocol
  if (-not [string]::IsNullOrWhiteSpace($protocol)) {
    $(gh config set git_protocol $protocol -h $GitHubHost 2>$null) | Out-Null
  }
}

function LoginWithEncryptedToken ([string] $encryptedToken) {
  $secureToken = ConvertTo-SecureString $encryptedToken
  $token = ConvertFrom-SecureString $secureToken -AsPlainText
  $isLoggedIn = IsLoggedIn
  if ($isLoggedIn) {
    $isSuccessfulLogout = Logout
    if (-not $isSuccessfulLogout) {
      throw 'GitHub logout failed (non-interactive login).'
    }
  }
  $($token | gh auth login -h $GitHubHost --with-token 2>$null) | Out-Null
  if (-not (Test-LastNativeCall)) {
    throw 'GitHub login failed (non-interactive login).'
  }
}

<#-- START OF SCRIPT --#>

$isOverride = $Override.IsPresent
$isProfileNameSpecified = -not [string]::IsNullOrWhiteSpace($ProfileName)
$isAlreadyLoggedIn = IsLoggedIn

# User wants to save the current profile (and potentially login)
if (-not $isProfileNameSpecified) {

  if (-not $isAlreadyLoggedIn) {
    LoginInteractively
  }

  $currentConfig = GetCurrentConfig 
  $currentProfileName = $currentConfig.User
  $storedConfig = LoadConfigFromFile -name $currentProfileName

  if ($null -ne $storedConfig -and -not $isAlreadyLoggedIn -and -not $isOverride) {
    throw "Profile '$currentProfileName' file exists. Specify the '-Override' switch to replace."
  }

  if ($null -eq $storedConfig -or $isOverride) {
    SaveConfigToFile -config $currentConfig
    return
  }

  return
}

$storedConfig = LoadConfigFromFile -name $ProfileName

# Login with stored profile
if ($null -ne $storedConfig -and -not $isOverride) {

  if ($ProfileName -ne $storedConfig.User) {
    $file = GetProfileFile -name $ProfileName
    throw "Profile '$ProfileName' and stored user '$($storedConfig.User)' mismatch. Please, delete '$file'"
  }

  LoginWithEncryptedToken -encryptedToken $storedConfig.EncryptedToken
  SetCurrentConfig -config $storedConfig
  return
}

# Override or no stored profile
if (-not $isAlreadyLoggedIn) {
  LoginInteractively
}

try {
  $currentConfig = GetCurrentConfig
  if ($ProfileName -ne $currentConfig.User) {
    throw "Profile '$ProfileName' and current user '$($currentConfig.User)' mismatch. Cannot save profile. Please logout 'gh auth logout'."
  }
  SaveConfigToFile -config $currentConfig
}
finally {
  if (-not $isAlreadyLoggedIn) {
    Logout
  }
}