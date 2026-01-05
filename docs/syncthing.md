# Syncthing Management Guide

This guide covers managing Syncthing devices, folders, and identities in the Romey NixOS dotfiles repository.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Normal Operations](#normal-operations)
  - [Adding a New Device](#adding-a-new-device)
  - [Removing a Device](#removing-a-device)
  - [Adding a Shared Folder](#adding-a-shared-folder)
  - [Removing a Shared Folder](#removing-a-shared-folder)
  - [Checking Sync Status](#checking-sync-status)
- [Migration](#migration)
  - [Migrating from Arch to NixOS (Preserving Identity)](#migrating-from-arch-to-nixos-preserving-identity)
  - [Creating New Syncthing Identity](#creating-new-syncthing-identity)
- [Troubleshooting](#troubleshooting)
  - [Devices Can't Connect](#devices-cant-connect)
  - [Files Not Syncing](#files-not-syncing)
  - [Conflict Files](#conflict-files)
  - [High CPU/Memory Usage](#high-cpumemory-usage)
- [Advanced Operations](#advanced-operations)
  - [Changing Device ID](#changing-device-id)
  - [Folder Versioning](#folder-versioning)
  - [Ignoring Files](#ignoring-files)
  - [Bandwidth Limits](#bandwidth-limits)
- [Best Practices](#best-practices)
- [Quick Reference](#quick-reference)

---

## Overview

**Syncthing** is a continuous file synchronization program that keeps files in sync across multiple devices without requiring a central server.

**In this setup:**
- **3 hosts**: mischief, intrepid, vigilant
- **2 shared folders**: `~/Sync` and `~/Code`
- **Declarative config**: Defined in `hosts/common/home.nix` via home-manager
- **Encrypted identities**: Device identities (key.pem, cert.pem) stored in git via sops-nix

**Key concepts:**
- **Device**: A Syncthing instance (one per host)
- **Device ID**: Unique identifier derived from certificate (65-character alphanumeric)
- **Folder**: A directory to sync (e.g., ~/Sync)
- **Identity**: Public/private key pair (key.pem + cert.pem) that identifies a device

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Git Repository                              │
│                                                                 │
│  secrets/syncthing/                                             │
│  ├── mischief.yaml   ← Encrypted key.pem + cert.pem            │
│  ├── intrepid.yaml   ← Encrypted key.pem + cert.pem            │
│  └── vigilant.yaml   ← Encrypted key.pem + cert.pem            │
│                                                                 │
│  hosts/common/home.nix                                          │
│  └── services.syncthing.settings                               │
│      ├── devices: {intrepid, vigilant, mischief}               │
│      └── folders: {sync, code}                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                      nixos-rebuild / home-manager switch
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       NixOS Host (e.g., mischief)               │
│                                                                 │
│  ~/.local/state/syncthing/                                      │
│  ├── key.pem    ← Deployed from sops (symlink from /run/secrets)│
│  ├── cert.pem   ← Deployed from sops (symlink from /run/secrets)│
│  └── config.xml ← Generated from home.nix settings              │
│                                                                 │
│  Syncthing service: systemctl --user status syncthing          │
│  Web UI: http://127.0.0.1:8384                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    Syncs with other devices
                              ↓
            ┌─────────────────┼─────────────────┐
            ↓                 ↓                 ↓
        intrepid          vigilant          (others)
       ~/Sync/            ~/Sync/
       ~/Code/            ~/Code/
```

---

## Normal Operations

### Adding a New Device

**Scenario**: You're adding a fourth device called "endeavor".

**Step 1: Install and start Syncthing on endeavor**

After NixOS installation on endeavor:

```bash
# On endeavor, ensure Syncthing is enabled in home.nix
# (It should inherit from hosts/common/home.nix)

# Rebuild to start Syncthing
home-manager switch --flake .#dustin

# Or if using nixos-rebuild:
sudo nixos-rebuild switch --flake .#endeavor

# Verify Syncthing is running
systemctl --user status syncthing
```

**Step 2: Get endeavor's device ID**

```bash
# On endeavor
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# Or from the web UI:
# Open http://127.0.0.1:8384
# Actions → Show ID
# Copy the device ID (e.g., YZQNMTK-ZQNMTKY-...)
```

**Step 3: Backup endeavor's Syncthing identity**

```bash
# On endeavor
mkdir -p ~/nixos-dotfiles/backups/endeavor
cp ~/.local/state/syncthing/key.pem ~/nixos-dotfiles/backups/endeavor/
cp ~/.local/state/syncthing/cert.pem ~/nixos-dotfiles/backups/endeavor/
```

**Step 4: Encrypt the identity**

```bash
# On mischief (or wherever you manage secrets)
cd ~/nixos-dotfiles/secrets

# Ensure endeavor is configured in .sops.yaml
# (See docs/sops-secrets.md for adding a new host)

# Encrypt the identity
sops syncthing/endeavor.yaml
```

Add content:

```yaml
syncthing_key: |
  -----BEGIN EC PRIVATE KEY-----
  [paste backups/endeavor/key.pem content]
  -----END EC PRIVATE KEY-----

syncthing_cert: |
  -----BEGIN CERTIFICATE-----
  [paste backups/endeavor/cert.pem content]
  -----END CERTIFICATE-----
```

**Step 5: Update hosts/common/home.nix**

Edit the Syncthing devices section:

```nix
services.syncthing = {
  enable = true;

  settings = {
    devices = {
      "mischief" = {
        id = "MISCHIEF-DEVICE-ID-HERE";
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
      "endeavor" = {  # Add this
        id = "ENDEAVOR-DEVICE-ID-FROM-STEP-2";
        addresses = [ "dynamic" ];
      };
    };

    folders = {
      "sync" = {
        path = "/home/dustin/Sync";
        devices = [ "mischief" "intrepid" "vigilant" "endeavor" ];  # Add endeavor
        ignorePerms = false;
      };

      "code" = {
        path = "/home/dustin/Code";
        devices = [ "mischief" "intrepid" "vigilant" "endeavor" ];  # Add endeavor
        ignorePerms = false;
      };
    };

    options = {
      urAccepted = -1;
      localAnnounceEnabled = true;
      globalAnnounceEnabled = true;
    };
  };
};
```

**Step 6: Create host-specific override for endeavor**

Edit `hosts/endeavor/home.nix`:

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [ ../common/home.nix ];

  # Exclude endeavor from its own device list
  services.syncthing.settings.folders = {
    "sync".devices = [ "mischief" "intrepid" "vigilant" ];
    "code".devices = [ "mischief" "intrepid" "vigilant" ];
  };
}
```

**Step 7: Add Syncthing identity to endeavor's secrets.nix**

Edit `hosts/endeavor/secrets.nix`:

```nix
sops.secrets = {
  # ... existing SSH secrets ...

  # Syncthing private key
  "syncthing_key" = {
    sopsFile = ../../secrets/syncthing/endeavor.yaml;
    path = "/home/dustin/.local/state/syncthing/key.pem";
    owner = "dustin";
    group = "users";
    mode = "0600";
  };

  # Syncthing certificate
  "syncthing_cert" = {
    sopsFile = ../../secrets/syncthing/endeavor.yaml;
    path = "/home/dustin/.local/state/syncthing/cert.pem";
    owner = "dustin";
    group = "users";
    mode = "0644";
  };
};
```

**Step 8: Rebuild all hosts**

```bash
# On each host (mischief, intrepid, vigilant, endeavor)
home-manager switch --flake .#dustin

# Or if using nixos-rebuild:
sudo nixos-rebuild switch --flake .#hostname
```

**Step 9: Verify connectivity**

```bash
# On each host, check that all devices are connected
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'

# Should list all other devices
# Or check web UI: http://127.0.0.1:8384
```

**Step 10: Verify synchronization**

```bash
# On mischief, create a test file
echo "Test from mischief" > ~/Sync/test.txt

# Wait a few seconds, then on endeavor:
cat ~/Sync/test.txt
# Should show: Test from mischief

# Clean up
rm ~/Sync/test.txt
```

**Step 11: Commit**

```bash
cd ~/nixos-dotfiles
git add secrets/syncthing/endeavor.yaml
git add hosts/common/home.nix
git add hosts/endeavor/home.nix
git add hosts/endeavor/secrets.nix
git commit -m "Add endeavor to Syncthing cluster"
git push
```

---

### Removing a Device

**Scenario**: You're decommissioning "mischief" and removing it from the Syncthing cluster.

**Step 1: Remove from hosts/common/home.nix**

Edit the Syncthing devices section:

```nix
services.syncthing.settings = {
  devices = {
    # Remove mischief:
    # "mischief" = { ... };

    "intrepid" = { ... };
    "vigilant" = { ... };
  };

  folders = {
    "sync" = {
      path = "/home/dustin/Sync";
      devices = [ "intrepid" "vigilant" ];  # Remove mischief
      ignorePerms = false;
    };

    "code" = {
      path = "/home/dustin/Code";
      devices = [ "intrepid" "vigilant" ];  # Remove mischief
      ignorePerms = false;
    };
  };
};
```

**Step 2: Update host-specific overrides**

Edit `hosts/intrepid/home.nix` and `hosts/vigilant/home.nix`:

```nix
services.syncthing.settings.folders = {
  "sync".devices = [ "vigilant" ];  # Remove mischief
  "code".devices = [ "vigilant" ];  # Remove mischief
};
```

**Step 3: Rebuild remaining hosts**

```bash
# On intrepid and vigilant
home-manager switch --flake .#dustin
```

**Step 4: (Optional) Remove encrypted identity**

```bash
cd ~/nixos-dotfiles
rm secrets/syncthing/mischief.yaml
```

**Step 5: Commit**

```bash
git add hosts/common/home.nix
git add hosts/intrepid/home.nix
git add hosts/vigilant/home.nix
git add secrets/syncthing/mischief.yaml  # If deleted
git commit -m "Remove mischief from Syncthing cluster"
git push
```

**Step 6: Verify on remaining hosts**

```bash
# On intrepid
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'
# Should NOT list mischief
```

---

### Adding a Shared Folder

**Scenario**: You want to sync `~/Documents` across all hosts.

**Step 1: Create folder on all hosts**

```bash
# On each host
mkdir -p ~/Documents
```

**Step 2: Update hosts/common/home.nix**

Add the new folder to `services.syncthing.settings.folders`:

```nix
folders = {
  "sync" = {
    path = "/home/dustin/Sync";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;
  };

  "code" = {
    path = "/home/dustin/Code";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;
  };

  # Add this:
  "documents" = {
    path = "/home/dustin/Documents";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;
  };
};
```

**Step 3: Update host-specific overrides**

Edit `hosts/mischief/home.nix` (and similarly for intrepid, vigilant):

```nix
services.syncthing.settings.folders = {
  "sync".devices = [ "intrepid" "vigilant" ];
  "code".devices = [ "intrepid" "vigilant" ];
  "documents".devices = [ "intrepid" "vigilant" ];  # Add this
};
```

**Step 4: Rebuild all hosts**

```bash
# On each host
home-manager switch --flake .#dustin
```

**Step 5: Verify**

```bash
# Check Syncthing recognizes the folder
curl http://127.0.0.1:8384/rest/system/config 2>/dev/null | jq -r '.folders[].id'
# Should list: sync, code, documents

# Test sync
echo "Test" > ~/Documents/test.txt
# Wait a few seconds, check on other hosts
```

**Step 6: Commit**

```bash
cd ~/nixos-dotfiles
git add hosts/common/home.nix
git add hosts/*/home.nix
git commit -m "Add ~/Documents to Syncthing shared folders"
git push
```

---

### Removing a Shared Folder

**Scenario**: You no longer want to sync `~/Documents`.

**Step 1: Remove from hosts/common/home.nix**

Edit the Syncthing folders section:

```nix
folders = {
  "sync" = { ... };
  "code" = { ... };
  # Remove documents:
  # "documents" = { ... };
};
```

**Step 2: Remove from host-specific overrides**

Edit `hosts/*/home.nix` and remove references to `"documents"`.

**Step 3: Rebuild all hosts**

```bash
# On each host
home-manager switch --flake .#dustin
```

**Step 4: (Optional) Delete local folder**

```bash
# On each host, if you want to delete the folder
rm -rf ~/Documents
```

**Note**: Syncthing will NOT automatically delete the folder. You must manually delete it if desired.

**Step 5: Commit**

```bash
git add hosts/common/home.nix
git add hosts/*/home.nix
git commit -m "Remove ~/Documents from Syncthing"
git push
```

---

### Checking Sync Status

**Web UI (easiest):**

```bash
# Open in browser
xdg-open http://127.0.0.1:8384

# Check:
# - "This Device" shows sync status for each folder
# - "Remote Devices" shows connected/disconnected status
# - "Global State" vs "Local State" for each folder
```

**CLI (API):**

```bash
# Check connected devices
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq

# Check folder status
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq

# Check if folder is idle (fully synced)
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq -r '.state'
# Output: "idle" (synced) or "syncing" (in progress)

# Check completion percentage with another device
curl "http://127.0.0.1:8384/rest/db/completion?folder=sync&device=DEVICE-ID" 2>/dev/null | jq -r '.completion'
```

**Check logs:**

```bash
# Syncthing service logs
journalctl --user -u syncthing -f

# Look for errors, warnings, or connection issues
```

**Quick status script:**

```bash
#!/usr/bin/env bash
# syncthing-status.sh

API="http://127.0.0.1:8384/rest"

echo "=== Syncthing Status ==="
echo

# Device info
echo "This device:"
curl -s "$API/system/status" | jq -r '.myID'
echo

# Connected devices
echo "Connected devices:"
curl -s "$API/system/connections" | jq -r '.connections | keys[]'
echo

# Folder status
echo "Folders:"
for folder in $(curl -s "$API/system/config" | jq -r '.folders[].id'); do
  state=$(curl -s "$API/db/status?folder=$folder" | jq -r '.state')
  echo "  $folder: $state"
done
```

---

## Migration

### Migrating from Arch to NixOS (Preserving Identity)

**Scenario**: Migrating "intrepid" from Arch Linux to NixOS while keeping the same Syncthing device ID.

**Why preserve identity:**
- Other devices recognize it immediately (no re-pairing)
- Sync history is maintained
- No need to re-transfer all files

**Prerequisites:**
- Backup intrepid's Syncthing identity (key.pem, cert.pem) BEFORE wiping Arch
- Backup files in ~/Sync and ~/Code (or ensure they're synced to other devices)

**Step 1: Backup identity on Arch**

```bash
# On intrepid (still running Arch)
mkdir -p ~/nixos-migration-backup

# Find Syncthing data directory
# Common locations:
# ~/.local/state/syncthing/
# ~/.config/syncthing/
# Check with: systemctl --user status syncthing

# Backup identity files
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/

# Backup device ID for reference
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID' > ~/nixos-migration-backup/device-id.txt
```

**Step 2: Copy backup to safe location**

```bash
# From mischief
scp -r dustin@intrepid:~/nixos-migration-backup ~/nixos-dotfiles/backups/intrepid/

# Verify
ls ~/nixos-dotfiles/backups/intrepid/
# Should contain: key.pem, cert.pem, device-id.txt
```

**Step 3: Install NixOS on intrepid**

Follow standard NixOS installation process.

**Step 4: Encrypt the identity**

```bash
# On mischief (or wherever you manage secrets)
cd ~/nixos-dotfiles/secrets

# Ensure intrepid is configured in .sops.yaml
# (See docs/sops-secrets.md)

# Encrypt the identity
sops syncthing/intrepid.yaml
```

Add content:

```yaml
syncthing_key: |
  -----BEGIN EC PRIVATE KEY-----
  [paste backups/intrepid/key.pem content]
  -----END EC PRIVATE KEY-----

syncthing_cert: |
  -----BEGIN CERTIFICATE-----
  [paste backups/intrepid/cert.pem content]
  -----END CERTIFICATE-----
```

**Step 5: Configure sops-nix for intrepid**

Create `hosts/intrepid/secrets.nix` (if not already done):

```nix
{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/ssh/intrepid.yaml;
    validateSopsFiles = true;

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      # SSH keys
      "ssh_private_key" = {
        sopsFile = ../../secrets/ssh/intrepid.yaml;
        path = "/home/dustin/.ssh/id_ed25519";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      "ssh_public_key" = {
        sopsFile = ../../secrets/ssh/intrepid.yaml;
        path = "/home/dustin/.ssh/id_ed25519.pub";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };

      # Syncthing identity
      "syncthing_key" = {
        sopsFile = ../../secrets/syncthing/intrepid.yaml;
        path = "/home/dustin/.local/state/syncthing/key.pem";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      "syncthing_cert" = {
        sopsFile = ../../secrets/syncthing/intrepid.yaml;
        path = "/home/dustin/.local/state/syncthing/cert.pem";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/dustin/.ssh 0700 dustin users"
    "d /home/dustin/.local/state/syncthing 0700 dustin users"
  ];
}
```

**Step 6: Configure Syncthing in home.nix**

The configuration should already exist in `hosts/common/home.nix`. Just ensure `hosts/intrepid/home.nix` has:

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [ ../common/home.nix ];

  # Exclude intrepid from its own device list
  services.syncthing.settings.folders = {
    "sync".devices = [ "mischief" "vigilant" ];
    "code".devices = [ "mischief" "vigilant" ];
  };
}
```

**Step 7: Update hosts/common/home.nix with intrepid's device ID**

Verify the device ID matches what you backed up:

```bash
cat ~/nixos-dotfiles/backups/intrepid/device-id.txt
```

Ensure `hosts/common/home.nix` has:

```nix
services.syncthing.settings.devices = {
  "intrepid" = {
    id = "DEVICE-ID-FROM-BACKUP";  # Should match device-id.txt
    addresses = [ "dynamic" ];
  };
  # ... other devices
};
```

**Step 8: Rebuild on intrepid**

```bash
# On intrepid (freshly installed NixOS)
cd ~/nixos-dotfiles
sudo nixos-rebuild switch --flake .#intrepid
```

**Step 9: Verify identity is deployed**

```bash
# On intrepid
ls -la ~/.local/state/syncthing/
# Should show: key.pem, cert.pem

# Check device ID matches backup
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'
# Should match ~/nixos-dotfiles/backups/intrepid/device-id.txt
```

**Step 10: Verify connectivity**

```bash
# On intrepid
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'
# Should list: mischief, vigilant

# On mischief (or vigilant)
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'
# Should list: intrepid, [others]
```

**Step 11: Wait for sync to complete**

```bash
# On intrepid, files should start appearing
watch ls -lh ~/Sync
watch ls -lh ~/Code

# Check sync progress
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq -r '.state'
# Wait for: "idle"
```

**Step 12: Commit**

```bash
cd ~/nixos-dotfiles
git add secrets/syncthing/intrepid.yaml
git add hosts/intrepid/secrets.nix
git add hosts/intrepid/home.nix
git add hosts/common/home.nix  # If device ID was added
git commit -m "Migrate intrepid to NixOS with preserved Syncthing identity"
git push
```

**Success!** intrepid is now running NixOS with the same Syncthing device ID, and other devices automatically reconnected.

---

### Creating New Syncthing Identity

**Scenario**: You want a fresh Syncthing identity (new device ID) for a host.

**When to use:**
- New host that never had Syncthing
- You don't care about preserving device ID
- Testing or development

**Step 1: Generate new identity**

```bash
# Install Syncthing temporarily
nix-shell -p syncthing

# Generate new identity
syncthing generate --home=/tmp/syncthing-temp

# This creates:
# /tmp/syncthing-temp/key.pem
# /tmp/syncthing-temp/cert.pem
```

**Step 2: Get the device ID**

```bash
# Start Syncthing temporarily
syncthing --home=/tmp/syncthing-temp &
STPID=$!

# Wait for startup
sleep 5

# Get device ID
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# Stop Syncthing
kill $STPID
```

**Step 3: Encrypt the identity**

```bash
cd ~/nixos-dotfiles/secrets
sops syncthing/hostname.yaml
```

Add:

```yaml
syncthing_key: |
  -----BEGIN EC PRIVATE KEY-----
  [paste /tmp/syncthing-temp/key.pem]
  -----END EC PRIVATE KEY-----

syncthing_cert: |
  -----BEGIN CERTIFICATE-----
  [paste /tmp/syncthing-temp/cert.pem]
  -----END CERTIFICATE-----
```

**Step 4: Clean up**

```bash
rm -rf /tmp/syncthing-temp
```

**Step 5: Follow standard deployment**

See "Adding a New Device" above, starting from Step 3.

---

## Troubleshooting

### Devices Can't Connect

**Symptom**: Device shows "Disconnected" in web UI or not listed in connections.

**Check 1: Syncthing service running**

```bash
# On both devices
systemctl --user status syncthing
# Should be: active (running)

# If not running:
systemctl --user start syncthing
```

**Check 2: Device IDs match**

```bash
# On device A
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# Compare with device ID in hosts/common/home.nix
# They must match exactly (case-sensitive)
```

**Check 3: Firewall**

Syncthing uses:
- TCP 22000: Sync protocol
- UDP 21027: Local discovery
- TCP 443: Global discovery

```bash
# Check if ports are listening
sudo ss -tulpn | grep syncthing

# If using firewall, allow Syncthing
sudo firewall-cmd --add-service=syncthing --permanent  # firewalld
sudo ufw allow syncthing  # ufw

# Or specific ports:
sudo firewall-cmd --add-port=22000/tcp --permanent
sudo firewall-cmd --add-port=21027/udp --permanent
```

**Check 4: Network connectivity**

```bash
# Ping other device
ping intrepid

# If on different networks, ensure global discovery is enabled
curl http://127.0.0.1:8384/rest/system/config 2>/dev/null | jq -r '.options.globalAnnounceEnabled'
# Should be: true
```

**Check 5: Check logs**

```bash
journalctl --user -u syncthing -f
# Look for errors like:
# - "failed to connect"
# - "certificate error"
# - "device ID mismatch"
```

**Solution: Force restart**

```bash
systemctl --user restart syncthing
```

**Solution: Re-add device**

If all else fails, remove and re-add the device:

1. Remove device from `hosts/common/home.nix`
2. Rebuild all hosts
3. Add device back
4. Rebuild all hosts again

---

### Files Not Syncing

**Symptom**: Files created on one device don't appear on others.

**Check 1: Folder state**

```bash
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq -r '.state'
# Should be: "idle" (fully synced)
# If "syncing": In progress, wait
# If "error": Check logs
```

**Check 2: Folder path exists**

```bash
# Ensure folder exists on both devices
ls -ld ~/Sync
# Should be a directory, not a file or symlink
```

**Check 3: Permissions**

```bash
# Ensure you can write to the folder
touch ~/Sync/test.txt
rm ~/Sync/test.txt
```

**Check 4: Out of sync**

```bash
# Check if folders are out of sync
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq

# Look at:
# - "globalFiles" (total files in cluster)
# - "localFiles" (files on this device)
# - "needFiles" (files this device needs)

# If needFiles > 0, sync is pending
```

**Check 5: Ignored files**

```bash
# Check if file matches ignore patterns
# Web UI → Folder → Edit → Ignore Patterns

# Common patterns that might exclude files:
# - (?d).git      (ignores .git directories)
# - *.tmp         (ignores temp files)
# - .stfolder     (Syncthing marker)
```

**Check 6: Check for errors**

```bash
# Check for folder errors
curl http://127.0.0.1:8384/rest/folder/errors?folder=sync 2>/dev/null | jq

# Check system errors
curl http://127.0.0.1:8384/rest/system/error 2>/dev/null | jq
```

**Solution: Trigger scan**

```bash
# Force Syncthing to rescan folder
curl -X POST http://127.0.0.1:8384/rest/db/scan?folder=sync
```

**Solution: Restart Syncthing**

```bash
systemctl --user restart syncthing
```

---

### Conflict Files

**Symptom**: Files with `.sync-conflict-` in the name appear.

**Example:**
```
report.txt
report.sync-conflict-20250104-123456-ABCD123.txt
```

**Cause**: Same file modified on multiple devices simultaneously.

**Resolution**:

1. **Review both versions:**
   ```bash
   # Original
   cat report.txt

   # Conflict
   cat report.sync-conflict-20250104-123456-ABCD123.txt
   ```

2. **Merge changes manually:**
   - Use a diff tool: `diff report.txt report.sync-conflict-*.txt`
   - Or a merge tool: `meld report.txt report.sync-conflict-*.txt`

3. **Keep desired version:**
   ```bash
   # If conflict version is correct:
   mv report.sync-conflict-*.txt report.txt

   # If original is correct:
   rm report.sync-conflict-*.txt
   ```

4. **Let sync propagate:**
   - Syncthing will sync your resolution to other devices

**Prevention:**

- Avoid editing the same file on multiple devices simultaneously
- Use file locking if possible (e.g., SQLite databases)
- For code: Use git, not Syncthing (Syncthing is for documents, not version control)

---

### High CPU/Memory Usage

**Symptom**: Syncthing uses a lot of resources.

**Cause 1: Large number of files**

```bash
# Check file count
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq -r '.globalFiles'
```

**Solution:** Reduce file count or increase scan interval:

Edit `hosts/common/home.nix`:

```nix
folders = {
  "sync" = {
    path = "/home/dustin/Sync";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;
    rescanIntervalS = 3600;  # Scan every hour instead of default (60 seconds)
  };
};
```

**Cause 2: Constant changes**

If files are constantly changing (e.g., logs, databases):

**Solution:** Add to ignore patterns:

```nix
folders = {
  "sync" = {
    path = "/home/dustin/Sync";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;
    ignorePatterns = [
      "*.log"
      "*.db-wal"
      "*.db-shm"
      ".git"
      "node_modules"
    ];
  };
};
```

**Cause 3: Large files**

Syncing very large files (GB+) can be CPU/memory intensive.

**Solution:** Use versioning or exclude large files:

```nix
ignorePatterns = [
  "*.iso"
  "*.vmdk"
  "*.vdi"
];
```

---

## Advanced Operations

### Changing Device ID

**Scenario**: You want to change a device's ID (e.g., after regenerating certificates).

**Warning**: This breaks existing connections. Other devices will see it as a new device.

**Step 1: Generate new identity**

Follow "Creating New Syncthing Identity" above.

**Step 2: Get new device ID**

```bash
# After deploying new identity
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'
```

**Step 3: Update hosts/common/home.nix**

```nix
"mischief" = {
  id = "NEW-DEVICE-ID-HERE";  # Update this
  addresses = [ "dynamic" ];
};
```

**Step 4: Rebuild all hosts**

```bash
# On each host
home-manager switch --flake .#dustin
```

**Step 5: Wait for reconnection**

Devices should automatically reconnect with new ID.

---

### Folder Versioning

**Enable versioning** to keep old versions of files when they're modified or deleted.

**Simple versioning (keep N versions):**

Edit `hosts/common/home.nix`:

```nix
folders = {
  "sync" = {
    path = "/home/dustin/Sync";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;

    versioning = {
      type = "simple";
      params = {
        keep = "5";  # Keep 5 versions
      };
    };
  };
};
```

**Staggered versioning (keep versions by age):**

```nix
versioning = {
  type = "staggered";
  params = {
    maxAge = "365";  # Keep for 1 year
  };
};
```

**Where versions are stored:**

```
~/Sync/.stversions/
```

**Restore a version:**

```bash
# List versions
ls -la ~/Sync/.stversions/

# Restore
cp ~/Sync/.stversions/old-version.txt ~/Sync/file.txt
```

---

### Ignoring Files

**Add ignore patterns** to exclude files from sync.

Edit `hosts/common/home.nix`:

```nix
folders = {
  "code" = {
    path = "/home/dustin/Code";
    devices = [ "mischief" "intrepid" "vigilant" ];
    ignorePerms = false;

    ignorePatterns = [
      # Version control
      ".git"
      ".svn"

      # Build artifacts
      "target"
      "node_modules"
      "dist"
      "__pycache__"

      # Temporary files
      "*.tmp"
      "*.swp"
      "*~"

      # OS files
      ".DS_Store"
      "Thumbs.db"

      # Logs
      "*.log"
    ];
  };
};
```

**Pattern syntax:**

- `*.ext`: Match files with extension
- `?`: Single character wildcard
- `path/to/file`: Match specific path
- `(?d)dirname`: Delete directory (don't sync)
- `(?i)pattern`: Case-insensitive
- `!pattern`: Negate (include this even if other patterns exclude it)

---

### Bandwidth Limits

**Limit bandwidth usage** for Syncthing.

Edit `hosts/common/home.nix`:

```nix
services.syncthing.settings = {
  options = {
    # Limit upload to 10 MB/s
    maxSendKbps = 10000;

    # Limit download to 20 MB/s
    maxRecvKbps = 20000;
  };
};
```

**Or per-device limits:**

```nix
devices = {
  "mischief" = {
    id = "DEVICE-ID";
    addresses = [ "dynamic" ];
    maxSendKbps = 5000;  # Limit to 5 MB/s
  };
};
```

---

## Best Practices

### DO:

- **Preserve device IDs during migration** (less hassle)
- **Back up Syncthing identities** before wiping systems
- **Use ignore patterns** to exclude build artifacts, temp files
- **Monitor sync status** regularly (check web UI)
- **Use versioning** for important folders (protection against accidental deletion)
- **Encrypt identities with sops-nix** (safe to commit to git)
- **Set up alerts** for sync errors (via systemd or monitoring)

### DON'T:

- **Sync version control repos** (.git/) - use git, not Syncthing
- **Sync databases** that are constantly changing (use proper replication)
- **Sync large media libraries** (consider using dedicated tools like rsync)
- **Share Syncthing identity between multiple devices** (one identity per device!)
- **Ignore errors** - fix them promptly
- **Commit plaintext key.pem/cert.pem** (use sops-nix encryption)

### Folder organization:

- `~/Sync`: Documents, notes, configs (frequently changing, small files)
- `~/Code`: Source code (but also use git for version control!)
- `~/Documents`: Larger documents (PDFs, spreadsheets)
- **Avoid**: OS directories (/etc, /usr, /var), databases, temp files

---

## Quick Reference

**Common commands:**

```bash
# Check service status
systemctl --user status syncthing

# Start/stop/restart
systemctl --user start syncthing
systemctl --user stop syncthing
systemctl --user restart syncthing

# Get device ID
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID'

# List connected devices
curl http://127.0.0.1:8384/rest/system/connections 2>/dev/null | jq -r '.connections | keys[]'

# Check folder sync status
curl http://127.0.0.1:8384/rest/db/status?folder=sync 2>/dev/null | jq -r '.state'

# Trigger folder rescan
curl -X POST http://127.0.0.1:8384/rest/db/scan?folder=sync

# View logs
journalctl --user -u syncthing -f

# Open web UI
xdg-open http://127.0.0.1:8384
```

**File locations:**

```
~/.local/state/syncthing/         Syncthing data directory
├── key.pem                        Private key (encrypted in git via sops)
├── cert.pem                       Public certificate (encrypted in git)
├── config.xml                     Configuration (auto-generated from home.nix)
└── index-*.db                     File index database

~/Sync/                            Shared folder 1
~/Code/                            Shared folder 2
```

**Web UI:**
- Local: http://127.0.0.1:8384
- Settings: Actions → Settings
- Device ID: Actions → Show ID
- Ignore patterns: Folder → Edit → Ignore Patterns
- Logs: Actions → Logs

---

## Additional Resources

- [Syncthing Documentation](https://docs.syncthing.net/)
- [Syncthing Forum](https://forum.syncthing.net/)
- [NixOS home-manager Syncthing options](https://nix-community.github.io/home-manager/options.html#opt-services.syncthing.enable)
- [sops-nix documentation](https://github.com/Mic92/sops-nix)
