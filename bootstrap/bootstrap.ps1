#Requires -Version 5.1
<#
.SYNOPSIS
    Sets up a Windows PC for development: winget apps, the dotfiles' PowerShell profile and prompt,
    Git and GitHub, the config repositories, VS Code extensions, the captured Windows settings and
    WSL2 Ubuntu ready for linux-bootstrap.

.DESCRIPTION
    Each stage checks what is already in place and acts only where something is missing, so the
    same command sets up a new PC and re-checks an existing one. -Plan shows every action without
    changing anything.

.PARAMETER Plan
    Print what each stage would do and change nothing. CI runs the bootstrap this way.

.PARAMETER Skip
    Stages to leave out, for example -Skip wsl,vscode.

.EXAMPLE
    .\bootstrap\bootstrap.ps1
.EXAMPLE
    .\bootstrap\bootstrap.ps1 -Plan
#>
[CmdletBinding()]
param(
    [switch]$Plan,
    [ValidateSet('winget', 'dotfiles', 'git', 'configs', 'vscode', 'settings', 'wsl')]
    [string[]]$Skip = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\winget.ps1')
. (Join-Path $PSScriptRoot 'lib\dotfiles.ps1')
. (Join-Path $PSScriptRoot 'lib\git.ps1')
. (Join-Path $PSScriptRoot 'lib\configs.ps1')
. (Join-Path $PSScriptRoot 'lib\vscode.ps1')
. (Join-Path $PSScriptRoot 'lib\wsl.ps1')

$script:PlanMode = [bool]$Plan

Assert-SupportedPlatform
if ($script:PlanMode) { Write-Info 'Plan mode: showing what would happen, changing nothing' }

$stages = [ordered]@{
    winget   = { Install-WingetPackages }
    dotfiles = { Install-Dotfiles }
    git      = { Set-GitConfiguration }
    configs  = { Install-ConfigRepos }
    vscode   = { Install-VSCodeExtensions }
    settings = { Set-WindowsSettings }
    wsl      = { Install-Wsl }
}

foreach ($name in $stages.Keys) {
    if ($Skip -contains $name) {
        Write-Info "Skipping stage: $name"
        continue
    }
    Invoke-Stage -Name $name -Action $stages[$name]
}

Write-Ok 'Windows Bootstrap completed'
Write-Info 'Open a new terminal so the PowerShell profile loads'
