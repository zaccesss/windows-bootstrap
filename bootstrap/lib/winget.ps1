# every app and tool in packages/winget.json, in winget's own export format so `winget export` on a
# set-up PC can regenerate it. winget import skips what is installed, so re-runs only add new apps

$script:PackageFile = Join-Path $script:Root 'packages\winget.json'

$script:AcrobatReaderId = 'Adobe.Acrobat.Reader.64-bit'

function Get-PackageIds {
    $json = Get-Content -Raw $script:PackageFile | ConvertFrom-Json
    return @($json.Sources | ForEach-Object { $_.Packages.PackageIdentifier })
}

# Acrobat Pro and the 64-bit Reader share one install, so with Pro present the Reader package would
# fight it. Reader 64-bit also registers as "Adobe Acrobat", which is fine: then nothing needs installing
function Test-AcrobatInstalled {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    if ($programFiles -and (Test-Path (Join-Path $programFiles 'Adobe\Acrobat DC\Acrobat\Acrobat.exe'))) { return $true }

    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $names = foreach ($key in $keys) {
        try { Get-ItemProperty -Path $key -ErrorAction Stop | ForEach-Object { $_.PSObject.Properties['DisplayName'].Value } } catch { $null }
    }
    return [bool]($names | Where-Object { $_ -match '^Adobe Acrobat' -and $_ -notmatch 'Reader' })
}

# a copy of the package list without the given identifiers, for winget import to read
function New-FilteredPackageFile {
    param([string[]]$Exclude, [string]$Path)

    $json = Get-Content -Raw $script:PackageFile | ConvertFrom-Json
    foreach ($source in $json.Sources) {
        $source.Packages = @($source.Packages | Where-Object { $Exclude -notcontains $_.PackageIdentifier })
    }
    $json | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding utf8
    return $Path
}

function Install-WingetPackages {
    $ids = Get-PackageIds
    Write-Info "The package list has $($ids.Count) apps and tools"

    if (-not $script:PlanMode -and -not (Test-Command 'winget')) {
        throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run the bootstrap again'
    }

    $importFile = $script:PackageFile
    if (Test-AcrobatInstalled) {
        Write-Info "Adobe Acrobat is already installed, so $script:AcrobatReaderId is left out"
        if (-not $script:PlanMode) {
            $importFile = New-FilteredPackageFile -Exclude @($script:AcrobatReaderId) -Path (Join-Path ([IO.Path]::GetTempPath()) 'windows-bootstrap-winget.json')
        }
    }

    # --no-upgrade leaves installed apps at their version; upgrades stay a deliberate `winget upgrade`.
    # --ignore-unavailable keeps one withdrawn package from stopping the rest
    Invoke-Step "install anything missing from $script:PackageFile with winget" {
        winget import --import-file $importFile --no-upgrade --ignore-unavailable `
            --accept-package-agreements --accept-source-agreements
    }

    # winget adds new folders to PATH for new processes only, so this run picks them up by hand
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($machine -or $user) { $env:Path = "$machine;$user" }
}
