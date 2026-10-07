# Accessibility

This bootstrap sets up a whole Windows PC, so it decides how much of the system a person has to
find and fix by hand afterwards. It keeps runs predictable and readable. It can also carry
high-contrast colours and captured accessibility settings to every PC.

> [!NOTE]
> Some of these settings are preferences rather than requirements. Change them freely in your own
> copy. If a change would help other people too, open an issue or a pull request so I can consider
> it for everyone.

## Reading a run

- Every line starts with a word label, `[INFO]`, `[ OK ]`, `[WARN]` or `[ERROR]`, as well as a
  colour, so the state of a run reads correctly without colour and with a screen reader.
- `-Plan` lists every action first without changing anything.
- Each stage checks what is already in place, so running it again changes nothing that is already
  right.

## Settings carried over

- The settings stage applies the values captured in system-defaults: pointer size, text
  scaling, window animations, high contrast, Sticky Keys and Filter Keys among them. It writes only
  values that differ and says when one needs a sign-out to take effect.
- The configs stage gives Windows Terminal terminal-config's High Contrast schemes, switching with
  the system's light and dark setting, with bold text kept in its own colour.

## Known gaps

- system-defaults publishes no Windows values yet, so a first run carries no settings over until
  you capture your own in a fork.
- Narrator and Magnifier are left at Windows' defaults.

## Feedback wanted

If something here gets in the way, open an [issue](https://github.com/zaccesss/windows-bootstrap/issues/new/choose)
describing what happened and what would work better.

## The shared statement

> [!NOTE]
> I keep one shared accessibility statement for all my projects:
> [zaccesss/accessibility](https://github.com/zaccesss/accessibility) or on
> [my site](https://isaacadjei.me/accessibility). This file takes precedence where the two differ.
