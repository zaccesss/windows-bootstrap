# Pester tests for the parts of the bootstrap that can be checked without changing a PC: the
# package list, the extension list parsing, the pointer files and plan mode end to end.

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $lib = Join-Path $script:Root 'bootstrap\lib'
    . (Join-Path $lib 'common.ps1')
    . (Join-Path $lib 'winget.ps1')
    . (Join-Path $lib 'vscode.ps1')
    $script:PlanMode = $false
}

Describe 'package list' {
    It 'is valid winget import JSON with unique publisher.name identifiers' {
        $ids = Get-PackageIds
        $ids.Count | Should -BeGreaterThan 30
        ($ids | Sort-Object -Unique).Count | Should -Be $ids.Count
        $ids | ForEach-Object { $_ | Should -Match '^[A-Za-z0-9-]+\.[A-Za-z0-9.+-]+$' }
    }

    It 'covers the everyday tools the shell profile expects' {
        $ids = Get-PackageIds
        foreach ($id in 'Git.Git', 'GitHub.cli', 'Microsoft.PowerShell', 'Starship.Starship', 'ajeetdsouza.zoxide', 'BurntSushi.ripgrep.MSVC', 'Microsoft.VisualStudioCode') {
            $ids | Should -Contain $id
        }
    }
}

Describe 'Get-WantedExtensions' {
    It 'strips pinned versions, comments and blank lines and lowercases names' {
        $list = Join-Path $TestDrive 'extensions.txt'
        Set-Content $list @('// editors', 'EditorConfig.EditorConfig@0.16.4', '', '# notes', 'eamodio.gitlens')
        Get-WantedExtensions -ListPath $list | Should -Be @('editorconfig.editorconfig', 'eamodio.gitlens')
    }
}

Describe 'Set-PointerFile' {
    It 'writes the pointer when no file exists' {
        $path = Join-Path $TestDrive 'new\profile.ps1'
        Set-PointerFile -Path $path -Content '. "C:\dotfiles\profile.ps1"'
        Get-Content -Raw $path | Should -Match 'dotfiles'
    }

    It 'keeps a different existing file as a backup instead of overwriting it' {
        $path = Join-Path $TestDrive 'existing\profile.ps1'
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        Set-Content $path '# my own profile'
        Set-PointerFile -Path $path -Content '. "C:\dotfiles\profile.ps1"'
        (Get-ChildItem (Split-Path $path) -Filter 'profile.ps1.backup-*').Count | Should -Be 1
    }

    It 'leaves a file that already points at the dotfiles untouched' {
        $path = Join-Path $TestDrive 'same\profile.ps1'
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        Set-Content $path '. "C:\dotfiles\profile.ps1"'
        Set-PointerFile -Path $path -Content '. "C:\dotfiles\profile.ps1"'
        (Get-ChildItem (Split-Path $path)).Count | Should -Be 1
    }
}

Describe 'Resolve-SkipList' {
    It 'accepts an array and a single comma-separated string alike' {
        Resolve-SkipList -Skip @('winget', 'settings') | Should -Be @('winget', 'settings')
        Resolve-SkipList -Skip 'winget, settings' | Should -Be @('winget', 'settings')
    }

    It 'stops on an unknown stage' {
        { Resolve-SkipList -Skip 'winget,nope' } | Should -Throw '*nope*'
    }
}

Describe 'New-FilteredPackageFile' {
    It 'leaves out the given packages and keeps the rest' {
        $path = New-FilteredPackageFile -Exclude @('Adobe.Acrobat.Reader.64-bit') -Path (Join-Path $TestDrive 'winget.json')
        $ids = @((Get-Content -Raw $path | ConvertFrom-Json).Sources.Packages.PackageIdentifier)
        $ids | Should -Not -Contain 'Adobe.Acrobat.Reader.64-bit'
        $ids.Count | Should -Be ((Get-PackageIds).Count - 1)
    }
}

Describe 'Get-MachineSkipList' {
    It 'reads the ids and drops comments and blank lines' {
        $dir = Join-Path $TestDrive 'skip'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Set-Content (Join-Path $dir 'TEST-PC.txt') @('# apps this PC leaves out', 'KiCad.KiCad', '', 'Figma.Figma  # not here')
        Get-MachineSkipList -ComputerName 'TEST-PC' -SkipDir $dir | Should -Be @('KiCad.KiCad', 'Figma.Figma')
    }

    It 'returns nothing for a PC with no list' {
        Get-MachineSkipList -ComputerName 'NO-SUCH-PC' -SkipDir (Join-Path $TestDrive 'skip') | Should -BeNullOrEmpty
    }

    It 'only names packages that are in the package list' {
        $ids = Get-PackageIds
        Get-ChildItem (Join-Path $script:Root 'packages\skip') -Filter '*.txt' -ErrorAction SilentlyContinue | ForEach-Object {
            Get-MachineSkipList -ComputerName $_.BaseName | ForEach-Object { $ids | Should -Contain $_ }
        }
    }
}

Describe 'Hide-HomeDotItems' {
    BeforeAll {
        . (Join-Path $script:Root 'bootstrap\lib\configs.ps1')
    }

    It 'hides dot folders and files only; plan mode changes nothing' {
        $homePath = Join-Path $TestDrive 'dothome'
        New-Item -ItemType Directory -Force -Path (Join-Path $homePath '.config'), (Join-Path $homePath 'dev') | Out-Null
        Set-Content -Path (Join-Path $homePath '.gitconfig') -Value 'x'
        Set-Content -Path (Join-Path $homePath 'notes.txt') -Value 'x'
        $isHidden = { param($Name) [bool]((Get-Item -LiteralPath (Join-Path $homePath $Name) -Force).Attributes -band [IO.FileAttributes]::Hidden) }

        $script:PlanMode = $true
        try { Hide-HomeDotItems -HomePath $homePath 6>$null } finally { $script:PlanMode = $false }
        & $isHidden '.config' | Should -BeFalse

        Hide-HomeDotItems -HomePath $homePath 6>$null
        & $isHidden '.config' | Should -BeTrue
        & $isHidden '.gitconfig' | Should -BeTrue
        & $isHidden 'dev' | Should -BeFalse
        & $isHidden 'notes.txt' | Should -BeFalse
    }
}

Describe 'Windows Terminal schemes' {
    BeforeAll {
        . (Join-Path $script:Root 'bootstrap\lib\common.ps1')
        . (Join-Path $script:Root 'bootstrap\lib\configs.ps1')
        $script:PlanMode = $false
    }

    It 'sets Zacess Deep Contrast Dark and bold text, keeping comments out of the way' {
        $path = Join-Path $TestDrive 'settings.json'
        Set-Content $path "// generated by Windows Terminal`n{ ""profiles"": { ""defaults"": {}, ""list"": [] } }"
        Set-TerminalScheme -SettingsPath $path 6>$null
        $saved = Get-Content -Raw $path | ConvertFrom-Json
        $saved.profiles.defaults.colorScheme | Should -Be 'Zacess Deep Contrast Dark'
        $saved.profiles.defaults.intenseTextStyle | Should -Be 'bold'
        $saved.theme | Should -Be 'system'
    }

    It 'replaces the earlier High Contrast pair but keeps a Zacess choice' {
        $path = Join-Path $TestDrive 'pair.json'
        Set-Content $path '{ "theme": "system", "profiles": { "defaults": { "colorScheme": { "dark": "High Contrast Dark", "light": "High Contrast Light" } } } }'
        Set-TerminalScheme -SettingsPath $path 6>$null
        (Get-Content -Raw $path | ConvertFrom-Json).profiles.defaults.colorScheme | Should -Be 'Zacess Deep Contrast Dark'
        Set-Content $path '{ "theme": "system", "profiles": { "defaults": { "colorScheme": "Zacess Cream" } } }'
        Set-TerminalScheme -SettingsPath $path 6>$null
        (Get-Content -Raw $path | ConvertFrom-Json).profiles.defaults.colorScheme | Should -Be 'Zacess Cream'
    }

    It 'leaves a file that already uses a Zacess scheme untouched' {
        $path = Join-Path $TestDrive 'done.json'
        Set-Content $path '{ "theme": "system", "profiles": { "defaults": { "colorScheme": "Zacess Deep Contrast Dark", "intenseTextStyle": "bold" } } }'
        Set-TerminalScheme -SettingsPath $path 6>$null
        (Get-ChildItem $TestDrive -Filter 'done.json.backup*').Count | Should -Be 0
    }
}

Describe 'plan mode' {
    It 'runs every stage and changes nothing' {
        $env:WINDOWS_BOOTSTRAP_ALLOW_ANY_OS = '1'
        $env:WINDOWS_BOOTSTRAP_REPOS_DIR = Join-Path $TestDrive 'repos'
        $output = & (Join-Path $script:Root 'bootstrap\bootstrap.ps1') -Plan -Skip vscode 6>&1 | Out-String
        foreach ($stage in 'winget', 'dotfiles', 'git', 'configs', 'settings', 'wsl') {
            $output | Should -Match "Completed stage: $stage"
        }
        $output | Should -Match 'Would clone dotfiles into'
        Test-Path $env:WINDOWS_BOOTSTRAP_REPOS_DIR | Should -BeFalse
    }

    It 'skips stages given as one comma-separated string' {
        $env:WINDOWS_BOOTSTRAP_ALLOW_ANY_OS = '1'
        $env:WINDOWS_BOOTSTRAP_REPOS_DIR = Join-Path $TestDrive 'repos'
        $output = & (Join-Path $script:Root 'bootstrap\bootstrap.ps1') -Plan -Skip 'vscode,settings' 6>&1 | Out-String
        $output | Should -Match 'Skipping stage: vscode'
        $output | Should -Match 'Skipping stage: settings'
        $output | Should -Not -Match 'Completed stage: settings'
    }
}

Describe 'Command Prompt start-up' {
    BeforeAll {
        . (Join-Path $script:Root 'bootstrap\lib\common.ps1')
        . (Join-Path $script:Root 'bootstrap\lib\dotfiles.ps1')
    }

    It 'sets the start-up when there is no AutoRun yet' {
        Get-CmdAutoRunValue -Existing '' -Script 'C:\r\autorun.cmd' | Should -Be 'call "C:\r\autorun.cmd"'
    }

    It 'chains an earlier AutoRun after it rather than replacing it' {
        Get-CmdAutoRunValue -Existing 'C:\tools\init.cmd' -Script 'C:\r\autorun.cmd' |
            Should -Be 'call "C:\r\autorun.cmd" & C:\tools\init.cmd'
    }

    It 'leaves a value that already runs it alone' {
        $value = 'call "C:\r\autorun.cmd" & C:\tools\init.cmd'
        Get-CmdAutoRunValue -Existing $value -Script 'C:\r\autorun.cmd' | Should -Be $value
    }
}
