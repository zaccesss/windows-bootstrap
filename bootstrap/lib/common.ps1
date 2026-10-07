# shared helpers: labelled output, plan mode, the platform check and safe file linking.
# Every message carries a word label as well as a colour, so a run reads correctly without colour.

# the dotfiles and config repositories are cloned here. They default to the public ones this
# project was built alongside; set BOOTSTRAP_GITHUB_USER to your own account to use your forks
$script:ReposDir = if ($env:BOOTSTRAP_CONFIG_DIR) { $env:BOOTSTRAP_CONFIG_DIR } elseif ($env:WINDOWS_BOOTSTRAP_REPOS_DIR) { $env:WINDOWS_BOOTSTRAP_REPOS_DIR } else { Join-Path $HOME '.dotfiles' }
$script:GitHubUser = if ($env:BOOTSTRAP_GITHUB_USER) { $env:BOOTSTRAP_GITHUB_USER } else { 'zaccesss' }
$script:StateDir = Join-Path $HOME '.local\state\windows-bootstrap'

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

# runs an action for real; plan mode only describes it
function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)

    if ($script:PlanMode) {
        Write-Info "Would $Description"
        return
    }
    Write-Info ($Description.Substring(0, 1).ToUpper() + $Description.Substring(1))
    & $Action
}

function Invoke-Stage {
    param([string]$Name, [scriptblock]$Action)

    Write-Info "Running stage: $Name"
    & $Action
    if (-not $script:PlanMode) {
        New-Item -ItemType Directory -Force -Path $script:StateDir | Out-Null
        Add-Content -Path (Join-Path $script:StateDir 'stages.log') -Value "$((Get-Date).ToUniversalTime().ToString('s'))Z $Name"
    }
    Write-Ok "Completed stage: $Name"
}

# Windows 11 is build 22000 or later. winget and WSL2's current installer need it; Windows 10 is
# out of support, so the bootstrap stops rather than half-work there
function Assert-SupportedPlatform {
    $isWindowsHost = if ($null -ne (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) { $IsWindows } else { $true }
    if ($env:WINDOWS_BOOTSTRAP_ALLOW_ANY_OS -ne '1' -and -not $isWindowsHost) {
        throw 'This bootstrap is for Windows. Use mac-bootstrap on a Mac and linux-bootstrap on Linux'
    }

    if ($isWindowsHost) {
        $build = [Environment]::OSVersion.Version.Build
        if ($build -lt 22000) {
            throw "Windows build $build is too old; Windows 11 (build 22000 or later) is needed"
        }
        Write-Ok "Platform detected: Windows build $build on $env:PROCESSOR_ARCHITECTURE"
    }
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# clones one of the GitHub user's public repositories unless it is already there, so a re-run never
# touches work in progress. Plain git over HTTPS, so no GitHub sign-in is needed
function Get-Repository {
    param([string]$Repository, [string]$Target)

    if (Test-Path (Join-Path $Target '.git')) {
        Write-Info "Already cloned: $Target"
        return
    }
    Invoke-Step "clone $Repository into $Target" {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
        git clone "https://github.com/$($script:GitHubUser)/$Repository.git" $Target
    }
}

# writes a file whose whole job is to point at the real one in a repository. An existing file with
# different content is kept as a dated backup, never overwritten
function Set-PointerFile {
    param([string]$Path, [string]$Content)

    if ((Test-Path $Path) -and ((Get-Content -Raw $Path).Trim() -eq $Content.Trim())) {
        Write-Info "Already pointing at the dotfiles: $Path"
        return
    }

    Invoke-Step "point $Path at the dotfiles" {
        if (Test-Path $Path) {
            $backup = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item $Path $backup
            Write-Warn "Kept the existing file as $backup"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        Set-Content -Path $Path -Value $Content -Encoding utf8
    }
}
