$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$src=Join-Path $root 'TayTweaks.ps1'
$out=Join-Path $root 'TayTweaks.exe'
if(!(Test-Path $src)){throw 'TayTweaks.ps1 is missing'}
if(!(Get-Module -ListAvailable ps2exe)){Install-Module ps2exe -Scope CurrentUser -Force}
Import-Module ps2exe
$icon=Join-Path $root 'TayTweaks.ico'
if(!(Test-Path $icon)){throw 'TayTweaks.ico missing: upload it to this branch before building'}
Invoke-PS2EXE -inputFile $src -outputFile $out -noConsole -requireAdmin -iconFile $icon -title 'Tay-Tweaks' -product 'Tay-Tweaks' -version '6.4.1.0'
if(!(Test-Path $out)){throw 'EXE build failed'}
Write-Host "Built $out"
