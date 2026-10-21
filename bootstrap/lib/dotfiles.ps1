# GitHub sign-in, the dotfiles and the pointers that make the PowerShell profile and prompt live.
# The profile file only dot-sources the one in the repository, so editing a topic file there takes
# effect in the next terminal without copying anything

function Connect-GitHub {
    if ($script:PlanMode) {
        Write-Info 'Would sign in to GitHub in the browser if not already signed in'
        return
    }
    gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Info 'Already signed in to GitHub'
        return
    }
    Write-Info 'Signing in to GitHub; a browser window will ask you to confirm'
    gh auth login --hostname github.com --git-protocol ssh --web
    gh auth setup-git
}

# PowerShell 7 keeps its profile under Documents\PowerShell whichever PowerShell runs the bootstrap,
# and OneDrive may have moved Documents, so the real folder is asked for rather than assumed
function Get-Pwsh7ProfilePath {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    return Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
}

function Install-Dotfiles {
    Connect-GitHub

    $dotfiles = Join-Path $script:ReposDir 'dotfiles'
    Get-Repository -Repository 'dotfiles' -Target $dotfiles

    $profileTarget = Join-Path $dotfiles 'windows\Microsoft.PowerShell_profile.ps1'
    Set-PointerFile -Path (Get-Pwsh7ProfilePath) -Content ". `"$profileTarget`""

    # zt and its Command Prompt wrappers live in windows\scripts, so that folder goes on the user PATH
    Add-UserPath (Join-Path $dotfiles 'windows\scripts')
    Set-CmdAutoRun -Script (Join-Path $dotfiles 'windows\cmd\autorun.cmd')

    # starship reads its config from STARSHIP_CONFIG, so the prompt follows the repository's file
    $starship = Join-Path $dotfiles 'windows\starship.toml'
    if ([Environment]::GetEnvironmentVariable('STARSHIP_CONFIG', 'User') -eq $starship) {
        Write-Info 'starship already uses the dotfiles config'
    } else {
        Invoke-Step "set STARSHIP_CONFIG to $starship" {
            [Environment]::SetEnvironmentVariable('STARSHIP_CONFIG', $starship, 'User')
        }
    }
}

function Add-UserPath {
    param([string]$Folder)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($current -split ';' | Where-Object { $_ })
    if ($parts -contains $Folder) {
        Write-Info "Already on the user PATH: $Folder"
        return
    }
    Invoke-Step "add $Folder to the user PATH" {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $Folder) -join ';'), 'User')
    }
}

# a registry value. $null when the key or value is missing (or there is no registry at all)
function Get-RegistryValue {
    param([string]$Key, [string]$Name)
    $item = Get-ItemProperty -Path $Key -ErrorAction SilentlyContinue
    if ($item -and $item.PSObject.Properties[$Name]) { return $item.$Name }
    return $null
}

# the AutoRun command that runs the dotfiles' Command Prompt start-up first and keeps whatever was
# there before after it, so another tool's AutoRun still runs
function Get-CmdAutoRunValue {
    param([string]$Existing, [string]$Script)
    $ours = "call `"$Script`""
    if (-not $Existing) { return $ours }
    if ($Existing.Contains($Script)) { return $Existing }
    return "$ours & $Existing"
}

# cmd.exe runs the AutoRun value under this key every time it starts. An earlier value is saved to
# the state folder before it is chained. the console host is also told to read ANSI colour codes,
# which Windows Terminal always does
function Set-CmdAutoRun {
    param([string]$Script, [string]$Key = 'HKCU:\Software\Microsoft\Command Processor')
    $existing = Get-RegistryValue -Key $Key -Name AutoRun
    $wanted = Get-CmdAutoRunValue -Existing $existing -Script $Script
    if ($existing -eq $wanted) {
        Write-Info 'Command Prompt already runs the dotfiles start-up'
    } else {
        Invoke-Step "make Command Prompt run $Script when it starts" {
            if ($existing) {
                New-Item -ItemType Directory -Force -Path $script:StateDir | Out-Null
                Set-Content -Path (Join-Path $script:StateDir 'cmd-autorun-before.txt') -Value $existing
            }
            if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
            Set-ItemProperty -Path $Key -Name AutoRun -Value $wanted
        }
    }
    $console = 'HKCU:\Console'
    if ((Get-RegistryValue -Key $console -Name VirtualTerminalLevel) -ne 1) {
        Invoke-Step 'let the console host show ANSI colours' {
            Set-ItemProperty -Path $console -Name VirtualTerminalLevel -Value 1 -Type DWord
        }
    }
}
