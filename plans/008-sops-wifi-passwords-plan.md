# Implementation Plan: WiFi Password Management with sops-nix

## Overview

This plan extends the sops-nix infrastructure established in plan 007 to manage WiFi passwords for home networks. The implementation uses sops-nix templates to generate iwd network configuration files with encrypted passwords, ensuring WiFi credentials are:

1. **Encrypted at rest** in the git repository
2. **Declaratively managed** via NixOS configuration
3. **Automatically deployed** at system activation
4. **Shared across hosts** (1-2 home SSIDs used by all 3 machines)

### Integration with Plan 007

This plan assumes the base sops-nix infrastructure from plan 007 is already in place:
- sops-nix flake input added
- Age keys generated for mischief (and later intrepid/vigilant)
- `.sops.yaml` configuration file exists
- Admin age key backed up securely

### Architecture

```
nixos-dotfiles/
├── secrets/
│   ├── .sops.yaml                 # Add WiFi secret rules
│   └── wifi/
│       └── networks.yaml          # NEW: Encrypted WiFi passwords (shared by all hosts)
├── hosts/
│   ├── common/
│   │   └── wifi.nix               # NEW: Shared WiFi configuration module
│   └── mischief/
│       ├── configuration.nix      # Import wifi.nix
│       └── secrets.nix            # Add WiFi secret definitions
└── docs/
    └── wifi-secrets.md            # NEW: User documentation
```

---

## Prerequisites

### Assumptions
- Plan 007 is fully implemented for mischief
- sops-nix is configured and working
- iwd is enabled (`networking.wireless.iwd.enable = true`)
- Admin age key (`~/.config/sops/age/keys.txt`) exists and is backed up
- mischief's host age key is generated and stored in `/var/lib/sops-nix/key.txt`

### Required Information
Before starting, gather:
1. **WiFi SSID(s)**: Name of home network(s) (e.g., "MyHomeNet")
2. **WiFi Passphrase(s)**: WPA2/WPA3 password(s) (8-63 ASCII characters)
3. **Network naming**: How SSID will appear in filename (alphanumeric, spaces, underscores, hyphens = verbatim; else = hex encoded)

### Tools
Already available from plan 007:
- `sops` - for encrypting/editing secrets
- `age` - for encryption keys
- `nixos-rebuild` - for deploying changes

---

## Background: iwd Network Configuration

### iwd PSK File Format

iwd stores network credentials in `/var/lib/iwd/` as `.psk` files (for WPA2/WPA3 networks). The file format is INI-style:

```ini
[Security]
Passphrase=my_wifi_password_here
PreSharedKey=924179acd138039828674bb2339a4a2c95cce4a41deb934d99c00380d0be8490

[Settings]
AutoConnect=true
```

**Key points**:
- **File name**: `<ssid>.psk` (SSID verbatim if alphanumeric/space/underscore/hyphen, else `=<hex>.psk`)
- **Passphrase**: Plain text password (8-63 ASCII characters)
- **PreSharedKey**: Hex-encoded PSK (optional - iwd calculates automatically if omitted)
- **Permissions**: Must be readable by root/iwd service
- **Location**: `/var/lib/iwd/` (managed by systemd)

### NixOS and iwd Challenges

**Problem**: iwd has no native `PassphraseFile=` option to read passwords from external files.

**Solution**: Use sops-nix templates to generate the `.psk` file with embedded secrets at activation time.

### AMD Hardware Compatibility

Both intrepid (Desktop AMD) and vigilant (Surface Laptop 4 AMD) support iwd:
- iwd is **CPU/GPU agnostic** - it's a wireless daemon that works with WiFi chipsets, not graphics hardware
- AMD systems commonly use Intel, MediaTek, Qualcomm, or Realtek WiFi chips
- All modern WiFi chipsets supported by Linux kernel work with iwd
- **Conclusion**: iwd will work identically on mischief (Intel), intrepid (AMD), and vigilant (AMD)

---

## Implementation Steps

### Step 1: Create WiFi Secrets Directory

```bash
cd ~/nixos-dotfiles/secrets
mkdir -p wifi
```

### Step 2: Create Encrypted WiFi Secrets File

**Create and edit the encrypted secrets file:**

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

**In your editor, add WiFi credentials (YAML format):**

```yaml
# Home WiFi networks
# These credentials are shared across all hosts (mischief, intrepid, vigilant)

# Primary home network
home_wifi_passphrase: "YourActualWiFiPassword123"

# Optional: Secondary network (guest network, 5GHz separate SSID, etc.)
# guest_wifi_passphrase: "GuestNetworkPassword456"
```

**Save and exit** - sops will automatically encrypt the file.

**Verify encryption:**

```bash
# Should show encrypted gibberish
cat wifi/networks.yaml

# Should show plaintext YAML
sops -d wifi/networks.yaml
```

### Step 3: Update .sops.yaml Configuration

**Edit `/home/dustin/nixos-dotfiles/secrets/.sops.yaml`:**

Add a new creation rule for WiFi secrets. Since WiFi credentials are **shared across all hosts**, they should be decryptable by all host keys plus the admin key.

```yaml
# sops-nix configuration
# This file defines which age keys can decrypt which secrets

keys:
  # Admin key (can decrypt everything)
  - &admin age10dggc9ndceshqs7zhljzjn72zch3ft9z3p0ynzfdvt5hd03l7pesvm3yp8

  # Host keys (derived from SSH host keys)
  - &mischief age1pldnhgr34hn375eufrrzlsv69qzwzjea3qhszlqkf73au0ruzflqp9yl9l
  # intrepid and vigilant keys will be added after NixOS installation
  # - &intrepid age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  # - &vigilant age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

creation_rules:
  # SSH keys for mischief - decryptable by admin and mischief
  - path_regex: ssh/mischief\.yaml$
    key_groups:
      - age:
          - *admin
          - *mischief

  # Syncthing identity for mischief
  - path_regex: syncthing/mischief\.yaml$
    key_groups:
      - age:
          - *admin
          - *mischief

  # WiFi passwords - SHARED across all hosts
  # Decryptable by admin and all current hosts
  - path_regex: wifi/networks\.yaml$
    key_groups:
      - age:
          - *admin
          - *mischief
          # Uncomment as hosts are added:
          # - *intrepid
          # - *vigilant

  # (Keep existing rules for intrepid and vigilant - commented out until migration)
```

**Re-encrypt WiFi secrets with new rules:**

```bash
cd ~/nixos-dotfiles/secrets
sops updatekeys wifi/networks.yaml
```

### Step 4: Create WiFi Configuration Module

**Create `/home/dustin/nixos-dotfiles/hosts/common/wifi.nix`:**

This module will be shared by all hosts and generates iwd `.psk` files using sops-nix templates.

```nix
{ config, lib, pkgs, ... }:

{
  # WiFi configuration using sops-nix for password management
  # This module uses sops-nix templates to generate iwd network config files

  # Ensure iwd state directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/iwd 0700 root root -"
  ];

  # sops-nix secrets for WiFi passphrases
  sops.secrets = {
    # Home WiFi passphrase
    "home_wifi_passphrase" = {
      sopsFile = ../../secrets/wifi/networks.yaml;
      # This secret is only accessed via templates, so it doesn't need a path
      # It will be available via config.sops.placeholder."home_wifi_passphrase"
    };

    # Optional: Guest WiFi passphrase (uncomment if you have a second network)
    # "guest_wifi_passphrase" = {
    #   sopsFile = ../../secrets/wifi/networks.yaml;
    # };
  };

  # Generate iwd .psk files using sops-nix templates
  sops.templates = {
    # Primary home network
    # Replace "MyHomeNet" with your actual SSID
    "iwd-MyHomeNet.psk" = {
      content = ''
        [Security]
        Passphrase=${config.sops.placeholder."home_wifi_passphrase"}

        [Settings]
        AutoConnect=true
      '';
      # Deploy to iwd's state directory
      path = "/var/lib/iwd/MyHomeNet.psk";
      mode = "0600";
      owner = "root";
      group = "root";
    };

    # Optional: Guest network (uncomment and configure if needed)
    # "iwd-GuestNet.psk" = {
    #   content = ''
    #     [Security]
    #     Passphrase=${config.sops.placeholder."guest_wifi_passphrase"}
    #
    #     [Settings]
    #     AutoConnect=true
    #   '';
    #   path = "/var/lib/iwd/GuestNet.psk";
    #   mode = "0600";
    #   owner = "root";
    #   group = "root";
    # };
  };

  # Ensure iwd is enabled (redundant with common/configuration.nix, but explicit)
  networking.wireless.iwd = {
    enable = lib.mkDefault true;
    # Optional: Configure iwd settings
    settings = {
      General = {
        # Enable network configuration (DHCP)
        EnableNetworkConfiguration = true;
      };
      Network = {
        # Enable IPv6
        EnableIPv6 = true;
        # Use systemd-resolved for DNS
        NameResolvingService = "systemd";
      };
      Settings = {
        # Automatically connect to known networks
        AutoConnect = true;
      };
    };
  };

  # Ensure systemd-resolved is available for DNS
  services.resolved.enable = lib.mkDefault true;
}
```

**Important customization**:
- Replace `"MyHomeNet"` with your actual WiFi SSID in **three places**:
  1. Template name: `"iwd-MyHomeNet.psk"`
  2. File path: `"/var/lib/iwd/MyHomeNet.psk"`
  3. Comments (optional)

**SSID naming rules** (from iwd documentation):
- **Alphanumeric, spaces, underscores, hyphens**: Use verbatim (e.g., `MyHome-Net_5G.psk`)
- **Special characters**: Encode as `=<hex>.psk` (e.g., SSID `Café` → `=436166c3a9.psk`)
  ```bash
  # To hex-encode an SSID:
  echo -n "Café" | xxd -p -c 999
  # Output: 436166c3a9
  ```

### Step 5: Update mischief Configuration

**Edit `/home/dustin/nixos-dotfiles/hosts/mischief/configuration.nix`:**

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ../common/wifi.nix           # Add this line
    ./secrets.nix
  ];

  networking.hostName = "mischief";

  # evremap - laptop config (Caps Lock -> Ctrl/Escape)
  systemd.services.evremap = {
    description = "evdev key remapper";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.evremap}/bin/evremap remap /home/dustin/nixos-dotfiles/config/evremap/laptop.toml";
      Restart = "always";
      RestartSec = "1";
    };
  };
}
```

**Edit `/home/dustin/nixos-dotfiles/hosts/mischief/secrets.nix`:**

Update to reference WiFi secrets (for completeness, though templates handle them):

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

      # WiFi secrets are handled by hosts/common/wifi.nix via templates
      # No explicit secret definitions needed here
    };
  };

  # Ensure .ssh directory exists
  systemd.tmpfiles.rules = [
    "d /home/dustin/.ssh 0700 dustin users"
    "d /home/dustin/.local/state/syncthing 0700 dustin users"
  ];
}
```

### Step 6: Test Configuration Build

**Before rebuilding, test configuration validity:**

```bash
cd ~/nixos-dotfiles

# Check flake syntax
nix flake check

# Test build without activation (dry-run)
sudo nixos-rebuild dry-build --flake .#mischief
```

**Expected output**:
- No syntax errors
- Build completes successfully
- Shows what would be changed

### Step 7: Deploy to mischief

**Rebuild NixOS configuration:**

```bash
cd ~/nixos-dotfiles

# Apply configuration
sudo nixos-rebuild switch --flake .#mischief
```

**What happens during activation**:
1. sops-nix decrypts `secrets/wifi/networks.yaml` using mischief's age key
2. Extracts `home_wifi_passphrase` secret
3. Generates `/var/lib/iwd/MyHomeNet.psk` with the decrypted password
4. Sets correct permissions (0600, root:root)
5. iwd daemon detects the new network configuration
6. Auto-connects if the SSID is in range

### Step 8: Verify WiFi Configuration

**Check that the .psk file was created:**

```bash
# List iwd network files
sudo ls -la /var/lib/iwd/

# Should show: MyHomeNet.psk (or your SSID name)

# Verify permissions
sudo stat /var/lib/iwd/MyHomeNet.psk
# Should be: 0600 root root

# Check file contents (should show passphrase in plaintext)
sudo cat /var/lib/iwd/MyHomeNet.psk
```

**Expected output**:
```ini
[Security]
Passphrase=YourActualWiFiPassword123

[Settings]
AutoConnect=true
```

**Check iwd status:**

```bash
# Check iwd service is running
systemctl status iwd

# Use iwctl to check networks
iwctl station list        # List WiFi interfaces
iwctl station wlan0 show  # Show status (replace wlan0 with your interface)
iwctl known-networks list # List known networks (should show MyHomeNet)
```

**Test connection using impala TUI:**

```bash
# Launch impala WiFi manager
impala

# Should show MyHomeNet in the list
# If in range, it should auto-connect
# If not connected, select and press Enter to connect
```

### Step 9: Test Auto-connect on Reboot

**Reboot mischief:**

```bash
sudo reboot
```

**After reboot, verify WiFi connected automatically:**

```bash
# Check connection status
ip addr show wlan0     # Should have an IP address
ping -c 3 1.1.1.1      # Test internet connectivity
iwctl station wlan0 show  # Should show "connected" state
```

### Step 10: Commit Changes

**Stage and commit the WiFi configuration:**

```bash
cd ~/nixos-dotfiles

# Stage changes
git add secrets/.sops.yaml
git add secrets/wifi/networks.yaml
git add hosts/common/wifi.nix
git add hosts/mischief/configuration.nix
git add hosts/mischief/secrets.nix  # If modified

# Commit
git commit -m "Add WiFi password management with sops-nix

- Add encrypted WiFi credentials in secrets/wifi/networks.yaml
- Create wifi.nix module using sops-nix templates
- Generate iwd .psk files at activation time
- Configure iwd with AutoConnect and IPv6 support
- WiFi secrets shared across all hosts

Builds on plan 007 sops-nix infrastructure."

# Push to remote
git push
```

---

## Adding More WiFi Networks

### Scenario: Add a Guest Network or 5GHz SSID

**Step 1: Add passphrase to encrypted secrets**

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Add the new network:

```yaml
# Existing
home_wifi_passphrase: "YourActualWiFiPassword123"

# NEW: Guest network
guest_wifi_passphrase: "GuestNetworkPassword456"
```

Save and exit (sops encrypts automatically).

**Step 2: Update wifi.nix**

Edit `/home/dustin/nixos-dotfiles/hosts/common/wifi.nix`:

```nix
sops.secrets = {
  "home_wifi_passphrase" = {
    sopsFile = ../../secrets/wifi/networks.yaml;
  };

  # NEW: Add guest network secret
  "guest_wifi_passphrase" = {
    sopsFile = ../../secrets/wifi/networks.yaml;
  };
};

sops.templates = {
  "iwd-MyHomeNet.psk" = {
    # ... existing config ...
  };

  # NEW: Add guest network template
  "iwd-GuestNet.psk" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."guest_wifi_passphrase"}

      [Settings]
      AutoConnect=false  # Don't auto-connect to guest network
    '';
    path = "/var/lib/iwd/GuestNet.psk";
    mode = "0600";
    owner = "root";
    group = "root";
  };
};
```

**Step 3: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

**Step 4: Verify**

```bash
sudo ls -la /var/lib/iwd/
# Should now show: MyHomeNet.psk, GuestNet.psk

iwctl known-networks list
# Should list both networks
```

---

## Extending to intrepid and vigilant

### Prerequisites
- intrepid and vigilant must be running NixOS
- Their host age keys must be generated and added to `.sops.yaml`
- Plan 007 must be completed for those hosts

### Step 1: Update .sops.yaml for New Hosts

After intrepid/vigilant are installed and their age keys are added:

```yaml
keys:
  - &admin age10dggc9ndceshqs7zhljzjn72zch3ft9z3p0ynzfdvt5hd03l7pesvm3yp8
  - &mischief age1pldnhgr34hn375eufrrzlsv69qzwzjea3qhszlqkf73au0ruzflqp9yl9l
  - &intrepid age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # UPDATED
  - &vigilant age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # UPDATED

creation_rules:
  # ... existing rules ...

  # WiFi passwords - SHARED across all hosts
  - path_regex: wifi/networks\.yaml$
    key_groups:
      - age:
          - *admin
          - *mischief
          - *intrepid   # UNCOMMENT
          - *vigilant   # UNCOMMENT
```

**Re-encrypt WiFi secrets to include new hosts:**

```bash
cd ~/nixos-dotfiles/secrets
sops updatekeys wifi/networks.yaml
```

### Step 2: Import wifi.nix in Host Configurations

**For intrepid** (`hosts/intrepid/configuration.nix`):

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ../common/wifi.nix           # Add this line
    ./secrets.nix                # (Assume this exists from plan 007)
  ];

  networking.hostName = "intrepid";

  # AMD GPU support
  # ... existing config ...
}
```

**For vigilant** (`hosts/vigilant/configuration.nix`):

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ../common/wifi.nix           # Add this line
    ./secrets.nix                # (Assume this exists from plan 007)
  ];

  networking.hostName = "vigilant";

  # AMD GPU support
  # ... existing config ...
}
```

### Step 3: Rebuild on Each Host

**On intrepid:**
```bash
sudo nixos-rebuild switch --flake .#intrepid
```

**On vigilant:**
```bash
sudo nixos-rebuild switch --flake .#vigilant
```

### Step 4: Verify WiFi Works on All Hosts

On each host:

```bash
sudo ls -la /var/lib/iwd/
iwctl known-networks list
iwctl station wlan0 show  # Check connection
ping -c 3 1.1.1.1         # Test internet
```

---

## Updating WiFi Passwords

### Scenario: Your Home WiFi Password Changed

**Step 1: Update the encrypted secret**

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Edit the passphrase:

```yaml
home_wifi_passphrase: "NewWiFiPassword789"  # Update this line
```

Save and exit.

**Step 2: Rebuild on all hosts**

```bash
# On mischief:
sudo nixos-rebuild switch --flake .#mischief

# On intrepid:
sudo nixos-rebuild switch --flake .#intrepid

# On vigilant:
sudo nixos-rebuild switch --flake .#vigilant
```

**Note**: You can rebuild remotely if you have SSH access:

```bash
# From mischief, rebuild intrepid remotely:
nixos-rebuild switch --flake .#intrepid --target-host intrepid --use-remote-sudo
```

**Step 3: Reconnect to WiFi**

iwd should automatically reconnect with the new password. If not:

```bash
# Disconnect current connection
iwctl station wlan0 disconnect

# Reconnect (will use new password from updated .psk file)
iwctl station wlan0 connect MyHomeNet
```

---

## Removing WiFi Networks

### Scenario: Remove Guest Network

**Step 1: Remove from wifi.nix**

Edit `/home/dustin/nixos-dotfiles/hosts/common/wifi.nix`:

Delete or comment out:
- `sops.secrets."guest_wifi_passphrase"`
- `sops.templates."iwd-GuestNet.psk"`

**Step 2: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

**Step 3: Clean up .psk file**

The old file won't be automatically removed. Clean up manually:

```bash
sudo rm /var/lib/iwd/GuestNet.psk
```

**Step 4: (Optional) Remove from secrets file**

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Remove the line:
```yaml
guest_wifi_passphrase: "GuestNetworkPassword456"  # DELETE THIS
```

---

## Verification Checklist

After completing this plan:

- [ ] WiFi secrets encrypted in `secrets/wifi/networks.yaml`
- [ ] `.sops.yaml` includes WiFi creation rule
- [ ] `hosts/common/wifi.nix` module created
- [ ] mischief imports `../common/wifi.nix`
- [ ] Configuration builds without errors (`nix flake check`)
- [ ] mischief rebuilt successfully (`nixos-rebuild switch`)
- [ ] `/var/lib/iwd/MyHomeNet.psk` file exists with correct permissions (0600)
- [ ] WiFi auto-connects on boot
- [ ] `iwctl known-networks list` shows home network
- [ ] Internet connectivity works (`ping 1.1.1.1`)
- [ ] impala TUI shows the network and connection status
- [ ] Changes committed to git
- [ ] User documentation created in `docs/wifi-secrets.md`

---

## Troubleshooting

### iwd .psk File Not Created

**Symptom**: After rebuild, `/var/lib/iwd/MyHomeNet.psk` doesn't exist.

**Causes & Solutions**:

1. **sops-nix secret not decrypted**:
   ```bash
   # Check secret status
   sudo systemctl status sops-nix.service

   # Check sops-nix logs
   journalctl -u sops-nix.service -n 50
   ```

2. **Wrong SSID name in wifi.nix**:
   - Verify template `path` matches your SSID exactly
   - Check for special characters requiring hex encoding

3. **Permissions error**:
   ```bash
   # Manually create directory if missing
   sudo mkdir -p /var/lib/iwd
   sudo chmod 0700 /var/lib/iwd

   # Rebuild
   sudo nixos-rebuild switch --flake .#mischief
   ```

### WiFi Doesn't Auto-Connect

**Symptom**: .psk file exists but WiFi doesn't connect automatically.

**Solutions**:

1. **Check iwd service**:
   ```bash
   systemctl status iwd
   # If not running:
   sudo systemctl start iwd
   ```

2. **Verify network is in range**:
   ```bash
   iwctl station wlan0 scan
   iwctl station wlan0 get-networks
   ```

3. **Manually connect once**:
   ```bash
   iwctl station wlan0 connect MyHomeNet
   # After first manual connect, auto-connect should work
   ```

4. **Check AutoConnect setting**:
   ```bash
   sudo cat /var/lib/iwd/MyHomeNet.psk
   # Ensure it contains:
   # [Settings]
   # AutoConnect=true
   ```

### Password Visible in .psk File

**Symptom**: Concerned that password is in plaintext in `/var/lib/iwd/MyHomeNet.psk`.

**Explanation**: This is **expected and by design**:
- iwd requires the passphrase in plaintext to connect
- The file is protected by:
  - **Permissions**: 0600 (only root can read)
  - **Location**: `/var/lib/iwd/` (system directory)
  - **Boot**: tmpfs can be used for `/var/lib/iwd/` if desired (advanced)
- The **encryption** is in the git repo (`secrets/wifi/networks.yaml`)
- This is how iwd works - same as storing passwords in NetworkManager/wpa_supplicant

### sops: no key could decrypt the file

**Symptom**: Error during rebuild: "sops: no key could decrypt the file"

**Cause**: Host age key not in `.sops.yaml` for `wifi/networks.yaml`.

**Solution**:

```bash
# Check which keys can decrypt WiFi secrets
sops -d --verbose secrets/wifi/networks.yaml

# If mischief's key is missing, update .sops.yaml
cd ~/nixos-dotfiles/secrets

# Edit .sops.yaml to include mischief in WiFi rule
# Then re-encrypt:
sops updatekeys wifi/networks.yaml
```

### WiFi Works on mischief but Not on intrepid/vigilant

**Symptom**: After extending to intrepid/vigilant, WiFi doesn't work.

**Causes & Solutions**:

1. **Age keys not added to .sops.yaml**:
   - Verify intrepid/vigilant age keys are in `.sops.yaml`
   - Verify WiFi rule includes `*intrepid` and `*vigilant`
   - Re-encrypt: `sops updatekeys wifi/networks.yaml`

2. **wifi.nix not imported**:
   - Check `hosts/intrepid/configuration.nix` imports `../common/wifi.nix`
   - Check `hosts/vigilant/configuration.nix` imports `../common/wifi.nix`

3. **Different WiFi interface name**:
   - Some systems use `wlp2s0` instead of `wlan0`
   - Find interface: `ip link show | grep wl`
   - Use correct interface in `iwctl station <interface> show`

### Special Characters in SSID

**Symptom**: SSID has spaces, quotes, or special characters (e.g., "My Home's Wi-Fi").

**Solution 1: Alphanumeric/spaces/underscores/hyphens** (use verbatim):
```nix
# In wifi.nix:
"iwd-My_Home-Network.psk" = {
  content = ''...'';
  path = "/var/lib/iwd/My_Home-Network.psk";
};
```

**Solution 2: Special characters** (use hex encoding):

```bash
# Hex-encode SSID
echo -n "My Home's Wi-Fi" | xxd -p -c 999
# Output: 4d7920486f6d652773205769d246469

# Use =<hex>.psk format:
"iwd-myhomes-wifi.psk" = {
  content = ''...'';
  path = "/var/lib/iwd/=4d7920486f6d652773205769d246469.psk";
  # Note: = prefix and hex encoding
};
```

**Alternative**: Rename your WiFi SSID to avoid special characters.

---

## Security Considerations

### What's Encrypted
- ✅ `secrets/wifi/networks.yaml` - Encrypted with age, safe to commit to git
- ✅ WiFi password in transit (decrypted only at activation time)

### What's Not Encrypted
- ❌ `/var/lib/iwd/MyHomeNet.psk` - Plaintext on disk (protected by file permissions)
- ❌ WiFi traffic (unless you use VPN - outside scope of this plan)

### Threat Model

**Protected against**:
- ✅ Accidentally committing WiFi passwords to git in plaintext
- ✅ WiFi passwords visible in Nix store (they're not - templates handle at runtime)
- ✅ Unauthorized users on the system (file is 0600 root-only)

**Not protected against**:
- ❌ Root user on the system (root can read `/var/lib/iwd/*.psk`)
- ❌ Physical access attacker with root password
- ❌ Malicious NixOS modules (they run as root and can read secrets)

**Conclusion**: This approach is **secure for normal use cases**. It prevents accidental exposure and keeps secrets out of git/Nix store. For higher security, consider full disk encryption (LUKS) and secure boot (outside scope).

### Multi-Host Secret Sharing

**Design decision**: WiFi secrets are **shared across all hosts** (mischief, intrepid, vigilant).

**Implications**:
- All hosts can decrypt `secrets/wifi/networks.yaml`
- Compromise of **any host's age key** exposes WiFi passwords
- This is acceptable because:
  - All hosts are on the same home network anyway
  - WiFi passwords are relatively low-value secrets (can be changed easily)
  - Shared secrets simplify management (one password for all hosts)

**Alternative** (higher security, more complex):
- Store WiFi secrets per-host (`secrets/wifi/mischief.yaml`, etc.)
- Use different WiFi networks for different security zones
- Rotate WiFi passwords independently

For home use, shared WiFi secrets are **recommended** for simplicity.

---

## Alternative Approaches Considered

### Alternative 1: wpa_supplicant Instead of iwd

**Pros**:
- More mature and widely used
- Better NetworkManager integration
- More configuration options

**Cons**:
- More complex configuration
- No benefit for simple home WiFi use case
- Conflicts with iwd (can't run both)

**Decision**: Stick with **iwd** because:
- Already configured in the system (`networking.wireless.iwd.enable = true`)
- Simpler for basic WiFi use
- Works great with impala TUI
- Recommended in CLAUDE.md

### Alternative 2: Store PSK Instead of Passphrase

**Approach**: Store the pre-shared key (hex) instead of plaintext passphrase.

**Example**:
```bash
# Calculate PSK
wpa_passphrase "MyHomeNet" "MyPassword123" | grep psk=
# Output: psk=924179acd138039828674bb2339a4a2c95cce4a41deb934d99c00380d0be8490

# Store PSK in secrets
home_wifi_psk: "924179acd138039828674bb2339a4a2c95cce4a41deb934d99c00380d0be8490"

# Use in template
[Security]
PreSharedKey=${config.sops.placeholder."home_wifi_psk"}
```

**Pros**:
- Slightly more secure (PSK is salted with SSID)
- No plaintext password stored

**Cons**:
- PSK is SSID-specific (if SSID changes, must recalculate)
- More complex to manage
- Minimal security benefit (both require root to read)

**Decision**: Use **passphrase** because:
- Simpler to manage (human-readable password)
- iwd calculates PSK automatically if omitted
- Security difference is negligible for this threat model

### Alternative 3: impala Manual WiFi Management

**Approach**: Don't use sops-nix at all. Just use impala TUI to connect manually.

**Pros**:
- Zero configuration
- Works out of the box

**Cons**:
- Not declarative (defeats purpose of NixOS)
- Credentials not synced across hosts
- Must manually reconnect on each rebuild (if `/var/lib/iwd/` is wiped)
- No backup/version control of WiFi credentials

**Decision**: Use **sops-nix + templates** because:
- Declarative and version-controlled
- Consistent across hosts
- Survives system rebuilds
- Follows NixOS philosophy

---

## Success Criteria

This implementation is successful when:

- [ ] WiFi passwords are encrypted in `secrets/wifi/networks.yaml`
- [ ] `.sops.yaml` has creation rule for WiFi secrets
- [ ] `hosts/common/wifi.nix` module exists and generates iwd .psk files
- [ ] mischief connects to WiFi automatically on boot
- [ ] WiFi survives `nixos-rebuild switch` without manual reconnection
- [ ] `iwctl known-networks list` shows configured networks
- [ ] impala TUI displays network status correctly
- [ ] No plaintext passwords in git repository
- [ ] User can add new WiFi networks by editing one file (`secrets/wifi/networks.yaml`)
- [ ] User can update passwords and rebuild to apply changes
- [ ] Configuration extends cleanly to intrepid and vigilant
- [ ] Documentation in `docs/wifi-secrets.md` is complete and accurate

---

## Next Steps After Implementation

1. **Extend to intrepid and vigilant**:
   - Follow "Extending to intrepid and vigilant" section
   - Verify WiFi works on all three hosts

2. **Add more WiFi networks** (if needed):
   - Work networks (if you travel with laptops)
   - Coffee shop networks (if frequently used)
   - Mobile hotspot credentials

3. **Consider network-specific settings**:
   - Disable AutoConnect for public networks
   - Configure static IP for specific SSIDs
   - Set DNS servers per-network

4. **Explore advanced iwd features**:
   - WPA3-SAE support
   - 802.11r fast roaming
   - Network priority ordering

5. **Monitor WiFi performance**:
   ```bash
   iwctl station wlan0 show  # Connection quality
   journalctl -f -u iwd      # iwd logs
   ```

6. **Backup considerations**:
   - Admin age key already backed up (from plan 007)
   - WiFi passwords now in encrypted repo (safe)
   - Consider printing QR codes for phone WiFi access

---

## References

### iwd Documentation
- [iwd ArchWiki](https://wiki.archlinux.org/title/Iwd) - Comprehensive iwd documentation
- [iwd.network man page](https://manpages.ubuntu.com/manpages/focal/en/man5/iwd.network.5.html) - Network config file format
- [NixOS iwd Wiki](https://wiki.nixos.org/wiki/Iwd) - Official NixOS iwd documentation

### sops-nix Documentation
- [sops-nix GitHub](https://github.com/Mic92/sops-nix) - Official sops-nix repository
- [Secret Management on NixOS with sops-nix](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/) - Detailed guide
- [sops-nix templates](https://discourse.nixos.org/t/sops-nix-templates-in-config-file/40225) - Template examples

### NixOS Wireless Configuration
- [NixOS Discourse: iwd declarative wifi configs](https://discourse.nixos.org/t/iwd-declarative-wifi-configs-networks-credentials/11267) - Community discussion
- [NixOS Wireless Networks Manual](https://nlewo.github.io/nixos-manual-sphinx/configuration/wireless.xml.html) - Official manual

---

## Appendix: Complete File Listing

After completing this plan, you should have:

```
~/nixos-dotfiles/
├── flake.nix                        # (No changes - already has sops-nix from plan 007)
├── secrets/
│   ├── .sops.yaml                   # ✓ UPDATED: Add WiFi creation rule
│   ├── wifi/
│   │   └── networks.yaml            # ✓ NEW: Encrypted WiFi passwords
│   ├── keys/                        # (Exists from plan 007)
│   ├── ssh/                         # (Exists from plan 007)
│   └── syncthing/                   # (Exists from plan 007)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix        # (No changes - iwd already enabled)
│   │   ├── home.nix                 # (No changes)
│   │   └── wifi.nix                 # ✓ NEW: WiFi secrets + templates
│   ├── mischief/
│   │   ├── configuration.nix        # ✓ UPDATED: Import ../common/wifi.nix
│   │   ├── secrets.nix              # ✓ UPDATED: Comment about WiFi templates
│   │   └── hardware-configuration.nix  # (No changes)
│   ├── intrepid/
│   │   └── configuration.nix        # ✓ UPDATED: Import ../common/wifi.nix (after migration)
│   └── vigilant/
│       └── configuration.nix        # ✓ UPDATED: Import ../common/wifi.nix (after migration)
├── docs/
│   ├── wifi-secrets.md              # ✓ NEW: User-facing documentation
│   ├── sops-secrets.md              # (Exists from plan 007)
│   ├── ssh-keys.md                  # (Exists from plan 007)
│   └── syncthing.md                 # (Exists from plan 007)
└── plans/
    ├── 007-sops-nix-secrets-plan.md # (Exists - base infrastructure)
    └── 008-sops-wifi-passwords-plan.md  # ✓ THIS FILE
```

**Files created/modified**:
- Created: `secrets/wifi/networks.yaml`
- Created: `hosts/common/wifi.nix`
- Created: `docs/wifi-secrets.md`
- Created: `plans/008-sops-wifi-passwords-plan.md`
- Updated: `secrets/.sops.yaml`
- Updated: `hosts/mischief/configuration.nix`
- Updated: `hosts/mischief/secrets.nix` (minor comment addition)
- Updated: `hosts/intrepid/configuration.nix` (after migration)
- Updated: `hosts/vigilant/configuration.nix` (after migration)

---

## Timeline Estimate

**For mischief (first implementation)**:
- Step 1-2 (Create secrets): **5 minutes**
- Step 3 (Update .sops.yaml): **3 minutes**
- Step 4 (Create wifi.nix): **10 minutes** (replace SSID, customize settings)
- Step 5 (Update mischief config): **3 minutes**
- Step 6 (Test build): **2 minutes**
- Step 7 (Deploy): **3 minutes**
- Step 8-9 (Verify + test): **10 minutes**
- Step 10 (Commit): **3 minutes**
- **Total: ~40 minutes**

**For intrepid/vigilant (extension)**:
- Per host: **~10 minutes** (update .sops.yaml, rebuild, verify)
- Both hosts: **~20 minutes**

**Documentation**:
- Reading this plan: **20 minutes**
- Creating `docs/wifi-secrets.md`: **15 minutes** (covered in next section)

**Grand total**: ~1.5 hours for complete implementation across all hosts.

---

## Plan Completion

This plan is **ready for execution** when:

1. ✅ Plan 007 (sops-nix infrastructure) is fully implemented for mischief
2. ✅ Admin age key exists and is backed up
3. ✅ mischief's host age key is in `.sops.yaml`
4. ✅ You know your home WiFi SSID and password
5. ✅ User documentation (`docs/wifi-secrets.md`) is created

**Next actions**:
1. Review this plan
2. Create `docs/wifi-secrets.md` (see separate document)
3. Execute steps 1-10 on mischief
4. Verify success
5. Extend to intrepid/vigilant after their NixOS migration

---

**Plan Status**: ✅ READY FOR IMPLEMENTATION

**Dependencies**: Plan 007 (sops-nix secrets management)

**Target Hosts**: mischief (primary), intrepid (after migration), vigilant (after migration)

**Estimated Time**: 40 minutes (mischief only), 1.5 hours (all hosts)
