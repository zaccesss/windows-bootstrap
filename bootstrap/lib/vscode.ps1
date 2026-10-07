# VS Code extensions from the editor config repository. The list pins versions (name@1.2.3) for the
# record, but only missing extensions are installed and always at their latest version: installing
# the pinned one would roll an up-to-date extension back

function Get-WantedExtensions {
    param([string]$ListPath)

    return @(Get-Content $ListPath |
        Where-Object { $_ -and $_ -notmatch '^\s*(//|#)' } |
        ForEach-Object { ($_ -split '@')[0].Trim().ToLowerInvariant() } |
        Where-Object { $_ })
}

function Install-VSCodeExtensions {
    $repo = Join-Path $script:ReposDir 'vscode-config'
    Get-Repository -Repository 'vscode-config' -Target $repo

    $list = Join-Path $repo 'extensions.txt'
    if ($script:PlanMode -and -not (Test-Path $list)) {
        Write-Info "Would install missing VS Code extensions listed in $list"
        return
    }

    if (-not (Test-Command 'code')) {
        Write-Warn 'The code command is not on PATH yet; open a new terminal after the winget stage and run the bootstrap again'
        return
    }

    $wanted = Get-WantedExtensions -ListPath $list
    $installed = @(code --list-extensions | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($wanted | Where-Object { $installed -notcontains $_ })

    if ($missing.Count -eq 0) {
        Write-Ok "All $($wanted.Count) VS Code extensions are installed"
        return
    }

    foreach ($extension in $missing) {
        Invoke-Step "install the VS Code extension $extension" { code --install-extension $extension | Out-Null }
    }
}
