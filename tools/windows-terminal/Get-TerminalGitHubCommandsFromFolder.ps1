<#
.EXAMPLE

./Get-TerminalGitHubCommandsFromFolder.ps1 -Folder '<path/to/parent-repos-folder>' -TabColor '#FC4C02' -Dark | ConvertTo-Json -Depth 10 | Out-File <terminal-commands.json>

#>

param (
  [string] $Folder = $(throw 'Folder is required'),
  [string] $TabColor,
  [switch] $Dark
)

$homeFolder = (Get-Item -Path (Resolve-Path $Folder).Path)

# Sub folders
$commands = (Get-ChildItem -Path $homeFolder.FullName -Directory).Name `
| ForEach-Object {
  $name = $_

  $command = @{
    action                   = 'newTab'
    startingDirectory        = (Join-Path -Path $homeFolder.FullName -ChildPath $name).Replace('\', '/')
    suppressApplicationTitle = $true
    tabTitle                 = $name
  }

  if (-not [string]::IsNullOrWhiteSpace($TabColor)) {
    $command.Add('tabColor', $TabColor)
  }

  # "https://github.githubassets.com/favicons/favicon[-dark.png]"
  $icon = 'https://github.githubassets.com/favicons/favicon'
  $icon = $Dark.IsPresent ? "$icon-dark.png" : "$icon.png"

  return [pscustomobject] @{
    action  = 'newTab'
    icon    = $icon
    name    = $name
    command = [pscustomobject]$command
  }
}

# Home folder
$homeCommand = @{
  action                   = 'newTab'
  startingDirectory        = $homeFolder.FullName.Replace('\', '/')
  suppressApplicationTitle = $true
  tabTitle                 = $homeFolder.Name
}
if (-not [string]::IsNullOrWhiteSpace($TabColor)) {
  $homeCommand.Add('tabColor', $TabColor)
}
$commands = @([pscustomobject]@{
    action  = 'newTab'
    icon    = '▶️'
    name    = "//$($homeFolder.Name)"
    command = [pscustomobject]$homeCommand
  }) `
  + $commands

return [pscustomobject]@{
  name     = "/$($homeFolder.Name)"
  icon     = '📂'
  commands = $commands
}
