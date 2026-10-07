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
