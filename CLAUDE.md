# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

Multi-host dotfiles repo. Each machine's configuration lives in its own directory under `hosts/`; nothing host-specific sits at the root.

```
hosts/
  quivira/   - Arch Linux + Hyprland desktop (primary workstation)
  ilium/     - Ubuntu + KDE Plasma thin client
```

Each host directory contains that machine's tracked dotfiles (`.bashrc`, `.config/…`, etc.), its own `install.sh`, `CHANGELOG.md`, package lists, and a host-specific `CLAUDE.md` with hardware and environment details.

## Conventions

- **Never mix hosts:** a change made on one machine goes under that machine's `hosts/<name>/` tree only. Shared root files are limited to this file and `.gitignore`.
- **Symlink-based on quivira** (`~/.config/hypr`, `~/.gitconfig` point into the repo); **copy-based sync on ilium** (configs are copied in/out by the sync skill).
- **Changelog before commit:** update the host's `CHANGELOG.md` before any commit touching that host (`## YYYY-MM-DD` date headers, `### Component` sections; debugging entries include Problem / Diagnosis / Status).
- **No secrets:** never track credential stores (`.git-credentials`, `~/.config/gh/`, API keys). `.gitconfig` files are per-host and reference credential helpers by path only.
- Restore a machine with `hosts/<name>/install.sh` — each script derives its paths from its own location.
