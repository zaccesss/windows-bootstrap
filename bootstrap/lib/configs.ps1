# the config repositories, each cloned once and pointed at from where its tool looks. Windows has
# no cheap file links for a normal user, so each tool gets the lightest pointer it supports: a
# junction for the Neovim folder, an environment variable for ripgrep and a symbolic link (or,
# without Developer Mode, a copy) for VS Code and lazygit

# a symbolic link needs Developer Mode or administrator rights. Without them a copy is made and the
# run says so, because a copy does not follow later edits in the repository
function Set-FileLink {
    param([string]$Source, [string]$Target)

    $item = Get-Item -Force $Target -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'SymbolicLink' -and $item.Target -contains $Source) {
        Write-Info "Already linked: $Target"
        return
    }

    Invoke-Step "link $Target to $Source" {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
        if ($item) {
            $backups = Join-Path $script:StateDir 'backups'
            New-Item -ItemType Directory -Force -Path $backups | Out-Null
            Move-Item $Target (Join-Path $backups "$(Split-Path -Leaf $Target)-$(Get-Date -Format 'yyyyMMdd-HHmmss')")
        }
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item $Source $Target
            Write-Warn "Copied $Target instead of linking it; turn on Developer Mode and run again to link it"
        }
    }
}

function Set-FolderJunction {
    param([string]$Source, [string]$Target)

    $item = Get-Item -Force $Target -ErrorAction SilentlyContinue
    if ($item -and $item.Target -contains $Source) {
        Write-Info "Already linked: $Target"
        return
    }
    if ($item) {
        Write-Warn "$Target exists and is not the repository's copy; leaving it for you to check"
        return
    }
    Invoke-Step "link $Target to $Source" {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
        New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
    }
}

function Install-ConfigRepos {
    $repos = $script:ReposDir
    # the special-folder API rather than environment variables, which are not set when the plan is
    # checked on another system
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $appData = [Environment]::GetFolderPath('ApplicationData')
    Get-Repository -Repository 'neovim-config' -Target (Join-Path $repos 'neovim-config')
    Get-Repository -Repository 'cli-tools-config' -Target (Join-Path $repos 'cli-tools-config')
    Get-Repository -Repository 'vscode-config' -Target (Join-Path $repos 'vscode-config')

    Set-FolderJunction -Source (Join-Path $repos 'neovim-config\nvim') -Target (Join-Path $localAppData 'nvim')

    $codeUser = Join-Path $appData 'Code\User'
    Set-FileLink -Source (Join-Path $repos 'vscode-config\settings.json') -Target (Join-Path $codeUser 'settings.json')
    Set-FileLink -Source (Join-Path $repos 'vscode-config\keybindings\windows-linux.json') -Target (Join-Path $codeUser 'keybindings.json')
    Set-FileLink -Source (Join-Path $repos 'cli-tools-config\lazygit\config.yml') -Target (Join-Path $appData 'lazygit\config.yml')

    # Windows Terminal loads extra colour schemes from a fragment folder, so the High Contrast pair
    # arrives without touching its own settings file; only the light and dark pairing does
    Get-Repository -Repository 'terminal-config' -Target (Join-Path $repos 'terminal-config')
    $fragment = Join-Path $localAppData 'Microsoft\Windows Terminal\Fragments\HighContrast\high-contrast.json'
    Set-FileLink -Source (Join-Path $repos 'terminal-config\windows\windows-terminal\high-contrast.json') -Target $fragment
    Set-TerminalScheme -SettingsPath (Join-Path $localAppData 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')

    # ripgrep reads its config from this variable, so no file needs linking at all
    $ripgreprc = Join-Path $repos 'cli-tools-config\ripgrep\ripgreprc'
    if ([Environment]::GetEnvironmentVariable('RIPGREP_CONFIG_PATH', 'User') -eq $ripgreprc) {
        Write-Info 'ripgrep already uses the repository config'
    } else {
        Invoke-Step "set RIPGREP_CONFIG_PATH to $ripgreprc" {
            [Environment]::SetEnvironmentVariable('RIPGREP_CONFIG_PATH', $ripgreprc, 'User')
        }
    }
}

# every Windows Terminal profile follows the system with the High Contrast Dark and Light schemes,
# and bold text keeps its colour instead of switching to the softer bright row
function Set-TerminalScheme {
    param([string]$SettingsPath)

    if (-not (Test-Path $SettingsPath)) {
        Write-Warn 'Windows Terminal has no settings file yet: open it once, then run the configs stage again'
        return
    }
    # the file allows // comments, which ConvertFrom-Json in Windows PowerShell 5.1 rejects
    $text = (Get-Content -Raw $SettingsPath) -replace '(?m)^\s*//.*$', ''
    $settings = $text | ConvertFrom-Json
    if (-not $settings.profiles.PSObject.Properties['defaults']) {
        $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
    }
    $defaults = $settings.profiles.defaults
    $current = $defaults.PSObject.Properties['colorScheme']
    if ($current -and $current.Value.dark -eq 'High Contrast Dark' -and $current.Value.light -eq 'High Contrast Light') {
        Write-Info 'Windows Terminal already uses the High Contrast schemes'
        return
    }
    Invoke-Step 'set Windows Terminal to the High Contrast Dark and Light schemes' {
        $pair = [pscustomobject]@{ dark = 'High Contrast Dark'; light = 'High Contrast Light' }
        $defaults | Add-Member -Force -NotePropertyName colorScheme -NotePropertyValue $pair
        $defaults | Add-Member -Force -NotePropertyName intenseTextStyle -NotePropertyValue 'bold'
        Copy-Item $SettingsPath "$SettingsPath.backup.$((Get-Date).ToString('yyyyMMddHHmmss'))"
        $settings | ConvertTo-Json -Depth 32 | Set-Content -Path $SettingsPath -Encoding utf8
    }
}

# Windows settings live in the defaults repository beside the macOS and Linux ones, with the
# script that captures and applies them
function Set-WindowsSettings {
    $defaults = Join-Path $script:ReposDir 'system-defaults'
    Get-Repository -Repository 'system-defaults' -Target $defaults

    $defaultsScript = Join-Path $defaults 'windows\defaults.ps1'
    if ($script:PlanMode) {
        Write-Info "Would apply the captured Windows settings with $defaultsScript"
        return
    }
    & $defaultsScript
}
