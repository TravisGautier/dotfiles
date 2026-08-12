# CLAUDE.md — ilium

Host-specific guidance for ilium, the Ubuntu/KDE Plasma thin client. See the repo-root `CLAUDE.md` for the multi-host layout and shared conventions.

## System Overview

Ubuntu with KDE Plasma, used as a thin client (Citrix Workspace) and secondary Claude Code machine. No exotic hardware; ext4 root with **no snapshot capability** — there is no rollback story here, unlike quivira's btrfs.

## Dotfiles Architecture

This host is **copy-based**, not symlinked: KDE rewrites its rc files constantly, so live configs stay plain files and the `/kubugit` skill copies changes in and out explicitly.

- Restore with `./install.sh` (in this directory) — copies repo → system.
- Sync live changes back with the `/kubugit` skill — copies system → repo, then commits.

## Tracked Content

- Shell: `.bashrc`, `.profile`, `.gitconfig`
- `.config/`: KDE core rc files (`kdeglobals`, `kwinrc`, `kwinoutputconfig.json`, `kglobalshortcutsrc`, `kscreenlockerrc`, `konsolerc`, `ksmserverrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`, `plasmanotifyrc`, `kdedefaults/`), `kitty/`, `gtk-3.0/`, `gtk-4.0/`, `git/ignore`, `mimeapps.list`, `powermanagementprofilesrc`, `dictate/vocab.txt`
- `.local/bin/`: `dictate` (voice dictation: Meta+Space → sox → Groq Whisper → ydotool), `citrix-workspace` wrapper
- `packages-manual.txt`: `apt-mark showmanual` output

## Secrets — never track

- `~/.config/dictate/config` — holds `GROQ_API_KEY` (gitignored; recreate by hand, `chmod 600`)
- `~/.git-credentials` — per-host GitHub PAT
- `~/.config/gh/` — gh CLI OAuth token

## Key Commands

```bash
# Restore to new system
./install.sh

# Install packages
sudo apt update && xargs -a packages-manual.txt sudo apt install -y

# Update package list
apt-mark showmanual > packages-manual.txt
```

## Changelog

See `CHANGELOG.md` in this directory. **Always update it before committing** — same format as quivira's: `## YYYY-MM-DD` date headers, `### Component` sections, Problem/Diagnosis/Status for debugging entries.
