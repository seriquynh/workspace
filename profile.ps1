$PowerShellProfileDir = "$HOME\Documents\WindowsPowerShell"

if (Test-Path "$HOME\OneDrive\Documents\WindowsPowerShell") {
    $PowerShellProfileDir = "$HOME\OneDrive\Documents\WindowsPowerShell"
}

function Write-Info {
    param(
        [Parameter(Mandatory)]
        [string]$Message

        # [Parameter(Mandatory=$false)]  # Optional parameter
        # [string]$Greeting = "Hello"    # Default value
    )

    Write-Host $Message -ForegroundColor Green
}

Write-Info "Loading profile.ps1"

Write-Output ""

Write-Info " * Custom commands, functions or scripts:"

$devFile = "$PowerShellProfileDir\dev.ps1"
if (Test-Path $devFile) {
    Set-Alias -Name dev -Value $devFile
    Write-Info "    -> Created 'dev' alias for $devFile"
}

# Git

#function Invoke-GitStatus {
#    git status $args
#}
#
#function Invoke-GitAdd {
#    git add $args
#}
#
#function Invoke-GitFetch {
#    git fetch origin --prune
#}
#
#if (-not (Test-Path 'Alias:gs')) {
#    Set-Alias -Name 'gs' -Value Invoke-GitStatus
#    Write-Info "Created 'gs' alias for git status"
#}
#
#if (-not (Test-Path 'Alias:ga')) {
#    Set-Alias -Name 'ga' -Value Invoke-GitAdd
#    Write-Info "Created 'ga' alias for git add"
#}
#
#if (-not (Test-Path 'Alias:gf')) {
#    Set-Alias -Name 'gf' -Value Invoke-GitFetch
#    Write-Info "Created 'gf' alias for git fetch origin --prune"
#}

Write-Output ""

Write-Info " * Built-in commands, functions or scripts:"

if (-not (Test-Path 'Alias:pstorm')) {
    Set-Alias -Name pstorm -Value PhpStorm1
    Write-Info "    -> Created 'pstorm' alias for PhpStorm1"
}


Write-Output ""
