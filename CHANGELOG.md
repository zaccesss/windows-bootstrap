# Changelog

All notable changes to this project are documented here.

## Unreleased

### Changed

- The Bootstrap workflow runs on every pull request, with a quick Changes job deciding whether the Windows jobs need to run, so docs-only changes still report each check as skipped instead of leaving it missing. Tests (Windows), Package list (winget) and markdownlint are now required before merging.
- Python comes from the Python Install Manager (`Python.PythonInstallManager`) instead of the `Python.Python.3.14` package. The winget stage installs Python 3.15 with it, pins 3.15 as the default through `PYTHON_MANAGER_DEFAULT` and puts the manager's shortcuts first on the user PATH, so `python`, `python3` and `py` all start 3.15. Each part is skipped when already done. An older python.org install stays and answers to `py -V:3.14`. The stage warns when one is still on the machine PATH, since removing it needs an administrator. It also warns while the older Python Launcher still answers to `py`.

## 0.0.1 - 2026-10-22

### Added

- `-SkipPackage` leaves winget ids out of one run. `packages\skip\<computer name>.txt` leaves them out on one PC for good. Both join the Acrobat check in one filtered copy of the package list.
- The settings stage hides the dot folders and files in the home folder in File Explorer, as macOS and Linux do.
- The dotfiles stage puts the dotfiles' `windows\scripts` folder on the user `PATH` for `zt` and sets Command Prompt's `AutoRun` to the dotfiles' `windows\cmd\autorun.cmd`, chaining any earlier value after it and saving that value first. It also sets `VirtualTerminalLevel` so the console host shows ANSI colours.

### Changed

- Windows Terminal gets the eight Zacess schemes from terminal-config's `windows-terminal\zacess.json` fragment. Every profile uses Zacess Deep Contrast Dark in place of the High Contrast light and dark pair. A Zacess scheme already set is kept. The earlier High Contrast fragment link is removed.

## 2026-10-19

### Added

- The configs stage turns on Developer Mode before it links anything.
- Docs-only changes skip the Windows CI jobs.
- First public release: one PowerShell command that sets up a Windows 11 PC with the winget package list, a PowerShell 7 profile and prompt from public dotfiles, starting Git and SSH configs, the Git hooks, tool configs from public repositories, VS Code extensions, captured Windows settings and WSL2 Ubuntu. Every stage checks first. `-Plan` shows every action without changing anything.
- The High Contrast light and dark schemes for Windows Terminal.
- Pester tests and PSScriptAnalyzer checks that run on any machine with PowerShell 7.

### Changed

- The README links the bootstraps for the other platforms.

### Fixed

- `-Skip` accepts one comma-separated string, so `pwsh -File` with `-Skip winget,settings` works.
- `Adobe.Acrobat.Reader.64-bit` is left out on a PC that already has Adobe Acrobat.
- Windows Terminal's window theme follows the system along with the High Contrast schemes.
