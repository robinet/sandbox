<#
.EXAMPLE

./Set-GitHubConnection.ps1

./Set-GitHubConnection.ps1 '<profile-name>'

./Set-GitHubConnection.ps1 '<profile-name>' -Override
#>

param (
  [string] $ProfileName,
  [switch] $Override
)

function LoadConfigFromFile ([string] $name) {
  $file = Join-Path $Env:USERPROFILE -ChildPath ".com.github.$name.json"
  if (-not [System.IO.File]::Exists($file)) {
    return $null
  }
  return Get-Content $file -Raw | ConvertFrom-Json
}

function SaveConfigToFile ([psobject] $config, [string] $name) {
  $file = Join-Path $Env:USERPROFILE -ChildPath ".com.github.$name.json"
  ConvertTo-Json $config | Set-Content $file | Out-Null
}

function GetCurrentConfig() {
  $token = (gh config get -h 'github.com' oauth_token)
  $secureToken = ConvertTo-SecureString $token -AsPlainText
  return [psobject]@{
    Editor = (gh config get editor -h 'github.com');
    Protocol = (gh config get git_protocol -h 'github.com');
    User = (gh config get user -h 'github.com');
    EncryptedToken = ConvertFrom-SecureString $secureToken
  }
}

function SetCurrentConfig([psobject] $config) {
  gh config set git_protocol $config.Protocol -h 'github.com'
  $editor = $config.Editor
  if (-not [string]::IsNullOrWhiteSpace($editor)) {
    gh config set editor $editor -h 'github.com'
  }
  $user = $config.User
  if (-not [string]::IsNullOrWhiteSpace($user)) {
    gh config set user $user -h 'github.com' 2>$null
  }
}

function LoginWithEncryptedToken ([string] $encryptedToken) {
  $secureToken = ConvertTo-SecureString $encryptedToken
  $token = ConvertFrom-SecureString $secureToken -AsPlainText
  $token | gh auth login -h 'github.com' --with-token
}

function LoginInteractivelyIfNecessary () {
  gh auth status -h github.com 2>$null
  $isAlreadyLoggedIn = $LASTEXITCODE -eq 0
  if (-not $isAlreadyLoggedIn) {
    gh auth login -h 'github.com' -w
  }
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub interactive login has been canceled or failed."
  }
  return $isAlreadyLoggedIn
}

$isProfileNameSpecified = -not [string]::IsNullOrWhiteSpace($ProfileName)
$isOverride = $Override.IsPresent

# Happy days: ProfileName specified with Override flag. We don't care about contents of the file
if ($isProfileNameSpecified -and $isOverride) {
  LoginInteractivelyIfNecessary | Out-Null
  $config = GetCurrentConfig
  SaveConfigToFile $config $ProfileName
  return
}

# Sad days: ProfileName not specified. Get it from context and make sure we don't override unless specified
if (-not $isProfileNameSpecified) {
  $isAlreadyLoggedIn = LoginInteractivelyIfNecessary
  $config = GetCurrentConfig
  $ProfileName = $config.User

  $existingConfig = LoadConfigFromFile $ProfileName
  if ($null -ne $existingConfig -and -not $isOverride) {
    # Logout if we logged in
    if (-not $isAlreadyLoggedIn) {
      gh auth logout
    }
    throw "Found existing profile '$ProfileName' but '-Override' was not set."
  }

  # No matching profile found or we are overriding anyways
  SaveConfigToFile $config $ProfileName
  return
}

# At this point ProfileName has been specified and the Override flag is not set
# See above conditions ("Happy days" and "Sad days")

$config = LoadConfigFromFile $ProfileName
# If profile file does not exist, ask the user to login and save
if ($null -ne $config ) {
  LoginInteractivelyIfNecessary | Out-Null
  $config = GetCurrentConfig
  SaveConfigToFile $config $ProfileName
  return
}

# At this point: ProfileName has been specified and profile has been found. Override flag is not set
LoginWithEncryptedToken $config.EncryptedToken | Out-Null
SetCurrentConfig $config