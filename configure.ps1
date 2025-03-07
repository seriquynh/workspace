$ProfileFile = "$PSScriptRoot\profile.ps1"

if (Test-Path "$HOME\Documents\WindowsPowerShell") {
    Copy-Item $ProfileFile "$HOME\Documents\WindowsPowerShell"

    Write-Host "Copy $ProfileFile to $HOME\Documents\WindowsPowerShell"
} elseif (Test-Path "$HOME\OneDrive\Documents\WindowsPowerShell") {
    Copy-Item $ProfileFile "$HOME\OneDrive\Documents\WindowsPowerShell"

    Write-Host "Copy $ProfileFile to $HOME\OneDrive\Documents\WindowsPowerShell"
}
