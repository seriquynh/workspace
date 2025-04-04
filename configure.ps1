$PowerShellProfileDir = "$HOME\Documents\WindowsPowerShell"

if (Test-Path "$HOME\OneDrive\Documents\WindowsPowerShell") {
    $PowerShellProfileDir = "$HOME\OneDrive\Documents\WindowsPowerShell"
}

Copy-Item "$PSScriptRoot\profile.ps1" "$HOME\OneDrive\Documents\WindowsPowerShell"
Write-Host "Copied "$PSScriptRoot\profile.ps1" to $PowerShellProfileDir"

Copy-Item "$PSScriptRoot\dev.ps1" "$HOME\OneDrive\Documents\WindowsPowerShell"
Write-Host "Copied "$PSScriptRoot\dev.ps1" to $PowerShellProfileDir"

Copy-Item "$PSScriptRoot\.gitignore" "$HOME\.gitignore"
Write-Host "Copied "$PSScriptRoot\.gitignore" to $HOME"
