# Changelog

All notable changes to this project are documented here.

## Unreleased

### Added

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
