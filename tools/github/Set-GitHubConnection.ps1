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
  if ($LASTEXITCODE -ne 0) {
    gh auth login -h 'github.com' -w
  }
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub interactive login has been canceled or failed."
  }
}

if ([string]::IsNullOrWhiteSpace($ProfileName)) {
  LoginInteractivelyIfNecessary
  $ProfileName = (GetCurrentConfig).User
}

$isOverride = $Override.IsPresent
$config = LoadConfigFromFile $ProfileName

if ($isOverride -or $null -eq $config) {
  LoginInteractivelyIfNecessary
  $config = GetCurrentConfig
  SaveConfigToFile $config $ProfileName
  return
}

LoginWithEncryptedToken $config.EncryptedToken
SetCurrentConfig $config