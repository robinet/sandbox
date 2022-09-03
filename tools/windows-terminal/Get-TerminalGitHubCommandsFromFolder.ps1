<#
.EXAMPLE

./Get-TerminalGitHubCommandsFromFolder.ps1 -Folder '<path/to/parent-repos-folder>' -TabColor '#FC4C02A'  -Dark | ConvertTo-Json | Out-File <terminal-commands.json>
#>

param (
  [string] $Folder = $(throw 'Folder is required'),
  [string] $TabColor,
  [switch] $Dark
)

$Folder = Resolve-Path $Folder

return (Get-ChildItem -Path $Folder -Directory).Name `
| ForEach-Object {
  $name = $_

  $command = @{
    action                   = 'newTab'
    startingDirectory        = (Join-Path -Path $Folder -ChildPath $name).Replace('\', '/')
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
    action  = 'newTab';
    icon    = $icon;
    name    = $name;
    command = [pscustomobject]$command
  }
}



<#
{
  "action": "newTab",
  "command": 
  {
      "action": "newTab",
      "startingDirectory": "C:/Projects/GitHub/<organization>/ic2-iac",
      "suppressApplicationTitle": true,
      "tabTitle": "ic2-iac",
      "tabColor": "#06332A"
  },
  "icon": "https://github.githubassets.com/favicons/favicon-dark.png", // /favicons/favicon[-dark].png
  "name": "ic2-iac"
}
#>