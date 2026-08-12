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
### /poweron — partymasters dev chain bring-up

- New `~/.local/bin/poweron` + `/poweron` skill: makes `localhost:3000` live end-to-end — checks/starts the ssh `-L 3000` forward (`quivira-dev-tunnel.service`, new system unit, enabled at boot), then over SSH starts postgres (`docker compose up -d --wait postgres`) and the Next.js dev server (transient user unit `partymasters-dev`) on quivira, then polls until HTTP answers.
- `etc/systemd/system/quivira-dev-tunnel.service` tracked here; apply with `sudo cp` + `systemctl daemon-reload && systemctl enable` on a fresh install.
- First run surfaced two quivira-side breakages, both fixed: the whole partymasters tree (167k files) was root-owned from the root-run Claude (fixed via docker alpine `chown -R 1000:1000` — travis has docker group but no sudo over SSH), and a stale root-era `.next` cache threw `MODULE_UNPARSABLE` (fixed with `rm -rf .next`).

### Remote Claude launchers in bashrc

- `claude()` wrapper now dispatches project names to quivira over SSH: `claude partymasters` (or `pm`), `claude timewave2` (`tw2`), `claude quivira` (`q`) run `ssh -t quivira`, cd into the project (`~/Projects/partymasters`, `~/Projects/Timewave2`, or `~`), and exec quivira's own `claude` wrapper via `bash -ic` — so its skills, config, and env load natively. Extra args pass through (`claude pm -c`). Any other first argument falls through to the local claude as before. sudo on quivira prompts for the password in the remote terminal.
