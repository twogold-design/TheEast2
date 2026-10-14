Set-StrictMode -Version Latest
$projectRoot = $PSScriptRoot
$godotRoot = 'D:\tools\Godot-4.7.2'
$dataRoot = Join-Path $projectRoot '.godot-user'

$env:APPDATA = Join-Path $dataRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $dataRoot 'AppData\Local'
$env:TEMP = Join-Path $dataRoot 'Temp'
$env:TMP = $env:TEMP

New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP, (Join-Path $dataRoot 'Logs') | Out-Null

& (Join-Path $godotRoot 'Godot_v4.7.2-stable_win64.exe') `
  --editor `
  --path $projectRoot `
  --log-file (Join-Path $dataRoot 'Logs\editor.log')
