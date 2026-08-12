# Changelog — ilium

System configuration changes and troubleshooting sessions for the Ubuntu/KDE thin client.

Format: Date-based entries with categorized changes. Complex investigations include problem context, diagnosis, and resolution status.

---

## 2026-08-11

### Initial host tree

- Created `hosts/ilium/` as part of the repo's multi-host restructure (quivira's tree moved to `hosts/quivira/` the same day).
- Tracked: shell dotfiles (`.bashrc`, `.profile`, `.gitconfig`), KDE core rc files + `kdedefaults/`, `kitty/`, `gtk-3.0/`, `gtk-4.0/`, `git/ignore`, `mimeapps.list`, `dictate/vocab.txt`, `.local/bin/dictate` and `citrix-workspace`, and `packages-manual.txt` from `apt-mark showmanual`.
- Deliberately excluded: `~/.config/dictate/config` (Groq API key), `~/.git-credentials`, `~/.config/gh/` (tokens), `kdeconnect/` (device certs), and all binaries/symlinks in `.local/bin`.
- Copy-based `install.sh` (no symlinks — KDE rewrites its rc files too often to symlink them into a repo).
- Ported the quivira `/hyprgit` skill here as `/kubugit` (`~/.claude/skills/kubugit/`), adapted for apt, KDE tracked set, and `hosts/ilium/` paths.
