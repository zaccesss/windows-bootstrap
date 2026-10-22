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

# the package ids one PC leaves out, from packages\skip\<computer name>.txt: one id per line, with #
# starting a comment. A PC with no file leaves nothing out
function Get-MachineSkipList {
    param(
        [string]$ComputerName = $env:COMPUTERNAME,
        [string]$SkipDir = (Join-Path $script:Root 'packages\skip')
    )

    $file = Join-Path $SkipDir "$ComputerName.txt"
    if (-not $ComputerName -or -not (Test-Path $file)) { return @() }
    return @(Get-Content $file | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ })
}

function Install-WingetPackages {
    param([string[]]$SkipPackage = @())

    $ids = Get-PackageIds
    Write-Info "The package list has $($ids.Count) apps and tools"

    if (-not $script:PlanMode -and -not (Test-Command 'winget')) {
        throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run the bootstrap again'
    }

    $exclude = @(Get-MachineSkipList) + @($SkipPackage | Where-Object { $_ })
    if ($exclude) { Write-Info "Left out on $($env:COMPUTERNAME): $($exclude -join ', ')" }
    if (Test-AcrobatInstalled) {
        Write-Info "Adobe Acrobat is already installed, so $script:AcrobatReaderId is left out"
        $exclude += $script:AcrobatReaderId
    }

    $importFile = $script:PackageFile
    if ($exclude -and -not $script:PlanMode) {
        $importFile = New-FilteredPackageFile -Exclude $exclude -Path (Join-Path ([IO.Path]::GetTempPath()) 'windows-bootstrap-winget.json')
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

    Install-PythonRuntime
}

# Python comes from the Python Install Manager (from the package list), so a new version is a new
# tag here rather than a new winget package. the default is pinned so a later install never takes
# over on its own. the manager's shortcuts go first on the user PATH so python and python3 reach
# it ahead of any other copy there. an older python.org install stays and answers to py -V:<version>
$script:PythonTag = '3.15'
$script:PythonShortcuts = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Python\bin'

function Install-PythonRuntime {
    if (-not $script:PlanMode -and -not (Test-Command 'pymanager')) {
        Write-Warn 'The Python Install Manager is not on PATH yet; open a new terminal and run the bootstrap again for Python'
        return
    }
    if ((Test-Command 'pymanager') -and (pymanager list --one $script:PythonTag -f exe)) {
        Write-Info "Python $script:PythonTag is already installed"
    } else {
        Invoke-Step "install Python $script:PythonTag with the Python Install Manager" { pymanager install -y $script:PythonTag }
    }
    if ([Environment]::GetEnvironmentVariable('PYTHON_MANAGER_DEFAULT', 'User') -ne $script:PythonTag) {
        Invoke-Step "make Python $script:PythonTag the default" {
            [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT', $script:PythonTag, 'User')
            $env:PYTHON_MANAGER_DEFAULT = $script:PythonTag
        }
    }
    $userPath = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
    if ($userPath[0] -ne $script:PythonShortcuts) {
        Invoke-Step "put $script:PythonShortcuts first on the user PATH" {
            $rest = $userPath | Where-Object { $_ -ne $script:PythonShortcuts }
            [Environment]::SetEnvironmentVariable('Path', (@($script:PythonShortcuts) + $rest) -join ';', 'User')
        }
    }
    # the machine PATH comes before the user's. changing it needs an administrator
    $older = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ -match '\\Python3\d+\\(Scripts\\?)?$' } | Select-Object -Unique)
    if ($older) {
        Write-Warn "An older Python on the machine PATH comes before $script:PythonTag. Remove $($older -join ' and ') from it in System Properties"
    }
    # a python.org installer's launcher sits in the Windows folder and answers to py ahead of the manager
    if (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'py.exe')) {
        Write-Warn 'The older Python Launcher still answers to py. Remove it with: winget uninstall --id Python.Launcher --exact'
    }
}
