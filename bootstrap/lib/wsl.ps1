# WSL2 with Ubuntu, ready for linux-bootstrap. Installing WSL itself needs administrator rights and
# may need a restart, so this stage explains exactly what to do next rather than guessing

$script:PreferredDistros = @('Ubuntu-26.04', 'Ubuntu-24.04')

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# wsl.exe prints UTF-16 text, which PowerShell reads with a NUL between letters; removing them makes
# the distro names comparable
function Get-WslLines {
    param([string[]]$Arguments)
    return @(wsl.exe @Arguments 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Install-Wsl {
    if ($script:PlanMode) {
        Write-Info "Would install WSL2 with the newest of $($script:PreferredDistros -join ' or ') if no Ubuntu is installed"
        return
    }

    $installed = Get-WslLines -Arguments @('--list', '--quiet')
    $existing = $installed | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1
    if ($existing) {
        Write-Ok "WSL already has $existing"
    } else {
        $online = Get-WslLines -Arguments @('--list', '--online')
        $distro = $script:PreferredDistros | Where-Object { $online -match "^$([regex]::Escape($_))\b" } | Select-Object -First 1
        if (-not $distro) {
            Write-Warn 'Neither Ubuntu 26.04 nor 24.04 is offered by wsl --list --online yet; skipping WSL'
            return
        }
        if (-not (Test-IsAdministrator)) {
            Write-Warn "Installing WSL needs an administrator terminal. Run: wsl --install -d $distro"
            return
        }
        Invoke-Step "install WSL2 with $distro" { wsl.exe --install -d $distro --no-launch }
        Write-Warn 'Restart Windows if WSL asks, then open Ubuntu from the Start menu to create the Linux user'
        $existing = $distro
    }

    Write-Info "Inside $existing, run linux-bootstrap to install the Linux tools:"
    Write-Info '  git clone https://github.com/zaccesss/linux-bootstrap.git'
    Write-Info '  ./linux-bootstrap/bootstrap/bootstrap.sh --with configs'
}
