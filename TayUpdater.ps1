param([int]$PidToWait,[string]$Source,[string]$Destination,[string]$ExpectedHash)
$ErrorActionPreference='Stop'
try {
 if($PidToWait -gt 0){try{Wait-Process -Id $PidToWait -Timeout 45 -ErrorAction Stop}catch{}}
 if(-not (Test-Path -LiteralPath $Source)){throw 'Downloaded update missing'}
 if((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ine $ExpectedHash){throw 'Update hash mismatch'}
 $backup="$Destination.previous"
 if(Test-Path -LiteralPath $Destination){Copy-Item -LiteralPath $Destination -Destination $backup -Force}
 try{Copy-Item -LiteralPath $Source -Destination $Destination -Force;Start-Process -FilePath $Destination -Verb RunAs}
 catch{if(Test-Path -LiteralPath $backup){Copy-Item -LiteralPath $backup -Destination $Destination -Force};throw}
}catch{
 Add-Type -AssemblyName System.Windows.Forms
 [System.Windows.Forms.MessageBox]::Show("Update failed; previous version preserved where possible.`r`n$($_.Exception.Message)",'Tay Tweaks Updater')|Out-Null
}
