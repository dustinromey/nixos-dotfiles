# Implementation Plan: sops-nix Secrets Management

## Overview

This plan integrates sops-nix into the Romey NixOS dotfiles repository to manage secrets across three hosts (mischief, intrepid, vigilant). The implementation will:

1. **Per-host SSH keys**: Each host gets unique ed25519 SSH keys (not shared) for better security isolation
2. **Syncthing identities**: Preserve existing Syncthing device IDs from Arch Linux hosts during migration
3. **Declarative secrets**: All secrets encrypted with age and stored in the repository
4. **Multi-host support**: Each host can decrypt only its own secrets

### Architecture

```
nixos-dotfiles/
├── flake.nix                    # Add sops-nix input
├── secrets/
│   ├── .sops.yaml               # sops configuration (which keys encrypt what)
│   ├── ssh/
│   │   ├── mischief.yaml        # Encrypted SSH keys for mischief
│   │   ├── intrepid.yaml        # Encrypted SSH keys for intrepid
│   │   └── vigilant.yaml        # Encrypted SSH keys for vigilant
│   ├── syncthing/
│   │   ├── mischief.yaml        # Encrypted Syncthing identity (key.pem, cert.pem)
│   │   ├── intrepid.yaml        # Encrypted Syncthing identity
│   │   └── vigilant.yaml        # Encrypted Syncthing identity
│   └── keys/
│       ├── hosts/
│       │   ├── mischief.txt     # Age public key for mischief (UNENCRYPTED)
│       │   ├── intrepid.txt     # Age public key for intrepid (UNENCRYPTED)
│       │   └── vigilant.txt     # Age public key for vigilant (UNENCRYPTED)
│       └── users/
│           └── admin.txt        # Admin age public key for emergency access (UNENCRYPTED)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix    # Import sops-nix module
│   │   └── home.nix             # Declarative Syncthing config
│   ├── mischief/
│   │   ├── configuration.nix    # sops secrets for mischief
│   │   └── secrets.nix          # NEW: sops secret definitions for mischief
│   ├── intrepid/
│   │   ├── configuration.nix    # sops secrets for intrepid
│   │   └── secrets.nix          # NEW: sops secret definitions for intrepid
│   └── vigilant/
│       ├── configuration.nix    # sops secrets for vigilant
│       └── secrets.nix          # NEW: sops secret definitions for vigilant
└── docs/
    ├── sops-secrets.md          # sops-nix workflow documentation
    ├── ssh-keys.md              # SSH key lifecycle management
    └── syncthing.md             # Syncthing management

OUTSIDE REPO (NOT CHECKED IN):
~/.config/sops/age/keys.txt      # Private age key for admin (BACKUP THIS!)
/var/lib/sops-nix/keys/         # Per-host age keys (generated on each host)
```

### Key Concepts

**Age encryption**: sops-nix uses age (modern encryption tool) instead of GPG for simplicity.

**Per-host keys**: Each host generates its own age key pair from its SSH host key. This means:
- Only that host can decrypt its secrets
- No need to manually distribute private keys
- Host compromise doesn't expose other hosts' secrets

**Admin key**: A master age key for emergency access and initial secret creation (stored securely outside repo).

**Two-tier encryption**: Secrets are encrypted to BOTH the relevant host key AND the admin key, so you can always decrypt/rotate secrets.

---

## Prerequisites

### Tools Required

1. **sops** - Secret Operations tool
   ```bash
   # Install on current system (for creating/editing secrets)
   nix-shell -p sops

   # Or install permanently
   nix-env -iA nixpkgs.sops
   ```

2. **age** - Encryption tool
   ```bash
   nix-shell -p age
   # Or install permanently
   nix-env -iA nixpkgs.age
   ```

3. **ssh-to-age** - Convert SSH keys to age format
   ```bash
   nix-shell -p ssh-to-age
   ```

### Backups to Make BEFORE Starting

**On intrepid (Arch Linux):**
```bash
# Backup Syncthing identity
mkdir -p ~/nixos-migration-backup
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/intrepid-syncthing-key.pem
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/intrepid-syncthing-cert.pem

# Note the device ID for reference
curl http://127.0.0.1:8384/rest/system/status | jq -r '.myID' > ~/nixos-migration-backup/intrepid-device-id.txt

# Backup SSH keys if any exist that you want to preserve
cp -r ~/.ssh ~/nixos-migration-backup/ssh-backup
```

**On vigilant (Arch Linux):**
```bash
# Same as above
mkdir -p ~/nixos-migration-backup
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/vigilant-syncthing-key.pem
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/vigilant-syncthing-cert.pem
curl http://127.0.0.1:8384/rest/system/status | jq -r '.myID' > ~/nixos-migration-backup/vigilant-device-id.txt
cp -r ~/.ssh ~/nixos-migration-backup/ssh-backup
```

**Copy backups to mischief (NixOS):**
```bash
# From mischief, copy over the network
scp -r dustin@intrepid:~/nixos-migration-backup ~/nixos-dotfiles/backups/intrepid/
scp -r dustin@vigilant:~/nixos-migration-backup ~/nixos-dotfiles/backups/vigilant/
```

---

## Implementation Steps

### Step 1: Generate Admin Age Key

**On mischief (or your daily driver), run:**

```bash
# Create sops config directory
mkdir -p ~/.config/sops/age

# Generate admin age key
age-keygen -o ~/.config/sops/age/keys.txt

# This will output something like:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**CRITICAL**:
- Save the **public key** that was printed to the terminal
- **BACKUP** the private key file `~/.config/sops/age/keys.txt` to a secure location (password manager, encrypted USB drive, etc.)
- If you lose this key, you cannot decrypt any secrets!

**Store the public key in the repo:**

```bash
cd ~/nixos-dotfiles
mkdir -p secrets/keys/users

# Replace with YOUR public key from the age-keygen output
echo "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > secrets/keys/users/admin.txt
```

### Step 2: Add sops-nix to flake.nix

**Edit `/home/dustin/nixos-dotfiles/flake.nix`:**

```nix
{
  description = "Romey NixOS - Multi-host configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Claude
    claude-code.url = "github:ryoppippi/claude-code-overlay";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    let
      # Helper function to create a host configuration
      mkHost = hostname: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          sops-nix.nixosModules.sops  # Add sops-nix module
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = false;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.dustin = import ./hosts/${hostname}/home.nix;
              backupFileExtension = "backup";
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        # Lenovo ThinkPad X270 - Intel i5-6300U, Intel HD 520, test machine
        mischief = mkHost "mischief" "x86_64-linux";

        # Desktop - AMD CPU/GPU, 32GB RAM, daily driver
        intrepid = mkHost "intrepid" "x86_64-linux";

        # Microsoft Surface Laptop 4 - AMD CPU/GPU, 16GB RAM
        vigilant = mkHost "vigilant" "x86_64-linux";
      };
    };
}
```

**Update flake lock:**

```bash
cd ~/nixos-dotfiles
nix flake update
```

### Step 3: Generate Host Age Keys

Each NixOS host will derive its age key from its SSH host key automatically. We need to extract the public keys to configure `.sops.yaml`.

**On mischief (currently running NixOS):**

```bash
# Extract age public key from SSH host key
sudo ssh-keygen -A  # Ensure host keys exist
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

# Output will be something like:
# age1host1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Save this to the repo
mkdir -p ~/nixos-dotfiles/secrets/keys/hosts
echo "age1host1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > ~/nixos-dotfiles/secrets/keys/hosts/mischief.txt
```

**For intrepid and vigilant (still on Arch):**

These hosts will generate their age keys after NixOS installation. For now, we'll create placeholder files and update them later.

```bash
cd ~/nixos-dotfiles/secrets/keys/hosts
touch intrepid.txt
touch vigilant.txt

# Add a comment so we know these need updating
echo "# TODO: Update after NixOS installation" > intrepid.txt
echo "# TODO: Update after NixOS installation" > vigilant.txt
```

### Step 4: Create .sops.yaml Configuration

**Create `/home/dustin/nixos-dotfiles/secrets/.sops.yaml`:**

```yaml
# sops-nix configuration
# This file defines which age keys can decrypt which secrets

# Read age public keys from files
keys:
  - &admin_key $(cat keys/users/admin.txt)
  - &mischief_key $(cat keys/hosts/mischief.txt)
  # intrepid and vigilant keys will be added after NixOS installation
  # - &intrepid_key $(cat keys/hosts/intrepid.txt)
  # - &vigilant_key $(cat keys/hosts/vigilant.txt)

creation_rules:
  # SSH keys for mischief
  - path_regex: secrets/ssh/mischief\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *mischief_key

  # Syncthing identity for mischief
  - path_regex: secrets/syncthing/mischief\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *mischief_key

  # SSH keys for intrepid (add after NixOS installation)
  # - path_regex: secrets/ssh/intrepid\.yaml$
  #   key_groups:
  #     - age:
  #         - *admin_key
  #         - *intrepid_key

  # Syncthing identity for intrepid (add after NixOS installation)
  # - path_regex: secrets/syncthing/intrepid\.yaml$
  #   key_groups:
  #     - age:
  #         - *admin_key
  #         - *intrepid_key

  # SSH keys for vigilant (add after NixOS installation)
  # - path_regex: secrets/ssh/vigilant\.yaml$
  #   key_groups:
  #     - age:
  #         - *admin_key
  #         - *vigilant_key

  # Syncthing identity for vigilant (add after NixOS installation)
  # - path_regex: secrets/syncthing/vigilant\.yaml$
  #   key_groups:
  #     - age:
  #         - *admin_key
  #         - *vigilant_key
```

### Step 5: Generate and Encrypt SSH Keys for Mischief

**Generate new SSH key for mischief:**

```bash
# Generate ed25519 key (modern, secure)
ssh-keygen -t ed25519 -C "dustin@mischief" -f /tmp/mischief_ed25519 -N ""

# This creates:
# /tmp/mischief_ed25519       (private key)
# /tmp/mischief_ed25519.pub   (public key)
```

**Create the secret file and encrypt it:**

```bash
cd ~/nixos-dotfiles/secrets

# Create directory structure
mkdir -p ssh

# Create the secret file with sops
# This will open your $EDITOR with an empty encrypted file
sops ssh/mischief.yaml
```

**In the editor, add this content (YAML format):**

```yaml
# SSH keys for mischief host
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [paste contents of /tmp/mischief_ed25519 here]
  -----END OPENSSH PRIVATE KEY-----

ssh_public_key: "ssh-ed25519 AAAA[...rest of public key...] dustin@mischief"
```

**Important**:
- The private key must be indented with 2 spaces for each line (YAML multiline string)
- Save and exit the editor
- sops will automatically encrypt the file

**Verify encryption:**

```bash
# View encrypted file (should be gibberish)
cat ssh/mischief.yaml

# Decrypt and view (should show plaintext YAML)
sops -d ssh/mischief.yaml

# Clean up temporary files
rm /tmp/mischief_ed25519 /tmp/mischief_ed25519.pub
```

### Step 6: Encrypt Syncthing Identity for Mischief

**If mischief already has Syncthing running:**

```bash
# Find existing Syncthing identity
ls ~/.local/state/syncthing/

# If key.pem and cert.pem exist, back them up
mkdir -p ~/nixos-dotfiles/backups/mischief
cp ~/.local/state/syncthing/key.pem ~/nixos-dotfiles/backups/mischief/
cp ~/.local/state/syncthing/cert.pem ~/nixos-dotfiles/backups/mischief/
```

**If mischief doesn't have Syncthing identity yet, create new keys:**

```bash
# Install syncthing temporarily to generate keys
nix-shell -p syncthing --run "syncthing generate --home=/tmp/syncthing-temp"

# This creates key.pem and cert.pem in /tmp/syncthing-temp/
cp /tmp/syncthing-temp/key.pem ~/nixos-dotfiles/backups/mischief/
cp /tmp/syncthing-temp/cert.pem ~/nixos-dotfiles/backups/mischief/
rm -rf /tmp/syncthing-temp
```

**Encrypt the Syncthing identity:**

```bash
cd ~/nixos-dotfiles/secrets

# Create directory
mkdir -p syncthing

# Create and edit encrypted file
sops syncthing/mischief.yaml
```

**In the editor, add:**

```yaml
# Syncthing identity for mischief
syncthing_key: |
  -----BEGIN EC PRIVATE KEY-----
  [paste contents of backups/mischief/key.pem here]
  -----END EC PRIVATE KEY-----

syncthing_cert: |
  -----BEGIN CERTIFICATE-----
  [paste contents of backups/mischief/cert.pem here]
  -----END CERTIFICATE-----
```

### Step 7: Configure sops-nix in Host Configuration

**Create `/home/dustin/nixos-dotfiles/hosts/mischief/secrets.nix`:**

```nix
{ config, ... }:

{
  # sops-nix configuration for mischief
  sops = {
    # Default sops file for this host
    defaultSopsFile = ../../secrets/ssh/mischief.yaml;

    # Validate sops files at build time
    validateSopsFiles = true;

    # Age key for decryption (derived from SSH host key)
    age = {
      # Use SSH host key to generate age key
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # Where to store the generated age key
      keyFile = "/var/lib/sops-nix/key.txt";
      # Generate the key if it doesn't exist
      generateKey = true;
    };

    # Define secrets to decrypt
    secrets = {
      # SSH private key
      "ssh_private_key" = {
        sopsFile = ../../secrets/ssh/mischief.yaml;
        path = "/home/dustin/.ssh/id_ed25519";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # SSH public key
      "ssh_public_key" = {
        sopsFile = ../../secrets/ssh/mischief.yaml;
        path = "/home/dustin/.ssh/id_ed25519.pub";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };

      # Syncthing private key
      "syncthing_key" = {
        sopsFile = ../../secrets/syncthing/mischief.yaml;
        path = "/home/dustin/.local/state/syncthing/key.pem";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # Syncthing certificate
      "syncthing_cert" = {
        sopsFile = ../../secrets/syncthing/mischief.yaml;
        path = "/home/dustin/.local/state/syncthing/cert.pem";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };
    };
  };

  # Ensure .ssh directory exists
  systemd.tmpfiles.rules = [
    "d /home/dustin/.ssh 0700 dustin users"
    "d /home/dustin/.local/state/syncthing 0700 dustin users"
  ];
}
```

**Update `/home/dustin/nixos-dotfiles/hosts/mischief/configuration.nix`:**

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix  # Add this line
  ];

  networking.hostName = "mischief";
}
```

### Step 8: Configure Declarative Syncthing

**Update `/home/dustin/nixos-dotfiles/hosts/common/home.nix`:**

Find the Syncthing section and replace it with:

```nix
  # Syncthing - continuous file synchronization
  services.syncthing = {
    enable = true;

    # Syncthing settings (declarative configuration)
    settings = {
      # Devices (other Syncthing instances)
      devices = {
        # Device IDs will be different for each host
        # These are placeholders - update with actual device IDs
        "intrepid" = {
          id = "INTREPID-DEVICE-ID-HERE";  # Update after intrepid NixOS install
          addresses = [ "dynamic" ];
        };
        "vigilant" = {
          id = "VIGILANT-DEVICE-ID-HERE";  # Update after vigilant NixOS install
          addresses = [ "dynamic" ];
        };
        # Add mischief's device ID after rebuild (get from web UI)
      };

      # Folders to sync
      folders = {
        # ~/Sync folder
        "sync" = {
          path = "/home/dustin/Sync";
          devices = [ "intrepid" "vigilant" ];
          ignorePerms = false;
        };

        # ~/Code folder
        "code" = {
          path = "/home/dustin/Code";
          devices = [ "intrepid" "vigilant" ];
          ignorePerms = false;
        };
      };

      # General options
      options = {
        urAccepted = -1;  # Disable usage reporting
        localAnnounceEnabled = true;
        globalAnnounceEnabled = true;
      };
    };
  };
```

**Create host-specific overrides for device lists:**

**Create `/home/dustin/nixos-dotfiles/hosts/mischief/home.nix`:**

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [ ../common/home.nix ];

  # Override Syncthing to exclude mischief from its own device list
  services.syncthing.settings.folders = {
    "sync".devices = [ "intrepid" "vigilant" ];
    "code".devices = [ "intrepid" "vigilant" ];
  };
}
```

**Similarly for intrepid and vigilant** (create after NixOS installation):

```nix
# hosts/intrepid/home.nix
{ config, pkgs, inputs, ... }:

{
  imports = [ ../common/home.nix ];

  services.syncthing.settings.folders = {
    "sync".devices = [ "mischief" "vigilant" ];
    "code".devices = [ "mischief" "vigilant" ];
  };
}
```

```nix
# hosts/vigilant/home.nix
{ config, pkgs, inputs, ... }:

{
  imports = [ ../common/home.nix ];

  services.syncthing.settings.folders = {
    "sync".devices = [ "mischief" "intrepid" ];
    "code".devices = [ "mischief" "intrepid" ];
  };
}
```

### Step 9: Test on Mischief

**Rebuild NixOS on mischief:**

```bash
cd ~/nixos-dotfiles

# Check flake validity
nix flake check

# Build and activate
sudo nixos-rebuild switch --flake .#mischief
```

**Verify secrets were deployed:**

```bash
# Check SSH keys
ls -la ~/.ssh/id_ed25519*
cat ~/.ssh/id_ed25519.pub

# Check Syncthing keys
ls -la ~/.local/state/syncthing/
cat ~/.local/state/syncthing/cert.pem

# Test SSH key (should work without password)
ssh-add -l
```

**Check Syncthing:**

```bash
# Get mischief's device ID
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# Or open web UI
xdg-open http://127.0.0.1:8384
```

**Update common/home.nix with mischief's device ID:**

Add mischief to the devices section:

```nix
devices = {
  "mischief" = {
    id = "[actual device ID from above command]";
    addresses = [ "dynamic" ];
  };
  "intrepid" = {
    id = "INTREPID-DEVICE-ID-HERE";
    addresses = [ "dynamic" ];
  };
  "vigilant" = {
    id = "VIGILANT-DEVICE-ID-HERE";
    addresses = [ "dynamic" ];
  };
};
```

### Step 10: Commit Initial Setup (mischief only)

```bash
cd ~/nixos-dotfiles

# Stage changes
git add flake.nix flake.lock
git add secrets/.sops.yaml
git add secrets/keys/
git add secrets/ssh/mischief.yaml
git add secrets/syncthing/mischief.yaml
git add hosts/mischief/secrets.nix
git add hosts/mischief/configuration.nix
git add hosts/mischief/home.nix
git add hosts/common/home.nix

# Commit
git commit -m "Add sops-nix secrets management for mischief

- Add sops-nix flake input
- Create age key infrastructure
- Encrypt SSH keys for mischief
- Encrypt Syncthing identity for mischief
- Configure declarative Syncthing with placeholder device IDs
- Add secrets.nix for mischief host"

# Push to remote
git push
```

### Step 11: Prepare for Intrepid Migration

**Before wiping Arch on intrepid:**

1. Verify backups exist on mischief:
   ```bash
   ls ~/nixos-dotfiles/backups/intrepid/
   # Should contain:
   # - intrepid-syncthing-key.pem
   # - intrepid-syncthing-cert.pem
   # - intrepid-device-id.txt
   # - ssh-backup/ (if any keys to preserve)
   ```

2. Note intrepid's Syncthing device ID:
   ```bash
   cat ~/nixos-dotfiles/backups/intrepid/intrepid-device-id.txt
   ```

**After installing NixOS on intrepid:**

1. Generate intrepid's age key:
   ```bash
   # On intrepid
   sudo ssh-keygen -A
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

   # Copy output to mischief and save to secrets/keys/hosts/intrepid.txt
   ```

2. Update `.sops.yaml` to include intrepid (uncomment the sections)

3. Generate and encrypt SSH keys for intrepid (same as Step 5)

4. Encrypt Syncthing identity using backed-up keys:
   ```bash
   # On mischief
   cd ~/nixos-dotfiles/secrets
   sops syncthing/intrepid.yaml

   # Paste contents from backups/intrepid/intrepid-syncthing-key.pem
   # and intrepid-syncthing-cert.pem
   ```

5. Create `hosts/intrepid/secrets.nix` (same structure as mischief)

6. Update `hosts/intrepid/configuration.nix` to import `./secrets.nix`

7. Create `hosts/intrepid/home.nix` with device list override

8. Update `hosts/common/home.nix` with intrepid's actual device ID

9. Re-encrypt all secrets to include intrepid:
   ```bash
   cd ~/nixos-dotfiles/secrets
   sops updatekeys ssh/mischief.yaml
   sops updatekeys syncthing/mischief.yaml
   # This adds intrepid's age key to existing secrets
   ```

10. Rebuild on intrepid:
    ```bash
    sudo nixos-rebuild switch --flake .#intrepid
    ```

### Step 12: Prepare for Vigilant Migration

Follow the same process as Step 11, but for vigilant.

### Step 13: Final Verification

**After all hosts are migrated:**

1. **Verify SSH keys on each host:**
   ```bash
   # On each host
   ls -la ~/.ssh/id_ed25519*
   ssh-keygen -lf ~/.ssh/id_ed25519.pub
   ```

2. **Verify Syncthing connectivity:**
   ```bash
   # On each host, check that all devices are connected
   curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq
   ```

3. **Test file synchronization:**
   ```bash
   # On mischief
   echo "Test from mischief" > ~/Sync/test.txt

   # Wait a few seconds, then on intrepid:
   cat ~/Sync/test.txt  # Should show "Test from mischief"
   ```

4. **Verify each host can only decrypt its own secrets:**
   ```bash
   # On mischief (should work)
   sudo sops -d /home/dustin/nixos-dotfiles/secrets/ssh/mischief.yaml

   # On mischief (should fail - no access to intrepid's key)
   sudo sops -d /home/dustin/nixos-dotfiles/secrets/ssh/intrepid.yaml
   ```

---

## Manual Steps Required

These steps **cannot** be automated and must be done manually:

1. **Generate and backup admin age key** (Step 1)
   - This is a one-time setup
   - Must be backed up to secure location

2. **Extract Syncthing identities from Arch hosts** (Prerequisites)
   - Must be done before wiping Arch installations
   - Copy to mischief for safekeeping

3. **Update .sops.yaml after each NixOS installation**
   - Add new host's age public key
   - Uncomment creation rules for that host

4. **Re-encrypt existing secrets** when adding new hosts
   - Use `sops updatekeys <file>` for each secret file
   - This ensures new host can be added to existing secrets as admin

5. **Update Syncthing device IDs** after each rebuild
   - Get actual device ID from web UI or API
   - Update in `hosts/common/home.nix`
   - Rebuild all hosts for changes to take effect

6. **Add SSH public keys to GitHub/GitLab/servers**
   - Each host has unique SSH key
   - Must manually add each public key to remote services

---

## Verification Steps

### Per-Step Verification

**After Step 2 (flake update):**
```bash
nix flake check
# Should complete without errors
```

**After Step 7 (secrets.nix created):**
```bash
nix-instantiate --eval --expr '(import ./hosts/mischief/configuration.nix)'
# Should not have syntax errors
```

**After Step 9 (rebuild on mischief):**
```bash
# SSH keys deployed
test -f ~/.ssh/id_ed25519 && echo "SSH private key exists"
test -f ~/.ssh/id_ed25519.pub && echo "SSH public key exists"

# Correct permissions
stat -c "%a %n" ~/.ssh/id_ed25519  # Should be 600
stat -c "%a %n" ~/.ssh/id_ed25519.pub  # Should be 644

# Syncthing keys deployed
test -f ~/.local/state/syncthing/key.pem && echo "Syncthing key exists"
test -f ~/.local/state/syncthing/cert.pem && echo "Syncthing cert exists"

# Syncthing service running
systemctl --user status syncthing
```

### Final System Verification

**All hosts online and syncing:**
```bash
# Run on each host
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'
# Should list all other hosts
```

**Secrets are properly isolated:**
```bash
# On mischief, try to decrypt intrepid's secrets (should fail)
cd ~/nixos-dotfiles
sops -d secrets/ssh/intrepid.yaml
# Error: no key could decrypt the file

# But admin key should work (on machine with admin key)
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d secrets/ssh/intrepid.yaml
# Should show decrypted content
```

**SSH keys work:**
```bash
# On each host
ssh-add -l  # Should list the ed25519 key
ssh -T git@github.com  # Test GitHub authentication (after adding key to GitHub)
```

---

## Rollback Procedures

### If Rebuild Fails on Mischief

**Rollback to previous generation:**
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nix-env --rollback --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

**If secrets are broken:**
```bash
# Manually restore SSH keys
cp ~/nixos-dotfiles/backups/mischief/id_ed25519 ~/.ssh/
chmod 600 ~/.ssh/id_ed25519

# Manually restore Syncthing keys
cp ~/nixos-dotfiles/backups/mischief/key.pem ~/.local/state/syncthing/
cp ~/nixos-dotfiles/backups/mischief/cert.pem ~/.local/state/syncthing/
chmod 600 ~/.local/state/syncthing/key.pem
systemctl --user restart syncthing
```

### If Host Age Key is Lost

**Regenerate from SSH host key:**
```bash
# The age key is deterministic from SSH host key
sudo ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# This will give the same age public key

# Update in repo if needed
cd ~/nixos-dotfiles
echo "age1newkey..." > secrets/keys/hosts/mischief.txt

# Re-encrypt all mischief secrets
cd secrets
sops updatekeys ssh/mischief.yaml
sops updatekeys syncthing/mischief.yaml
```

### If Admin Age Key is Lost

**CRITICAL - This is why backups are important!**

If admin key is lost and you need to rotate:

1. Generate new admin key:
   ```bash
   age-keygen -o ~/.config/sops/age/keys-new.txt
   ```

2. Update all secrets to use new admin key:
   ```bash
   # For each secret file, you'll need to decrypt with host key and re-encrypt
   # This requires access to each host

   # On mischief:
   cd ~/nixos-dotfiles/secrets

   # Decrypt with old admin key (if you have backup) or host key
   sudo sops -d ssh/mischief.yaml > /tmp/mischief-ssh.yaml

   # Update .sops.yaml with new admin key
   # Then re-encrypt
   sops -e /tmp/mischief-ssh.yaml > ssh/mischief.yaml
   rm /tmp/mischief-ssh.yaml
   ```

3. **Prevention**: Always keep 2-3 backups of admin key in different secure locations

### If NixOS Installation Fails on intrepid/vigilant

**You still have the Arch installation:**

1. Boot back into Arch Linux (if dual-boot) or from live USB
2. Restore Syncthing keys from backup
3. Continue using Arch until NixOS issues are resolved
4. Syncthing will continue syncing with other hosts

**If you need to abort NixOS migration:**

1. Reinstall Arch Linux
2. Restore from `~/nixos-migration-backup/`
3. Syncthing identity will be preserved
4. SSH keys can be restored from backup

---

## Security Considerations

### What's Safe to Commit to Git

**Safe (COMMIT these):**
- `.sops.yaml` - Contains only public keys
- `secrets/keys/hosts/*.txt` - Age public keys
- `secrets/keys/users/admin.txt` - Admin age public key
- `secrets/ssh/*.yaml` - Encrypted SSH keys (safe because encrypted)
- `secrets/syncthing/*.yaml` - Encrypted Syncthing identities (safe because encrypted)
- `hosts/*/secrets.nix` - Secret definitions (paths only, no actual secrets)

**NEVER COMMIT:**
- `~/.config/sops/age/keys.txt` - Admin private age key
- `/var/lib/sops-nix/key.txt` - Host private age keys
- `backups/*/` - Unencrypted backup files
- Any file containing `-----BEGIN PRIVATE KEY-----` in plaintext

### Backup Strategy

**Critical files to backup:**

1. **Admin age private key** (`~/.config/sops/age/keys.txt`)
   - Store in password manager (1Password, Bitwarden, etc.)
   - Encrypted USB drive in safe location
   - Print on paper and store in safe (for disaster recovery)

2. **This dotfiles repository**
   - Already on GitHub (private repo recommended)
   - Local backups on multiple machines
   - Encrypted cloud storage (optional)

3. **Syncthing identities** (before migration)
   - Keep backups until all hosts migrated
   - Store encrypted backups in dotfiles repo (already done)

**Backup verification:**
```bash
# Test admin key backup works
SOPS_AGE_KEY_FILE=/path/to/backup/keys.txt sops -d secrets/ssh/mischief.yaml
# Should decrypt successfully
```

### What Happens if a Host is Compromised

**If mischief is compromised:**

1. **Immediate actions:**
   ```bash
   # Revoke SSH keys from GitHub/servers
   # (see docs/ssh-keys.md for detailed steps)

   # On GitHub: Settings → SSH Keys → Delete mischief key

   # On other servers:
   ssh other-server
   # Edit ~/.ssh/authorized_keys, remove mischief's public key
   ```

2. **Rotate secrets:**
   ```bash
   # Generate new SSH key for mischief
   ssh-keygen -t ed25519 -C "dustin@mischief" -f /tmp/new_mischief_key

   # Encrypt new key
   cd ~/nixos-dotfiles/secrets
   sops ssh/mischief.yaml
   # Replace with new key

   # Deploy
   sudo nixos-rebuild switch --flake .#mischief
   ```

3. **Optionally rotate Syncthing identity** (if you suspect Syncthing data was accessed):
   ```bash
   # Generate new Syncthing identity
   nix-shell -p syncthing --run "syncthing generate --home=/tmp/st"

   # Encrypt new identity
   sops secrets/syncthing/mischief.yaml
   # Replace with new cert/key

   # Rebuild mischief
   sudo nixos-rebuild switch --flake .#mischief

   # Update device ID in common/home.nix on all hosts
   # Rebuild all hosts to pick up new device ID
   ```

**Importantly:**
- Other hosts (intrepid, vigilant) are NOT compromised
- Their secrets remain secure (can't be decrypted by mischief's key)
- Only mischief's secrets need rotation

**If admin key is compromised:**
- ALL secrets are potentially compromised
- Must rotate ALL secrets on ALL hosts
- Generate new admin key
- Re-encrypt everything
- This is why admin key security is critical!

---

## Additional Notes

### Why Per-Host SSH Keys?

**Security benefits:**
- Host compromise doesn't expose other hosts' keys
- Can revoke one host's access without affecting others
- Audit trail: know which host accessed what

**Trade-off:**
- More keys to manage (3 instead of 1)
- Must add each key to GitHub/servers separately
- Slightly more complex setup

**Alternative**: If you prefer shared SSH keys, create one `secrets/ssh/shared.yaml` and deploy to all hosts. However, this is less secure.

### Why Preserve Syncthing Identities?

**Benefits:**
- No need to re-pair devices after migration
- Keeps sync history and folder state
- Devices automatically reconnect after migration

**If you didn't preserve:**
- Syncthing would treat it as a new device
- Must re-add and re-pair on other hosts
- Initial sync would re-transfer all files (wasted bandwidth)

### Syncthing Device IDs

**How they work:**
- Device ID is derived from certificate (cert.pem)
- It's a hash of the public key in the certificate
- Same cert = same device ID (this is why we preserve it)

**Getting device IDs:**
```bash
# Method 1: From Syncthing API
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# Method 2: From web UI
# Open http://127.0.0.1:8384
# Click "Actions" → "Show ID"

# Method 3: From certificate
openssl x509 -in ~/.local/state/syncthing/cert.pem -noout -fingerprint -sha256 | \
  tr -d ':' | tail -c 64 | fold -w 7 | paste -sd- | tr '[:lower:]' '[:upper:]'
```

### Age vs GPG

**Why age over GPG:**
- Simpler: 1 key type vs many (RSA, Ed25519, etc.)
- Modern: Designed for file encryption specifically
- Smaller keys: Easier to manage
- Better UX: Less confusing than GPG

**sops supports both**, but age is recommended for new setups.

### Testing sops Encryption/Decryption

**Encrypt a test file:**
```bash
cd ~/nixos-dotfiles/secrets
echo "test secret" > test.txt
sops -e test.txt > test.yaml
rm test.txt

# Verify it's encrypted
cat test.yaml  # Should be gibberish

# Decrypt
sops -d test.yaml  # Should show "test secret"
```

**Test with specific age key:**
```bash
# Use admin key
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d secrets/ssh/mischief.yaml

# Use host key (on that host)
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d secrets/ssh/mischief.yaml
```

---

## Success Criteria

This implementation is successful when:

- [ ] All three hosts have unique SSH keys deployed
- [ ] SSH keys are properly encrypted in the repository
- [ ] Each host can only decrypt its own secrets
- [ ] Admin key can decrypt all secrets (for emergency access)
- [ ] Syncthing is declaratively configured in home.nix
- [ ] All Syncthing devices can connect to each other
- [ ] Original Syncthing device IDs are preserved from Arch hosts
- [ ] ~/Sync and ~/Code folders sync across all three hosts
- [ ] Files created on one host appear on others within seconds
- [ ] Documentation exists for all lifecycle operations (see docs/ folder)
- [ ] Rollback procedures are tested and work
- [ ] Admin age key is backed up to at least 2 secure locations
- [ ] No plaintext secrets exist in the git repository
- [ ] `nix flake check` passes on all hosts

---

## Next Steps After Implementation

1. **Add more secrets as needed:**
   - API tokens
   - Database passwords
   - Wi-Fi passwords
   - VPN configurations

2. **Document host-specific procedures** in docs/

3. **Set up automatic secret rotation** (optional, advanced)

4. **Consider encrypted backups** of entire home directory

5. **Monitor Syncthing** for conflicts or sync issues

---

## Troubleshooting

### sops: no key could decrypt the file

**Cause**: The age key used for decryption is not in the file's allowed keys.

**Solution**:
```bash
# Check which keys can decrypt
sops -d --verbose secrets/ssh/mischief.yaml

# Update keys if needed
cd ~/nixos-dotfiles/secrets
sops updatekeys ssh/mischief.yaml
```

### Syncthing devices can't connect

**Cause**: Firewall, wrong device ID, or Syncthing not running.

**Solution**:
```bash
# Check service status
systemctl --user status syncthing

# Check device IDs match
curl http://127.0.0.1:8384/rest/system/config 2>/dev/null | jq -r '.devices[].deviceID'

# Check if firewall is blocking (usually not an issue on local network)
sudo firewall-cmd --list-all  # If using firewalld
```

### SSH key has wrong permissions after deployment

**Cause**: sops-nix didn't set mode correctly.

**Solution**:
```bash
# Fix manually
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Or fix in secrets.nix and rebuild
# Ensure mode = "0600" for private key
```

### Age key not generated on new host

**Cause**: SSH host key doesn't exist yet.

**Solution**:
```bash
# Generate SSH host keys
sudo ssh-keygen -A

# Then rebuild
sudo nixos-rebuild switch --flake .#hostname
```

---

## File Checklist

After completing this plan, you should have:

```
~/nixos-dotfiles/
├── flake.nix                           # ✓ Updated with sops-nix input
├── flake.lock                          # ✓ Updated
├── secrets/
│   ├── .sops.yaml                      # ✓ Created
│   ├── keys/
│   │   ├── hosts/
│   │   │   ├── mischief.txt            # ✓ Created
│   │   │   ├── intrepid.txt            # ✓ Created (after migration)
│   │   │   └── vigilant.txt            # ✓ Created (after migration)
│   │   └── users/
│   │       └── admin.txt               # ✓ Created
│   ├── ssh/
│   │   ├── mischief.yaml               # ✓ Created
│   │   ├── intrepid.yaml               # ✓ Created (after migration)
│   │   └── vigilant.yaml               # ✓ Created (after migration)
│   └── syncthing/
│       ├── mischief.yaml               # ✓ Created
│       ├── intrepid.yaml               # ✓ Created (after migration)
│       └── vigilant.yaml               # ✓ Created (after migration)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix           # ✓ No changes needed
│   │   └── home.nix                    # ✓ Updated with declarative Syncthing
│   ├── mischief/
│   │   ├── configuration.nix           # ✓ Imports secrets.nix
│   │   ├── secrets.nix                 # ✓ Created
│   │   └── home.nix                    # ✓ Created with device override
│   ├── intrepid/
│   │   ├── configuration.nix           # ✓ Imports secrets.nix (after migration)
│   │   ├── secrets.nix                 # ✓ Created (after migration)
│   │   └── home.nix                    # ✓ Created (after migration)
│   └── vigilant/
│       ├── configuration.nix           # ✓ Imports secrets.nix (after migration)
│       ├── secrets.nix                 # ✓ Created (after migration)
│       └── home.nix                    # ✓ Created (after migration)
├── backups/                            # ✓ Created (not committed to git)
│   ├── mischief/
│   ├── intrepid/
│   └── vigilant/
├── docs/
│   ├── sops-secrets.md                 # ✓ Created (see separate file)
│   ├── ssh-keys.md                     # ✓ Created (see separate file)
│   └── syncthing.md                    # ✓ Created (see separate file)
└── plans/
    └── 007-sops-nix-secrets-plan.md    # ✓ This file
```

**NOT in repository (keep secure):**
```
~/.config/sops/age/keys.txt              # Admin private key (BACKUP THIS!)
/var/lib/sops-nix/key.txt                # Host private keys (auto-generated)
```
