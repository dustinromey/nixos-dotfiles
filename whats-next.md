# What's Next - NixOS Dotfiles Project Handoff

<original_task>
Set up sops-nix secrets management for a multi-host NixOS dotfiles repository, including:
1. Per-host SSH key generation and encrypted storage
2. Declarative Syncthing configuration with preserved device identities from existing Arch Linux hosts
3. Complete workflow documentation for encrypting, storing, and deploying secrets across 3 hosts (mischief, intrepid, vigilant)
</original_task>

<work_completed>

## This Session - sops-nix Implementation for Mischief (COMPLETE)

### Step 1: Admin Age Key
- Key already existed at `~/.config/sops/age/keys.txt` from previous setup
- Public key: `age10dggc9ndceshqs7zhljzjn72zch3ft9z3p0ynzfdvt5hd03l7pesvm3yp8`
- Saved to `secrets/keys/users/admin.txt`
- User confirmed backup of private key

### Step 2: Add sops-nix to flake.nix
- Added input: `sops-nix.url = "github:Mic92/sops-nix"`
- Added `inputs.sops-nix.nixosModules.sops` to mkHost function
- Ran `nix flake update sops-nix`
- `nix flake check` passed

### Step 3: Extract Host Age Key
- User ran: `sudo ssh-keygen -A` (SSH host keys didn't exist initially)
- Extracted mischief key: `age1pldnhgr34hn375eufrrzlsv69qzwzjea3qhszlqkf73au0ruzflqp9yl9l`
- Saved to `secrets/keys/hosts/mischief.txt`
- Created placeholder files for `intrepid.txt` and `vigilant.txt`

### Step 4: Create .sops.yaml
- Created `secrets/.sops.yaml` with:
  - Admin key anchor (`&admin`)
  - Mischief host key anchor (`&mischief`)
  - Creation rules for `ssh/mischief.yaml` and `syncthing/mischief.yaml`
  - Commented placeholders for intrepid/vigilant (to enable after migration)

### Step 5: Generate and Encrypt SSH Keys
- Generated new ed25519 SSH key: `ssh-keygen -t ed25519 -C "dustin@mischief" -f /tmp/mischief_ed25519 -N ""`
- Created plaintext YAML with keys
- Encrypted with: `sops -e -i ssh/mischief.yaml` (from secrets/ directory)
- Verified decryption works
- Cleaned up temp files
- Public key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6CDl/4A3Ih/ayQSp8JhABwQ7X8LsNUSwf36ES54m8J dustin@mischief`

### Step 6: Encrypt Syncthing Identity
- Found existing identity at `~/.local/state/syncthing/` (key.pem, cert.pem)
- Created `secrets/syncthing/mischief.yaml` with both files as YAML multiline strings
- Encrypted with sops
- Verified decryption works

### Step 7: Create secrets.nix for Mischief
- Created `hosts/mischief/secrets.nix`:
  - sops configuration with age key from SSH host key
  - Secrets definitions for ssh_private_key, ssh_public_key, syncthing_key, syncthing_cert
  - Proper paths, ownership (dustin:users), and permissions (0600/0644)
  - systemd.tmpfiles.rules for directory creation
- Updated `hosts/mischief/configuration.nix` to import `./secrets.nix`

### Step 8: Test Rebuild
- `nix flake check` passed (after git adding new files)
- User ran `sudo nixos-rebuild switch --flake .#mischief` - SUCCESS
- Verified secrets deployed as symlinks:
  - `~/.ssh/id_ed25519` → `/run/secrets/ssh_private_key`
  - `~/.ssh/id_ed25519.pub` → `/run/secrets/ssh_public_key`
  - `~/.local/state/syncthing/key.pem` → `/run/secrets/syncthing_key`
  - `~/.local/state/syncthing/cert.pem` → `/run/secrets/syncthing_cert`

### Files Created/Modified This Session
```
secrets/
├── .sops.yaml                    # CREATED - sops configuration
├── keys/
│   ├── hosts/
│   │   ├── mischief.txt          # CREATED - host age public key
│   │   ├── intrepid.txt          # CREATED - placeholder
│   │   └── vigilant.txt          # CREATED - placeholder
│   └── users/
│       └── admin.txt             # CREATED - admin age public key
├── ssh/
│   └── mischief.yaml             # CREATED - encrypted SSH keys
└── syncthing/
    └── mischief.yaml             # CREATED - encrypted Syncthing identity

hosts/mischief/
├── configuration.nix             # MODIFIED - added ./secrets.nix import
└── secrets.nix                   # CREATED - sops-nix secret definitions
```

### Previous Sessions
- **Implementation Plan**: `plans/007-sops-nix-secrets-plan.md` (1356 lines)
- **Documentation Files**:
  - `docs/sops-secrets.md` - sops-nix workflow
  - `docs/ssh-keys.md` - SSH key lifecycle
  - `docs/syncthing.md` - Syncthing management
- **Prompts Created**:
  - `prompts/009-add-evremap.md` - evremap key remapper
  - `prompts/010-add-fresh-editor.md` - Fresh text editor

</work_completed>

<work_remaining>

## Mischief Post-Setup
1. **Add SSH public key to GitHub/GitLab** (if using this key for git operations)
   - Key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6CDl/4A3Ih/ayQSp8JhABwQ7X8LsNUSwf36ES54m8J dustin@mischief`

2. **Commit sops-nix changes to git**:
   ```bash
   cd ~/nixos-dotfiles
   git add secrets/ hosts/mischief/secrets.nix hosts/mischief/configuration.nix
   git commit -m "Add sops-nix secrets management for mischief"
   git push
   ```

## Intrepid/Vigilant Migration (Steps 11-13 from plan)

### BEFORE Wiping Arch - Backup Syncthing Identities
```bash
# On intrepid and vigilant (while still on Arch):
mkdir -p ~/nixos-migration-backup
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID' > ~/nixos-migration-backup/device-id.txt
```

### After NixOS Installation on Each Host
1. Extract host age key:
   ```bash
   sudo ssh-keygen -A
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub | nix-shell -p ssh-to-age --run ssh-to-age
   ```
2. Update `secrets/keys/hosts/<hostname>.txt` with the age public key
3. Uncomment creation rules in `secrets/.sops.yaml`
4. Generate and encrypt SSH keys (same as Step 5)
5. Encrypt backed-up Syncthing identity
6. Create `hosts/<hostname>/secrets.nix` (copy from mischief, adjust paths)
7. Update `hosts/<hostname>/configuration.nix` to import secrets.nix
8. Rebuild and verify

## Declarative Syncthing Configuration (Step 8 from plan)
- Update `hosts/common/home.nix` with Syncthing device declarations
- Add mischief's device ID to the shared config
- Create per-host home.nix overrides for folder device lists

## Prompts Ready to Run
| Prompt | Description | Command |
|--------|-------------|---------|
| 009 | Add evremap key remapper | `/run-prompt 009` |
| 010 | Add Fresh text editor | `/run-prompt 010` |

## Other Pending Items
- Configure backups
- Configure Brave sync
- `prompts/008-plan-sops-wifi-passwords.md` - WiFi password management

</work_remaining>

<attempted_approaches>

## Successful Approaches
1. **sops path_regex matching**: Initially tried encrypting from /tmp/ but sops couldn't match the path. Fixed by copying plaintext to correct path first (`secrets/ssh/mischief.yaml`), then encrypting in-place with `sops -e -i`.

2. **nix-shell for tools**: Used `nix-shell -p sops` and `nix-shell -p ssh-to-age` since these aren't installed globally.

3. **Git staging for flake check**: `nix flake check` couldn't find new files until they were `git add`ed (flakes use git tree, not filesystem).

## Errors Encountered and Fixes
1. **age-keygen "file exists"** - Key already existed from previous setup; used existing key.

2. **SSH host key doesn't exist** - `/etc/ssh/ssh_host_ed25519_key.pub: No such file or directory`
   - Fixed with: `sudo ssh-keygen -A`

3. **sops "no matching creation rules found"** - path_regex `ssh/mischief\.yaml$` didn't match `/tmp/mischief-ssh.yaml`
   - Fixed by: Copy to correct path first, then encrypt in-place

4. **sops command not found** - Not installed globally
   - Fixed with: `nix-shell -p sops --run "sops -e -i file.yaml"`

</attempted_approaches>

<critical_context>

## Repository Structure
```
~/nixos-dotfiles/
├── flake.nix                    # Entry point (now includes sops-nix input)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix    # Shared NixOS config
│   │   └── home.nix             # Shared home-manager config
│   ├── mischief/                # ThinkPad X270 (Intel) - sops-nix COMPLETE
│   │   ├── configuration.nix    # Imports secrets.nix
│   │   ├── secrets.nix          # sops secret definitions
│   │   └── hardware-configuration.nix
│   ├── intrepid/                # Desktop (AMD) - on Arch, needs migration
│   └── vigilant/                # Surface Laptop 4 (AMD) - on Arch, needs migration
├── secrets/
│   ├── .sops.yaml               # sops configuration
│   ├── keys/hosts/              # Age public keys per host
│   ├── keys/users/              # Admin age public key
│   ├── ssh/                     # Encrypted SSH keys
│   └── syncthing/               # Encrypted Syncthing identities
├── config/                      # App configs symlinked to ~/.config/
├── plans/
│   └── 007-sops-nix-secrets-plan.md
├── docs/
│   ├── sops-secrets.md
│   ├── ssh-keys.md
│   └── syncthing.md
└── prompts/
```

## Key Technical Details

### sops-nix Secret Deployment
- Secrets decrypted at boot by sops-nix
- Stored in `/run/secrets/` (tmpfs, not persisted)
- Symlinked to final destinations (~/.ssh/, ~/.local/state/syncthing/)
- Age key derived from SSH host key (`/etc/ssh/ssh_host_ed25519_key`)

### Age Keys
| Key | Public Key | Location |
|-----|------------|----------|
| Admin | age10dggc9ndceshqs7zhljzjn72zch3ft9z3p0ynzfdvt5hd03l7pesvm3yp8 | ~/.config/sops/age/keys.txt (private) |
| Mischief | age1pldnhgr34hn375eufrrzlsv69qzwzjea3qhszlqkf73au0ruzflqp9yl9l | /var/lib/sops-nix/key.txt (auto-generated) |

### Host Status
| Host | OS | sops-nix | Notes |
|------|-----|----------|-------|
| mischief | NixOS | COMPLETE | SSH + Syncthing secrets deployed |
| intrepid | Arch | NOT STARTED | Backup Syncthing identity before migration |
| vigilant | Arch | NOT STARTED | Backup Syncthing identity before migration |

### Commands Reference
```bash
# Rebuild NixOS
sudo nixos-rebuild switch --flake .#mischief

# Encrypt a secret file (from secrets/ directory)
nix-shell -p sops --run "sops -e -i ssh/mischief.yaml"

# Decrypt and view
nix-shell -p sops --run "sops -d ssh/mischief.yaml"

# Extract age key from SSH host key
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | nix-shell -p ssh-to-age --run ssh-to-age
```

### validateSopsFiles Setting
Set to `false` in secrets.nix because validation can fail during initial builds. Can set to `true` after confirming everything works.

</critical_context>

<current_state>

## Deliverable Status

| Item | Status | Notes |
|------|--------|-------|
| sops-nix plan | COMPLETE | `plans/007-sops-nix-secrets-plan.md` |
| Documentation | COMPLETE | `docs/sops-secrets.md`, `ssh-keys.md`, `syncthing.md` |
| **Mischief sops-nix** | **COMPLETE** | SSH + Syncthing secrets deployed and working |
| Intrepid sops-nix | NOT STARTED | Waiting for NixOS migration |
| Vigilant sops-nix | NOT STARTED | Waiting for NixOS migration |
| Declarative Syncthing | NOT STARTED | Device ID config in home.nix |
| Prompt 009 (evremap) | SAVED | Ready to run with `/run-prompt 009` |
| Prompt 010 (Fresh) | SAVED | Ready to run with `/run-prompt 010` |

## Git Status
- New files staged (`git add` was run for flake check)
- **Not yet committed** - run:
  ```bash
  git commit -m "Add sops-nix secrets management for mischief"
  git push
  ```

## Secrets Deployment Verified
```
~/.ssh/id_ed25519 → /run/secrets/ssh_private_key (0600)
~/.ssh/id_ed25519.pub → /run/secrets/ssh_public_key (0644)
~/.local/state/syncthing/key.pem → /run/secrets/syncthing_key (0600)
~/.local/state/syncthing/cert.pem → /run/secrets/syncthing_cert (0644)
```

## Ready Actions
1. **Commit and push** sops-nix changes
2. **Add SSH key to GitHub** if needed for git operations
3. Run `/run-prompt 009` to add evremap
4. Run `/run-prompt 010` to add Fresh editor
5. **Before intrepid/vigilant migration**: Backup Syncthing identities on Arch

## Critical Reminder
**BEFORE migrating intrepid/vigilant to NixOS**: Backup Syncthing identities!
```bash
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/
```

</current_state>
