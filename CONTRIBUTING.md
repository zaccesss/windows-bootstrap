# Contributing

## Workflow

All substantive changes should:

1. Start from an up-to-date `main`.
2. Have a corresponding GitHub issue.
3. Use a focused branch.
4. Use an imperative conventional commit subject.
5. Include `Closes #N` where the change resolves an issue.
6. Open a pull request with the relevant context.
7. Pass all required checks.
8. Be squash-merged.
9. Have the feature branch removed after merging.

## Requirements

- Do not commit secrets or credentials.
- Keep platform assumptions explicit.
- Prefer idempotent bootstrap operations.
- Test changes against the supported environment.
- Update `CHANGELOG.md` for every real repository change.

## The shared guide

> [!NOTE]
> I keep one shared contributing guide for all my projects, covering software, hardware,
> writing and everything in between: [zaccesss/contribute](https://github.com/zaccesss/contribute)
> or on [my site](https://isaacadjei.me/contribute). This file takes precedence where the two
> differ.
