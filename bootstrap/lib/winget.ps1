# every app and tool in packages/winget.json, in winget's own export format so `winget export` on a
# set-up PC can regenerate it. winget import skips what is installed, so re-runs only add new apps

$script:PackageFile = Join-Path $script:Root 'packages\winget.json'

function Get-PackageIds {
    $json = Get-Content -Raw $script:PackageFile | ConvertFrom-Json
    return @($json.Sources | ForEach-Object { $_.Packages.PackageIdentifier })
}

function Install-WingetPackages {
    $ids = Get-PackageIds
    Write-Info "The package list has $($ids.Count) apps and tools"

    if (-not $script:PlanMode -and -not (Test-Command 'winget')) {
        throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run the bootstrap again'
    }

    # --no-upgrade leaves installed apps at their version; upgrades stay a deliberate `winget upgrade`.
    # --ignore-unavailable keeps one withdrawn package from stopping the rest
    Invoke-Step "install anything missing from $script:PackageFile with winget" {
        winget import --import-file $script:PackageFile --no-upgrade --ignore-unavailable `
            --accept-package-agreements --accept-source-agreements
    }

    # winget adds new folders to PATH for new processes only, so this run picks them up by hand
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($machine -or $user) { $env:Path = "$machine;$user" }
}
