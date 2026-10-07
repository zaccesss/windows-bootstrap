# How it works

`bootstrap/bootstrap.ps1` checks the PC is running Windows 11, then runs five stages in order. Each
stage looks first and acts only where something is missing. `-Plan` prints every action it would
take and changes nothing.

## The stages

### 1. winget

`winget import` installs every package in `packages/winget.json` that is missing. Packages already
installed keep their version; upgrades stay a deliberate `winget upgrade --all`. The list is in
winget's own export format, so running `winget export -o packages/winget.json` on a PC that is set
up the right way regenerates it.

### 2. Dotfiles

- signs in to GitHub with the CLI in the browser, if not already signed in
- clones the dotfiles into `%USERPROFILE%\.dotfiles\dotfiles`
- writes a one-line PowerShell 7 profile that dot-sources `windows\Microsoft.PowerShell_profile.ps1`
  from the dotfiles, keeping any existing profile as a dated backup
- sets `STARSHIP_CONFIG` for the user to the dotfiles' `windows\starship.toml`

### 3. Git

- clones the git-config, git-hooks and ssh-config repositories
- copies git-config's `windows\gitconfig` to `%USERPROFILE%\.gitconfig` and ssh-config's
  `windows\config` to `%USERPROFILE%\.ssh\config` if they are missing, as starting points to edit
  for your own name, email, keys and hosts
- links `%USERPROFILE%\.git-hooks` to the hooks repository with a junction, which needs no
  administrator rights
- warns when there is no signing key yet and prints the two commands that create and register one

### 3b. Config repositories

Each tool gets the lightest pointer it supports, since Windows has no cheap file links for a
normal user:

| Tool | How it points at the repository |
| --- | --- |
| Neovim | `%LOCALAPPDATA%\nvim` is a junction to the Neovim repository's folder |
| VS Code settings and keybindings | A symbolic link with Developer Mode on, otherwise a copy with a warning |
| lazygit | The same, at `%APPDATA%\lazygit\config.yml` |
| ripgrep | `RIPGREP_CONFIG_PATH` points at the repository's file |

Anything replaced is moved into `%USERPROFILE%\.local\state\windows-bootstrap\backups`.

### 4. VS Code extensions

Reads `windows\extensions.txt` from the editor config repository and installs only the extensions
that are missing, always at their latest version. The pinned versions in the list are for the
record and are never installed, so nothing is rolled back.

### 4b. Settings

Clones the defaults repository and runs `windows\defaults.ps1`, which applies the registry values
captured from a set-up PC (taskbar, File Explorer, appearance, input, Storage Sense and
accessibility), writing only what differs. Until a PC has been captured the file is empty and this
changes nothing. Capture with `.\windows\defaults.ps1 -Capture` in that repository.

### 5. WSL2

If no Ubuntu is installed, installs WSL2 with the newest of Ubuntu 26.04 or 24.04 that WSL offers.
Installing WSL needs an administrator terminal, so in a normal terminal the stage prints the exact
command instead. It ends with the commands that run linux-bootstrap inside Ubuntu.

## What it never does

- uninstall or upgrade apps
- create SSH keys or sign in anywhere without a browser confirmation
- overwrite a profile written by hand (it is kept as a dated backup)

## Where things live

| What | Where |
| --- | --- |
| Apps and tools | `packages/winget.json` in this repository |
| PowerShell profile and prompt | `windows\` in the dotfiles |
| Git identity and signing | `windows\gitconfig` in the gitconfig repository |
| VS Code extensions | `windows\extensions.txt` in the editor config repository |
| Progress log | `%USERPROFILE%\.local\state\windows-bootstrap\stages.log` |
