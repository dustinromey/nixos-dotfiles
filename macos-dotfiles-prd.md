# PRD: macOS Host Support via nix-darwin

**Status:** Draft — awaiting decisions on Open Questions (§9)
**Owner:** Dustin
**Implementing agent:** Claude Code, working in the `nixos-dotfiles` repo
**Conventions:** Read `CLAUDE.md` first. Follow the existing modular multi-host
pattern, `nixfmt-rfc-style`, 2-space indentation, and the repo's commit style
(no AI attribution footers; `type: description`).

---

## 1. Background

The `nixos-dotfiles` repo currently manages three NixOS hosts (`mischief`,
`intrepid`, `vigilant`) through a flake with home-manager integration. Dustin
has moved his primary machines to macOS and now needs the **same kind of
declarative, multi-host management** for a Mac desktop and a Mac laptop, kept
in sync with each other.

The decision (from prior discussion) is to use **nix-darwin + home-manager**,
extending the existing flake rather than starting a separate traditional
dotfile system. nix-darwin gives the closest experience to the current NixOS
setup; Homebrew (driven declaratively by nix-darwin) backs GUI apps, since
macOS GUI builds in nixpkgs are unreliable.

## 2. Goals

- Manage two new macOS hosts from the existing flake via `darwinConfigurations`.
- Keep the desktop and laptop in sync: apps, macOS settings, dev tooling,
  Claude config.
- Reuse the cross-platform parts of the current home-manager config; cleanly
  separate the Linux-only parts so NixOS hosts are unaffected.
- Declarative GUI app management through nix-darwin's `homebrew` module.
- Declarative macOS settings, including the Ctrl/Cmd modifier swap and as many
  keyboard shortcuts as the `defaults` system allows.
- Per-device SSH keys; Claude config under version control.

## 3. Non-Goals

- Replacing the NixOS hosts or changing their behavior. NixOS rebuilds must
  continue to work unchanged.
- 100% coverage of macOS settings. Some settings have no `defaults` key and
  remain manual; this is expected and acceptable (target ~80%).
- Porting the Linux window-manager stack (niri/qtile/waybar/rofi/mako) to
  macOS. Window management on macOS is a separate decision (§9, Q10).
- Building anything as a Word/PDF deliverable — this PRD and configs are
  text/Nix for an agent and a human to consume.

## 4. Target Architecture

### 4.1 Flake changes (`flake.nix`)

1. Add input `nix-darwin`, tracking the release branch that matches the pinned
   `nixpkgs` (currently `nixos-25.05` → use the `nix-darwin-25.05` branch), with
   `inputs.nixpkgs.follows = "nixpkgs"`.
2. *(Optional, see Q3)* Add input `nix-homebrew` for a declarative Homebrew
   bootstrap.
3. Add a `mkDarwinHost` helper alongside `mkHost`, using
   `inputs.nix-darwin.lib.darwinSystem`, importing `home-manager.darwinModules.home-manager`.
4. Add a `darwinConfigurations` output with the two Mac hosts.
5. The `waystt` overlay is Linux-only — it must **not** be applied to darwin
   hosts. Scope the overlay to `nixosConfigurations` only.
6. Verify the `claude-code`, `ghostty`, and `fresh` flake inputs provide
   `aarch64-darwin` outputs. If any does not, drop it on macOS and use the
   alternative noted in the inventory (§6 / §7).

Build commands (document in `CLAUDE.md`):
- First-time bootstrap on a Mac: `nix run nix-darwin -- switch --flake .#<host>`
- Thereafter: `darwin-rebuild switch --flake .#<host>`

### 4.2 home-manager refactor

`hosts/common/home.nix` is currently heavily Linux-specific (GTK theming,
Wayland utilities, niri/qtile config symlinks). Split it so platforms share
only what is genuinely portable:

```
modules/home/
  shared.nix    # cross-platform: git, shell, dev CLI + LSPs, portable config symlinks
  linux.nix     # GTK, Wayland utils, niri/qtile/waybar/rofi/mako, Linux-only pkgs
  darwin.nix    # macOS-specific home bits
```

- NixOS host `home.nix` → imports `shared.nix` + `linux.nix`.
- Darwin host `home.nix` → imports `shared.nix` + `darwin.nix`.
- This refactor must be behavior-neutral for the NixOS hosts — verify with
  `nixos-rebuild build` (or `nix flake check`) before and after.

### 4.3 System-level layout

```
darwin/
  common.nix        # shared darwin system config (start from the darwin.nix scaffold)
  <mac-desktop>/    # per-host: hostname, host-specific casks/settings
  <mac-laptop>/
```

`hosts/common/configuration.nix` stays NixOS-only. The provided `darwin.nix`
scaffold becomes `darwin/common.nix` (generalize the username if needed).

### 4.4 Repo naming

Optional and cosmetic: the repo name `nixos-dotfiles` becomes a slight
misnomer. Renaming to `dotfiles` or `nix-dotfiles` is fine but **not blocking**
and out of scope for this PRD.

## 5. App Inventory — GUI apps → Homebrew

Every GUI application currently in the repo, with its macOS path. The agent
must **verify each cask name with `brew search`** before committing — cask
names occasionally change.

| Current (NixOS) | macOS app | Homebrew cask | Notes |
|---|---|---|---|
| `brave` | Brave | `brave-browser` | Direct equivalent. |
| `ghostty` (flake input) | Ghostty | `ghostty` | Native macOS build; prefer the cask over the Nix/flake build on darwin. |
| `zed-editor` | Zed | `zed` | Direct. Reads `~/.config/zed/` on macOS. |
| `obsidian` | Obsidian | `obsidian` | Direct. |
| `obs-studio` (`wrapOBS`) | OBS Studio | `obs` | The `obs-pipewire-audio-capture` plugin is Linux-only; macOS audio capture differs. See Q7. |
| `mpv` | mpv / IINA | `mpv` (or `iina`) | IINA is a native macOS front-end if preferred. |
| `filezilla` | FileZilla | `filezilla` | Direct. |
| `nerd-fonts.jetbrains-mono` | JetBrains Mono NF | `font-jetbrains-mono-nerd-font` | Fonts install via cask on macOS. |
| `hack-font` | Hack | `font-hack` | — |
| `services.syncthing` | Syncthing | `syncthing` | Also available as a nix-darwin service; cask is simpler. |
| `services.tailscale` | Tailscale | `tailscale` | Mac App Store build integrates with the macOS VPN UI; pick one (Q11). |

## 6. CLI / Dev Tooling → stays in Nix

These are cross-platform and should remain Nix-managed in `modules/home/shared.nix`
(`home.packages`). They build for `aarch64-darwin` and keep parity with the
Linux hosts.

- **LSPs / formatters:** `nixd`, `nil`, `nixfmt-rfc-style`, `nixpkgs-fmt`,
  `rust-analyzer`, `rustfmt`, `pyright`, `black`, `lua-language-server`,
  `stylua`, `gopls`, `gotools`, `nodePackages.typescript-language-server`,
  `nodePackages.prettier`, `nodePackages.bash-language-server`, `shfmt`,
  `nodePackages.vscode-langservers-extracted`, `sqls`, `fish-lsp`.
- **CLI tools:** `neovim`, `bat`, `ripgrep`, `jq`, `curl`, `wget`, `vim`,
  `git`, `unzip`, `unrar`, `p7zip`, `gnutar`, `gzip`, `bzip2`, `nodejs_22`,
  `python3`, `fastfetch`, `btop`, `nmap`, `sox`, `imagemagick`, `libheif`.
- **Database:** `pgcli`, `pspg`.
- **React Native / Expo:** `eas-cli`, `watchman` (both fine from Nix on darwin;
  `watchman` is also a well-maintained Homebrew formula if preferred).

Notes / caveats:

- **`gcc`** — on macOS prefer the Xcode Command Line Tools (`clang`) for native
  builds. Keep `gcc` in Nix only if a specific toolchain needs it. Add a note
  to install the Xcode CLT (`xcode-select --install`) as a bootstrap step.
- **`claude-code`** — currently from the `claude-code` overlay. Verify the
  overlay builds on `aarch64-darwin`; if not, install Claude Code on macOS via
  Homebrew or npm instead. (Confirm install method in Q4.)
- **`fresh`** (flake input) — verify darwin support; drop on macOS if unbuildable.
- **Android SDK / `jdk17`** — `androidenv` on darwin is fiddly. Prefer the
  Homebrew route (`android-commandlinetools` + `android-platform-tools`, or the
  Android Studio cask) for the Mac(s) that need React Native work. See Q8.

## 7. Linux-Only Items → drop, native, or replace (Gap Analysis)

These have no macOS build. Each row states how the gap is filled. Items marked
**native** need no replacement — macOS already provides the capability.

| Current (NixOS) | Gap on macOS | Resolution |
|---|---|---|
| `niri`, `qtile` | No macOS window manager | **Aerospace** (tiling WM, i3/sway-style, pure TOML config, no SIP changes). Decision in Q10. |
| `waybar` | No status bar | **SketchyBar** if a custom bar is wanted; otherwise the native menu bar. |
| `rofi-wayland` | No launcher | **Raycast** (also covers clipboard history, snippets, window actions). |
| `mako`, `libnotify` | No notification daemon | **Native** Notification Center. |
| `swaylock-effects` | No lock screen tool | **Native** lock screen. |
| `swayosd` | No on-screen display | **Native** OSD (or SketchyBar). |
| `swww` | No wallpaper daemon | **Native** wallpaper (scriptable via `defaults` if needed). |
| `cliphist` | No clipboard history | **Maccy** (cask) or Raycast's clipboard history. |
| `wl-clipboard`, `xclip` | No X11/Wayland clipboard | **Native** `pbcopy` / `pbpaste`. Update any scripts/aliases that call `wl-copy`/`wl-paste`. |
| `xwayland`, `xwayland-satellite`, `xorg.xhost` | n/a | **Drop.** |
| `evremap` | No evdev remapper | nix-darwin `system.keyboard` + `hidutil` (handled in `darwin.nix`). |
| `waystt` (Wayland speech-to-text) | No macOS build | macOS Dictation, or a Whisper-based macOS tool / Wispr Flow. Decide in Q6. |
| `impala` (WiFi TUI) | iwd-specific | **Native** Wi-Fi. |
| `bluetui` (Bluetooth TUI) | BlueZ-specific | **Native** Bluetooth. |
| `v4l-utils` | No Video4Linux | n/a — drop. |
| `playerctl` | No MPRIS | `nowplaying-cli` (Homebrew) if CLI media control is needed. |
| `brightnessctl` | — | **Native**; `brightness` (Homebrew) for CLI control. |
| `xfce.thunar` (+ volman, archive-plugin) | No file manager | **Finder** (native). |
| `nwg-look`, `papirus-icon-theme`, GTK theming, `dconf`, `glib` | No GTK desktop | **Native** macOS appearance / accent settings (via `system.defaults`). |
| `services.gnome-keyring` | — | **Native** macOS Keychain. |
| `programs.ydotool`, `hardware.uinput`, `programs.adb`, `virtualisation.docker` | NixOS system options | Docker → see Q9. `adb` → via Android tooling (Q8). `ydotool`/`uinput` → drop. |

### Config files

- **Keep, symlink via `xdg.configFile` (works on macOS):** `nvim`, `ghostty`,
  `zed`, `btop`, `fastfetch`. (Ghostty also reads
  `~/Library/Application Support/com.mitchellh.ghostty/config`; the
  `~/.config/ghostty/config` path works too.)
- **Exclude from darwin:** `qtile`, `niri`, `waybar`, `rofi`, `mako`, `evremap`
  config directories.
- **Review:** `obs-studio` config (different path/format on macOS — Q7).
- **`config/zed/keymap.json`** — with Ctrl/Cmd swapped at the OS level, review
  whether the Zed keymap still behaves as intended on macOS.

### `bin/` scripts

`niri-meeting-setup.sh`, `stt-toggle.sh`, `swaylock-random` are Linux/Wayland
-specific — exclude from the darwin `~/.local/bin` symlink set. `xtuple` is
obsolete (migrated to Zoho) — drop.

## 8. Per-Domain Implementation

### 8.1 Apps
Homebrew via the nix-darwin `homebrew` module. `casks` from §5 plus any
additions from Q4. `cleanup = "zap"` for true declarative state (start with
`"uninstall"` if preferred). `masApps` only if Q11 is yes.

### 8.2 macOS settings
`system.defaults` for modeled keys (Dock, Finder, trackpad, key repeat,
appearance). `system.keyboard.swapLeftCtrlAndLeftCmd` for the Ctrl/Cmd swap.
Keyboard **shortcuts** go in `system.defaults.CustomUserPreferences`
(`com.apple.symbolichotkeys`, `NSUserKeyEquivalents`) — captured with
`defaults read`, not hand-authored. Expect a logout to apply shortcut changes.
The `darwin.nix` scaffold contains the structure and the capture workflow.

### 8.3 SSH keys
Continue the repo's **per-host key** model (`docs/ssh-keys.md`) — each Mac gets
its own `ed25519` key; register both public keys with GitHub and any servers.
Two options for where a Mac's private key lives:
- **(a) Generated locally, never synced** — simplest; recommended, since Macs
  are rarely reinstalled.
- **(b) Stored encrypted via sops-nix** keyed to that Mac — reproducible across
  reinstalls; sops-nix works on darwin. More moving parts.

`~/.ssh/config` is portable — manage it via home-manager `programs.ssh` in
`modules/home/shared.nix`. Bitwarden's built-in desktop SSH agent or `bw` CLI
provisioning remain options but are not recommended over per-device keys for a
two-machine setup. Confirm in Q5.

### 8.4 Claude config
Version-control the declarative parts via the dotfiles repo (home-manager
`home.file` with `mkOutOfStoreSymlink`, matching the existing `config/`
pattern): `~/.claude/CLAUDE.md`, `settings.json`, `commands/`, `agents/`,
hooks. **Do not** version-control or sync: `settings.local.json` (per-machine),
`projects/` transcripts, `todos/`, `shell-snapshots/`, `statsig/`, and stored
credentials (machine-specific; on macOS may live in the Keychain). Syncthing
(installed as a cask) may optionally continue to sync **only** live state if
cross-machine session continuity is wanted.

### 8.5 Dev environment
Global CLI via `modules/home/shared.nix`. Per-project `flake.nix` devshells +
`nix-direnv` (add `direnv` + `programs.direnv` to the shared module). Node:
keep `nodejs_22` in Nix, or adopt `mise` for runtime-version management — Q12
covers Docker; Android tooling is Q8.

## 9. Open Questions — Dustin to answer before implementation

1. **Mac hostnames?** The NixOS hosts follow a theme (`mischief`, `intrepid`,
   `vigilant`). Pick two names for the Mac desktop and laptop.
2. **Same repo or new repo?** Recommendation: extend the existing flake. Confirm.
3. **Homebrew bootstrap:** add the `nix-homebrew` flake input for a declarative
   Homebrew install, or install Homebrew manually once per machine?
4. **Apps to add** that aren't in the NixOS repo. Candidate list to confirm or
   amend — note install method for the Anthropic apps may need verification:
   Claude Desktop, Cowork, Bitwarden, Raycast, Aerospace, a Docker runtime,
   Wispr Flow (or other dictation), Slack, Zoom, a SQL GUI (e.g. DBeaver/TablePlus),
   1Password (you said you don't use it — confirm exclude).
5. **SSH:** confirm per-device keys (recommended). If yes, option 8.3(a) or (b)?
6. **`waystt` replacement:** macOS Dictation, Wispr Flow, or another
   Whisper-based tool?
7. **OBS:** still needed on the Macs? If so, which capture sources/plugins —
   the PipeWire plugin does not exist on macOS.
8. **Android / React Native:** needed on which Mac(s)? This determines whether
   to set up the Android SDK at all, and via Homebrew vs `androidenv`.
9. **Docker runtime:** Docker Desktop, OrbStack, or Colima?
10. **Window manager:** adopt Aerospace, or stay native macOS? This decides
    whether SketchyBar / a launcher config are in scope.
11. **Mac App Store apps:** want any installed via `masApps` (requires a
    signed-in App Store and `mas`)?
12. **`homebrew.onActivation.cleanup`:** comfortable with `"zap"` (Homebrew
    removes anything not declared), or start at `"uninstall"`?

## 10. Implementation Phases

- **Phase 0 — Decisions.** Resolve §9.
- **Phase 1 — Flake plumbing.** Add `nix-darwin` (and optionally `nix-homebrew`)
  inputs, `mkDarwinHost`, `darwinConfigurations`; scope the `waystt` overlay to
  NixOS only. Bootstrap one Mac with a minimal `darwin/common.nix`.
- **Phase 2 — home-manager refactor.** Split `hosts/common/home.nix` into
  `modules/home/{shared,linux,darwin}.nix`. Verify NixOS hosts are unchanged.
- **Phase 3 — Homebrew layer.** Populate `casks` / `masApps` from §5 + Q4.
- **Phase 4 — macOS settings.** `system.defaults`, the Ctrl/Cmd swap, and
  captured keyboard shortcuts in `CustomUserPreferences`.
- **Phase 5 — SSH + secrets.** Per the §8.3 decision.
- **Phase 6 — Claude config.** Symlink declarative files; configure Syncthing
  for state only if wanted.
- **Phase 7 — Dev environment.** `direnv` + devshells; Node, Docker, Android
  per decisions.
- **Phase 8 — Second Mac.** Bring up the second host; confirm parity.

## 11. Acceptance Criteria

- `nix flake check` passes; all three NixOS hosts still build with no behavior
  change.
- `darwin-rebuild switch --flake .#<host>` succeeds on both Macs.
- GUI apps install/remove declaratively via Homebrew; an app removed from
  `casks` is gone after the next rebuild.
- Left Ctrl and Left Cmd are swapped on both Macs, verified on internal and
  external keyboards.
- At least the intended keyboard shortcuts are reproduced via
  `CustomUserPreferences` (logout-to-apply documented).
- Each Mac has its own SSH key; both public keys authenticate to GitHub.
- Claude declarative config (`CLAUDE.md`, `settings.json`, `commands/`,
  `agents/`) is symlinked from the repo on both Macs; per-machine state is not
  version-controlled.
- Per-project devshells load via direnv; the dev toolchain matches the Linux
  hosts where cross-platform.
- Desktop and laptop produce identical results from the same flake (modulo
  intentional per-host differences).
- `CLAUDE.md` updated with darwin build commands and the new module layout.
