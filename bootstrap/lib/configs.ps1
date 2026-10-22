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
    Enable-DeveloperMode
    Get-Repository -Repository 'neovim-config' -Target (Join-Path $repos 'neovim-config')
    Get-Repository -Repository 'cli-tools-config' -Target (Join-Path $repos 'cli-tools-config')
    Get-Repository -Repository 'vscode-config' -Target (Join-Path $repos 'vscode-config')

    Set-FolderJunction -Source (Join-Path $repos 'neovim-config\nvim') -Target (Join-Path $localAppData 'nvim')

    $codeUser = Join-Path $appData 'Code\User'
    Set-FileLink -Source (Join-Path $repos 'vscode-config\settings.json') -Target (Join-Path $codeUser 'settings.json')
    Set-FileLink -Source (Join-Path $repos 'vscode-config\keybindings\windows-linux.json') -Target (Join-Path $codeUser 'keybindings.json')
    Set-FileLink -Source (Join-Path $repos 'cli-tools-config\lazygit\config.yml') -Target (Join-Path $appData 'lazygit\config.yml')

    # Windows Terminal loads extra colour schemes from a fragment folder, so the eight Zacess schemes
    # arrive without touching its own settings file; only the default scheme is set there
    Get-Repository -Repository 'terminal-config' -Target (Join-Path $repos 'terminal-config')
    $fragments = Join-Path $localAppData 'Microsoft\Windows Terminal\Fragments'
    # the earlier High Contrast fragment points at a file terminal-config no longer has, which
    # Windows Terminal reports as an error, so its link goes
    $oldFragment = Join-Path $fragments 'HighContrast\high-contrast.json'
    if ((Test-Path $oldFragment) -or (Get-Item $oldFragment -ErrorAction SilentlyContinue)) {
        Invoke-Step "remove the earlier High Contrast fragment $oldFragment" { Remove-Item -Force $oldFragment }
    }
    Set-FileLink -Source (Join-Path $repos 'terminal-config\windows\windows-terminal\zacess.json') -Target (Join-Path $fragments 'Zacess\zacess.json')
    Install-GeistMonoFont
    Install-GeistMonoFontAllUsers
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

# Geist Mono has no winget package, so its Nerd Font build comes from a pinned Nerd Fonts release
# checked against the digest GitHub publishes for it. It is installed for this user only (no
# administrator rights) and each file is registered under HKCU so it survives a restart
$script:TerminalFont = 'GeistMono Nerd Font'
$script:GeistMonoZip = @{
    Url    = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/GeistMono.zip'
    Sha256 = '4799A6C340F3993CEA7F59C256C723AFB3E70233471EA9042D92F153B87EF83E'
}

function Install-GeistMonoFont {
    param(
        [string]$FontDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\Fonts'),
        [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )

    # the editors' own terminals use the Mono build, whose icons fill one cell, so a machine that
    # only has the first build gets the download again
    $installed = @(@('GeistMonoNerdFont-Regular.otf', 'GeistMonoNerdFontMono-Regular.otf') |
        Where-Object { Test-Path -LiteralPath (Join-Path $FontDir $_) })
    if ($installed.Count -eq 2) {
        Write-Info 'Geist Mono Nerd Font is already installed'
        return
    }
    if ($script:PlanMode) {
        Write-Info "Would install Geist Mono Nerd Font from $($script:GeistMonoZip.Url)"
        return
    }
    $work = Join-Path ([IO.Path]::GetTempPath()) "geistmono-$PID"
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        $zip = Join-Path $work 'GeistMono.zip'
        Invoke-WebRequest -Uri $script:GeistMonoZip.Url -OutFile $zip -UseBasicParsing
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $script:GeistMonoZip.Sha256) {
            Write-Warn 'The Geist Mono download does not match its pinned checksum, so it was not installed'
            return
        }
        Expand-Archive -LiteralPath $zip -DestinationPath $work -Force
        New-Item -ItemType Directory -Force -Path $FontDir | Out-Null
        if (-not (Test-Path $RegistryKey)) { New-Item -Path $RegistryKey -Force | Out-Null }
        $files = @(Get-ChildItem -LiteralPath $work -Filter 'GeistMonoNerdFont*.otf' |
            Where-Object { $_.Name -notlike 'GeistMonoNerdFontPropo-*' })
        foreach ($file in $files) {
            $target = Join-Path $FontDir $file.Name
            # a font Windows has loaded is locked, so one already installed is left in place
            if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $file.FullName -Destination $target }
            Set-ItemProperty -Path $RegistryKey -Name "$($file.BaseName) (OpenType)" -Value $target
        }
        Write-Ok "Installed Geist Mono Nerd Font ($($files.Count) styles) for this user"
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Java, which the JetBrains IDEs run on, only lists fonts installed for every user, so a per-user
# copy leaves those IDEs on a fallback font. The per-user files are copied into the machine font
# folder and registered under HKLM, which needs one elevation through a UAC prompt; declining it
# only means the JetBrains IDEs keep their fallback font
function Install-GeistMonoFontAllUsers {
    param(
        [string]$SourceDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\Fonts'),
        [string]$FontDir = (Join-Path $env:WINDIR 'Fonts'),
        [string]$RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        [switch]$NoElevation
    )

    $installed = @(@('GeistMonoNerdFont-Regular.otf', 'GeistMonoNerdFontMono-Regular.otf') |
        Where-Object { Test-Path -LiteralPath (Join-Path $FontDir $_) })
    if ($installed.Count -eq 2) {
        Write-Info 'Geist Mono Nerd Font is already installed for all users'
        return
    }
    if ($script:PlanMode) {
        Write-Info 'Would install Geist Mono Nerd Font for all users so the JetBrains IDEs can use it'
        return
    }
    $files = @(Get-ChildItem -LiteralPath $SourceDir -Filter 'GeistMonoNerdFont*.otf' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'GeistMonoNerdFontPropo-*' } | ForEach-Object { $_.FullName })
    if ($files.Count -eq 0) {
        Write-Warn 'Geist Mono Nerd Font is not installed for this user yet, so it cannot be installed for all users'
        return
    }
    $copy = {
        param([string[]]$Files, [string]$FontDir, [string]$RegistryKey)
        if (-not (Test-Path $RegistryKey)) { New-Item -Path $RegistryKey -Force | Out-Null }
        foreach ($file in $Files) {
            $name = Split-Path -Leaf $file
            $target = Join-Path $FontDir $name
            if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $file -Destination $target }
            # a machine-wide font is registered by its file name alone, relative to the Fonts folder
            Set-ItemProperty -Path $RegistryKey -Name "$([IO.Path]::GetFileNameWithoutExtension($name)) (OpenType)" -Value $name
        }
    }
    if ($NoElevation -or (Test-IsAdministrator)) {
        & $copy $files $FontDir $RegistryKey
        Write-Ok "Installed Geist Mono Nerd Font ($($files.Count) styles) for all users"
        return
    }
    $list = ($files | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
    $command = "& { $copy } @($list) '$FontDir' '$RegistryKey'"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    try {
        Start-Process pwsh -ArgumentList '-NoProfile', '-EncodedCommand', $encoded -Verb RunAs -Wait -WindowStyle Hidden
        Write-Ok "Installed Geist Mono Nerd Font ($($files.Count) styles) for all users"
    } catch {
        Write-Warn 'Geist Mono Nerd Font was not installed for all users; the JetBrains IDEs keep a fallback font until the configs stage runs again'
    }
}

# every Windows Terminal profile uses Zacess Deep Contrast Dark and bold text keeps its colour instead
# of switching to the bright row. A Zacess scheme already chosen (one name or a dark and light pair,
# set by zt for example) is kept. The window's own theme follows the system, so a light scheme is
# never framed by a dark window
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
    $named = if (-not $current) { $null } elseif ($current.Value -is [string]) { $current.Value } else { $current.Value.dark }
    $theme = $settings.PSObject.Properties['theme']
    $bold = $defaults.PSObject.Properties['intenseTextStyle']
    $font = $defaults.PSObject.Properties['font']
    $face = if ($font -and $font.Value.PSObject.Properties['face']) { $font.Value.face } else { $null }
    if ($named -is [string] -and $named.StartsWith('Zacess ') -and $theme -and $theme.Value -eq 'system' -and $bold -and $bold.Value -eq 'bold' -and $face -eq $script:TerminalFont) {
        Write-Info 'Windows Terminal already uses a Zacess scheme'
        return
    }
    Invoke-Step 'set Windows Terminal to the Zacess Deep Contrast Dark scheme and Geist Mono' {
        $settings | Add-Member -Force -NotePropertyName theme -NotePropertyValue 'system'
        if (-not ($named -is [string] -and $named.StartsWith('Zacess '))) {
            $defaults | Add-Member -Force -NotePropertyName colorScheme -NotePropertyValue 'Zacess Deep Contrast Dark'
        }
        $defaults | Add-Member -Force -NotePropertyName intenseTextStyle -NotePropertyValue 'bold'
        # the prompt's Nerd Font symbols need the Geist Mono Nerd Font build installed above
        if (-not $font) { $defaults | Add-Member -Force -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
        $defaults.font | Add-Member -Force -NotePropertyName face -NotePropertyValue $script:TerminalFont
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

# File Explorer hides an item only by its Hidden attribute, never by a leading dot, so the dot
# folders and files in the home folder are marked the way macOS and Linux treat them. Tools ignore
# the attribute; only Get-ChildItem without -Force leaves them out
function Hide-HomeDotItems {
    param([string]$HomePath = $HOME)

    $shown = @(Get-ChildItem -LiteralPath $HomePath -Force |
            Where-Object { $_.Name.StartsWith('.') -and -not ($_.Attributes -band [IO.FileAttributes]::Hidden) })
    if ($shown.Count -eq 0) {
        Write-Info 'Every dot folder and file in the home folder is already hidden'
        return
    }
    if ($script:PlanMode) {
        Write-Info "Would hide $($shown.Count) dot items in the home folder: $($shown.Name -join ', ')"
        return
    }
    foreach ($item in $shown) { $item.Attributes = $item.Attributes -bor [IO.FileAttributes]::Hidden }
    Write-Ok "Hid $($shown.Count) dot items in the home folder"
}
