# New PC checklist

The bootstrap does most of the work. These are the steps around it, in order.

## Before the bootstrap

1. Finish Windows setup and install every update (Settings, Windows Update), restarting as asked.
2. Make sure **App Installer** is up to date in the Microsoft Store, since it provides winget.
3. Sign in to any cloud storage you use and leave folders online-only unless needed straight away.

## The bootstrap

Follow the [Quickstart](../README.md#quickstart). Run it once with `-Plan` first to see every
action, then for real. Confirm the GitHub sign-in in the browser when asked.

## After the bootstrap

1. Open a new Windows Terminal tab so the PowerShell profile loads.
2. **Capture this PC's settings** once it is set up the way you like: in your fork of
   system-defaults, run `.\windows\defaults.ps1 -Capture` and commit `windows\defaults.tsv`. Every later PC then
   gets them from the settings stage.
3. **Git and SSH:** edit the starting `.gitconfig` for your own name and email, then create and
   register a signing key with the two commands the git stage prints.
4. **WSL2:** if the wsl stage printed an install command, run it in an administrator terminal and
   restart. Open Ubuntu from the Start menu, create the Linux user, then run linux-bootstrap with
   the commands the stage printed. linux-bootstrap's WSL2 guide covers the details.
5. **Apps that need a sign-in:** office suites, JetBrains Toolbox, chat and music apps and the like.

## Dual boot

To run Ubuntu natively next to Windows instead of (or as well as) WSL2, follow linux-bootstrap's
dual boot guide. Run this bootstrap on the Windows side first, so the BitLocker recovery key is
saved and Windows is fully set up before any partitions change.

## Keeping a PC in line

| When | Run |
| --- | --- |
| After installing an app with winget | `winget export -o packages/winget.json`, review and commit |
| Every so often | `.\bootstrap\bootstrap.ps1 -Plan` to see what has drifted |
