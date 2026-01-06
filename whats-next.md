# What's Next - NixOS Dotfiles Project Handoff

<original_task>
Multi-host NixOS dotfiles repository with sops-nix secrets management, declarative Syncthing, and development environment configuration.
</original_task>

<work_completed>

## Completed This Session

### sops-nix Implementation for Mischief (COMPLETE)
- Admin age key generated and backed up
- sops-nix added to flake.nix
- Mischief host age key extracted
- SSH keys encrypted in `secrets/ssh/mischief.yaml`
- Syncthing identity encrypted in `secrets/syncthing/mischief.yaml`
- `hosts/mischief/secrets.nix` created
- Secrets deployed as symlinks from `/run/secrets/`

### Fresh Text Editor (COMPLETE)
- Added `fresh.url = "github:sinelaw/fresh"` to flake inputs
- Added to home.packages
- Version: `fresh-editor-0.1.71`

### evremap Key Remapper (COMPLETE)
- Package installed system-wide
- `config/evremap/laptop.toml` - Caps Lock → Ctrl/Esc for laptops
- `config/evremap/rk-s70.toml` - Custom mappings for RK-S70 keyboard
- Host-specific service config (mischief uses laptop.toml)

## All Completed Prompts
```
prompts/completed/
├── 001-configure-niri-session.md
├── 002-install-noctalia-shell.md
├── 002-install-waybar.md
├── 003-add-brave-browser.md
├── 004-add-syncthing.md
├── 005-add-wifi-bluetooth-tui.md
├── 006-add-obsidian-wl-clipboard.md
├── 007-finish-niri-setup.md
├── 007-plan-sops-nix-secrets.md
├── 008-modularize-multi-host.md
├── 009-add-evremap.md
└── 010-add-fresh-editor.md
```

</work_completed>

<work_remaining>

## Pending Prompts
| Prompt | Description |
|--------|-------------|
| 008-plan-sops-wifi-passwords.md | Plan WiFi password management with sops-nix |

## Git Status
- **4 unpushed commits** - run `git push`

## Intrepid/Vigilant Migration (Future)

### BEFORE Wiping Arch - Backup Syncthing Identities
```bash
mkdir -p ~/nixos-migration-backup
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID' > ~/nixos-migration-backup/device-id.txt
```

### After NixOS Installation
1. Extract host age key from SSH host key
2. Update `secrets/keys/hosts/<hostname>.txt`
3. Uncomment creation rules in `secrets/.sops.yaml`
4. Generate and encrypt SSH keys
5. Encrypt backed-up Syncthing identity
6. Create `hosts/<hostname>/secrets.nix`
7. Add evremap service config (use rk-s70.toml for intrepid desktop)
8. Rebuild and verify

## Other Tasks
- Declarative Syncthing config (add device IDs to home.nix)
- Configure backups
- Configure Brave sync

</work_remaining>

<critical_context>

## Repository Structure
```
~/nixos-dotfiles/
├── flake.nix                    # Entry point (sops-nix, fresh inputs)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix    # Shared config (evremap pkg, uinput)
│   │   └── home.nix             # Shared home-manager (fresh, packages)
│   ├── mischief/                # ThinkPad X270 - sops-nix COMPLETE
│   │   ├── configuration.nix    # Imports secrets.nix, evremap laptop service
│   │   └── secrets.nix          # sops secret definitions
│   ├── intrepid/                # Desktop (AMD) - on Arch, needs migration
│   └── vigilant/                # Surface Laptop 4 - on Arch, needs migration
├── secrets/
│   ├── .sops.yaml               # sops configuration
│   ├── keys/                    # Age public keys
│   ├── ssh/mischief.yaml        # Encrypted SSH keys
│   └── syncthing/mischief.yaml  # Encrypted Syncthing identity
├── config/
│   └── evremap/
│       ├── laptop.toml          # AT Translated Set 2 keyboard (Caps→Ctrl/Esc)
│       └── rk-s70.toml          # RK-S70 custom mappings
└── prompts/
    ├── 008-plan-sops-wifi-passwords.md
    └── completed/               # 12 completed prompts
```

## Host Status
| Host | OS | sops-nix | evremap |
|------|-----|----------|---------|
| mischief | NixOS | COMPLETE | laptop.toml (Caps→Ctrl/Esc) |
| intrepid | Arch | NOT STARTED | rk-s70.toml ready |
| vigilant | Arch | NOT STARTED | laptop.toml ready |

## Key Commands
```bash
# Rebuild NixOS
sudo nixos-rebuild switch --flake .#mischief

# Restart evremap after config changes
sudo systemctl restart evremap

# Encrypt a secret (from secrets/ directory)
nix-shell -p sops --run "sops -e -i ssh/mischief.yaml"
```

</critical_context>

<current_state>

## Ready Actions
1. `git push` - 4 unpushed commits
2. `/run-prompt 008` - Plan WiFi password management
3. Declarative Syncthing config

## Mischief Status
- sops-nix: SSH + Syncthing secrets deployed
- evremap: Caps Lock → Ctrl/Esc working
- Fresh editor: Installed (v0.1.71)

</current_state>
