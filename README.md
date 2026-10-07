# Windows Bootstrap

[![Bootstrap](https://github.com/zaccesss/windows-bootstrap/actions/workflows/bootstrap.yml/badge.svg)](https://github.com/zaccesss/windows-bootstrap/actions/workflows/bootstrap.yml)
[![Lint markdown files](https://github.com/zaccesss/windows-bootstrap/actions/workflows/markdownlint.yml/badge.svg)](https://github.com/zaccesss/windows-bootstrap/actions/workflows/markdownlint.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

One PowerShell command that sets up a Windows 11 PC for development and keeps it in line. It covers
every app and tool in the winget package list, the PowerShell profile and prompt from the dotfiles,
Git configuration and hooks, VS Code extensions and WSL2 Ubuntu ready for linux-bootstrap.

> [!IMPORTANT]
> This is a first version. It is tested on a Windows runner in CI and in plan mode, but has not yet
> run end to end on a real PC. Run it with `-Plan` first and report anything that goes wrong.

## Quickstart

In **Windows Terminal**, as your normal user (not administrator):

```powershell
winget install --id Git.Git --exact
git clone https://github.com/zaccesss/windows-bootstrap.git
cd windows-bootstrap
.\bootstrap\bootstrap.ps1 -Plan     # see what would happen
.\bootstrap\bootstrap.ps1           # do it
```

If PowerShell refuses to run the script, allow local scripts for your user once:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## What it does

| Stage | What happens |
| --- | --- |
| winget | Installs anything missing from `packages/winget.json` without upgrading what is already there |
| dotfiles | Signs in to GitHub, clones the dotfiles and points the PowerShell 7 profile and starship at them |
| git | Copies a starting `.gitconfig` and SSH config if missing and links the Git hooks |
| configs | Points Neovim, VS Code settings, lazygit and ripgrep at their config repositories, then gives Windows Terminal the High Contrast light and dark schemes |
| vscode | Installs missing VS Code extensions from vscode-config at their latest version |
| settings | Applies the Windows settings captured in system-defaults, writing only what differs |
| wsl | Installs WSL2 with Ubuntu 26.04 (or 24.04) and explains the linux-bootstrap step |

Leave stages out with `-Skip`, for example `-Skip wsl,vscode`.

> [!TIP]
> Turn on Developer Mode (Settings, System, For developers) before the first run. It lets the
> configs stage link VS Code and lazygit settings instead of copying them, so later edits in the
> repositories apply straight away.

## Your own configuration

The dotfiles and configs come from these public repositories:

| Repository | What it provides |
| --- | --- |
| [dotfiles](https://github.com/zaccesss/dotfiles) | The PowerShell 7 profile with aliases and helpers and the starship prompt |
| [git-config](https://github.com/zaccesss/git-config) | A starting `.gitconfig` with SSH commit signing |
| [git-hooks](https://github.com/zaccesss/git-hooks) | Secret scanning, large file and force push guards |
| [ssh-config](https://github.com/zaccesss/ssh-config) | A starting `.ssh\config` |
| [neovim-config](https://github.com/zaccesss/neovim-config) | Neovim with LSP, treesitter and Telescope |
| [cli-tools-config](https://github.com/zaccesss/cli-tools-config) | ripgrep, fzf and lazygit defaults |
| [vscode-config](https://github.com/zaccesss/vscode-config) | VS Code settings, keybindings and extensions |
| [terminal-config](https://github.com/zaccesss/terminal-config) | The High Contrast light and dark schemes for Windows Terminal |
| [system-defaults](https://github.com/zaccesss/system-defaults) | Windows settings, captured and applied |

They are cloned into `%USERPROFILE%\.dotfiles` (change it with `BOOTSTRAP_CONFIG_DIR`). `.gitconfig`
and `.ssh\config` are copied once as a starting point, because they hold your own name, email, keys
and hosts. Fork the repositories and point the bootstrap at your own account to make them yours:

```powershell
$env:BOOTSTRAP_GITHUB_USER = '<your GitHub user>'; .\bootstrap\bootstrap.ps1
```

## Documentation

| Page | What it covers |
| --- | --- |
| [How it works](docs/how-it-works.md) | Each stage in detail, what is never touched and where the lists live |
| [New PC checklist](docs/new-pc.md) | Everything to do on a new PC, including WSL2 and dual booting |
| [Accessibility](ACCESSIBILITY.md) | How a run reads and the settings it carries over |

## Development

The Pester tests and the analyzer run on any machine with PowerShell 7:

```powershell
Invoke-ScriptAnalyzer -Path ./bootstrap -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester ./tests
```

CI runs both on a Windows runner, plans a full run and checks every package still exists in the
winget catalogue. Changes follow the workflow in [CONTRIBUTING.md](CONTRIBUTING.md).

> [!IMPORTANT]
> Do not commit passwords, API keys, private keys or tokens. See [SECURITY.md](SECURITY.md).

## Licence

Apache License, Version 2.0. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

## Contact and Support

Open an [issue](https://github.com/zaccesss/windows-bootstrap/issues) for questions or bugs. See
[SUPPORT.md](SUPPORT.md) for where to go.

> [!TIP]
> Reach me directly at [contact@isaacadjei.me](mailto:contact@isaacadjei.me) or through the
> [website contact page](https://isaacadjei.me/contact).
