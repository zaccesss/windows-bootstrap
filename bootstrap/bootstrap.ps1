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
    Stages to leave out, for example -Skip wsl,vscode. A single comma-separated string such as
    'wsl,vscode' works too, which is how the list arrives when the script is started with pwsh -File.

.PARAMETER SkipPackage
    winget package ids to leave out on this run, on top of the PC's own list in
    packages\skip\<computer name>.txt. Comma-separated strings work as for -Skip.

.EXAMPLE
    .\bootstrap\bootstrap.ps1
.EXAMPLE
    .\bootstrap\bootstrap.ps1 -Plan
#>
[CmdletBinding()]
param(
    [switch]$Plan,
    [ArgumentCompleter({ 'winget', 'dotfiles', 'git', 'configs', 'vscode', 'settings', 'wsl' })]
    [string[]]$Skip = @(),
    [string[]]$SkipPackage = @()
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
$Skip = Resolve-SkipList -Skip $Skip
$SkipPackage = @($SkipPackage | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

Assert-SupportedPlatform
if ($script:PlanMode) { Write-Info 'Plan mode: showing what would happen, changing nothing' }

$stages = [ordered]@{
    winget   = { Install-WingetPackages -SkipPackage $SkipPackage }
    dotfiles = { Install-Dotfiles }
    git      = { Set-GitConfiguration }
    configs  = { Install-ConfigRepos }
    vscode   = { Install-VSCodeExtensions }
    settings = { Set-WindowsSettings; Hide-HomeDotItems }
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
