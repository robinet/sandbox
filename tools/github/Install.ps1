param (
)


<#-- Start of script --#>

$ErrorActionPreference = 'Stop'

$userPaths = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User) -split [IO.Path]::PathSeparator
if ($userPaths -contains $PSScriptRoot) {
  Write-Host "$($Env:USERNAME) path contains '$PSScriptRoot' already."
  return
}

$userPaths += $PSScriptRoot
$updatedPath = $userPaths -join [IO.Path]::PathSeparator

[Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::Process)

if ($Env:OS.StartsWith('Windows')) {
  #TODO: Target is ignored on non Windows OS
  [Environment]::SetEnvironmentVariable('PATH', $updatedPath, [EnvironmentVariableTarget]::User)
  Write-Host "Updated '$($Env:USERNAME)' path. Added '$PSScriptRoot'."
}