function Test-LastNativeCall() {
  return $LASTEXITCODE -eq 0
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