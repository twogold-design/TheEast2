param([string]$Godot=$env:GODOT_BIN)
$ErrorActionPreference='Stop'
if (!$Godot) { $Godot='D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
$work=Join-Path $PSScriptRoot '.web-build'
$env:APPDATA=Join-Path $work 'appdata'
$env:LOCALAPPDATA=Join-Path $work 'localappdata'
$env:TEMP=Join-Path $work 'temp'
$env:TMP=$env:TEMP
$source=Join-Path $work ('source-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force $source,$env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'src\*') -Destination $source -Recurse
$project=Join-Path $source 'project.godot'
$projectText=[IO.File]::ReadAllText($project)
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($project,($projectText -replace '(?m)^theme/custom_font=.*\r?\n',''),$utf8)
& $Godot --headless --editor --path $source --import --quit --log-file (Join-Path $work 'import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $work 'import.log') -Pattern '^(SCRIPT ERROR:|ERROR:)')) { throw 'Godot import failed. See import.log.' }
[IO.File]::WriteAllText($project,$projectText,$utf8)
& $Godot --headless --editor --path $source --quit --log-file (Join-Path $work 'validate.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $work 'validate.log') -Pattern '^(SCRIPT ERROR:|ERROR:)')) { throw 'Godot validation failed. See validate.log.' }
& $Godot --headless --path $source --export-release Web (Join-Path $PSScriptRoot 'index.html') --log-file (Join-Path $work 'export.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $work 'export.log') -Pattern '^(SCRIPT ERROR:|ERROR:)')) { throw 'Godot Web export failed. See export.log.' }
& node (Join-Path $PSScriptRoot 'src\web\prepare_local.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Offline bundle failed.' }
$excluded=@('.git','.web-build','.qa-cache','.npm-cache','node_modules')
$size=0L
foreach ($item in Get-ChildItem -LiteralPath $PSScriptRoot -Force) {
    if ($item.Name -in $excluded) { continue }
    if ($item.PSIsContainer) { $size+=(Get-ChildItem -LiteralPath $item.FullName -File -Recurse | Measure-Object Length -Sum).Sum }
    else { $size+=$item.Length }
}
if ($size -ge 200000000) { throw "Complete project exceeds 200 MB: $size bytes" }
Write-Output "Web project ready: $size bytes"
