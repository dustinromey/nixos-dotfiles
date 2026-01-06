# WiFi Secrets Management

**Quick Reference for Managing WiFi Passwords with sops-nix**

This document provides copy-paste commands for common WiFi password management tasks. For implementation details and troubleshooting, see `/home/dustin/nixos-dotfiles/plans/008-sops-wifi-passwords-plan.md`.

---

## Overview

WiFi passwords are stored in encrypted YAML files using sops-nix and deployed as iwd network configuration files at system activation. This approach provides:

- **Encrypted storage** in git repository
- **Declarative configuration** via NixOS
- **Automatic deployment** to `/var/lib/iwd/`
- **Shared credentials** across all hosts (mischief, intrepid, vigilant)

### Architecture

```
secrets/wifi/networks.yaml  (encrypted)
    ↓ (sops-nix decrypts)
hosts/common/wifi.nix  (templates)
    ↓ (generates)
/var/lib/iwd/MyHomeNet.psk  (plaintext, root-only)
    ↓ (iwd reads)
Auto-connect to WiFi on boot
```

---

## Quick Start

### View Current WiFi Networks

```bash
# List configured networks
iwctl known-networks list

# Show current connection
iwctl station wlan0 show

# List network files
sudo ls -la /var/lib/iwd/
```

### Check WiFi Status

```bash
# View connection details
iwctl station wlan0 show

# Test internet connectivity
ping -c 3 1.1.1.1

# Use impala TUI
impala
```

---

## Common Tasks

### 1. Add a New WiFi Network

**Scenario**: Add a new home network (e.g., guest WiFi or 5GHz SSID)

#### Step 1: Add password to encrypted secrets

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Add the new network (your editor will open with decrypted YAML):

```yaml
# Existing network
home_wifi_passphrase: "YourCurrentPassword"

# New network (add this)
guest_wifi_passphrase: "GuestNetworkPassword456"
```

Save and exit (Ctrl+X in nano, :wq in vim).

#### Step 2: Update wifi.nix configuration

```bash
nvim ~/nixos-dotfiles/hosts/common/wifi.nix
```

Add the new secret definition:

```nix
sops.secrets = {
  "home_wifi_passphrase" = {
    sopsFile = ../../secrets/wifi/networks.yaml;
  };

  # NEW: Add this block
  "guest_wifi_passphrase" = {
    sopsFile = ../../secrets/wifi/networks.yaml;
  };
};
```

Add the new template (replace `GuestNet` with your actual SSID):

```nix
sops.templates = {
  # Existing template...
  "iwd-MyHomeNet.psk" = { ... };

  # NEW: Add this block
  "iwd-GuestNet.psk" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."guest_wifi_passphrase"}

      [Settings]
      AutoConnect=false  # Set to true for auto-connect
    '';
    path = "/var/lib/iwd/GuestNet.psk";
    mode = "0600";
    owner = "root";
    group = "root";
  };
};
```

#### Step 3: Rebuild system

```bash
cd ~/nixos-dotfiles
sudo nixos-rebuild switch --flake .#$(hostname)
```

#### Step 4: Verify network was added

```bash
# Check .psk file was created
sudo ls -la /var/lib/iwd/GuestNet.psk

# List known networks
iwctl known-networks list

# Connect manually (if AutoConnect=false)
iwctl station wlan0 connect GuestNet
```

#### Step 5: Commit changes

```bash
cd ~/nixos-dotfiles
git add secrets/wifi/networks.yaml hosts/common/wifi.nix
git commit -m "Add GuestNet WiFi network"
git push
```

---

### 2. Update WiFi Password

**Scenario**: Your WiFi password changed

#### Step 1: Update encrypted secret

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Edit the password:

```yaml
home_wifi_passphrase: "NewWiFiPassword789"  # Update this
```

Save and exit.

#### Step 2: Rebuild on all hosts

**On current host:**
```bash
cd ~/nixos-dotfiles
sudo nixos-rebuild switch --flake .#$(hostname)
```

**On other hosts (remotely):**
```bash
# From mischief, rebuild intrepid:
nixos-rebuild switch --flake .#intrepid --target-host intrepid --use-remote-sudo

# From mischief, rebuild vigilant:
nixos-rebuild switch --flake .#vigilant --target-host vigilant --use-remote-sudo
```

**Or SSH to each host:**
```bash
ssh intrepid
cd ~/nixos-dotfiles && sudo nixos-rebuild switch --flake .#intrepid
exit

ssh vigilant
cd ~/nixos-dotfiles && sudo nixos-rebuild switch --flake .#vigilant
exit
```

#### Step 3: Reconnect WiFi (if needed)

Usually auto-reconnects. If not:

```bash
iwctl station wlan0 disconnect
iwctl station wlan0 connect MyHomeNet
```

#### Step 4: Commit change

```bash
cd ~/nixos-dotfiles
git add secrets/wifi/networks.yaml
git commit -m "Update MyHomeNet WiFi password"
git push
```

---

### 3. Remove WiFi Network

**Scenario**: Remove an old or unused network

#### Step 1: Remove from wifi.nix

```bash
nvim ~/nixos-dotfiles/hosts/common/wifi.nix
```

Delete or comment out:
- The `sops.secrets."network_name_passphrase"` block
- The `sops.templates."iwd-NetworkName.psk"` block

#### Step 2: Rebuild

```bash
cd ~/nixos-dotfiles
sudo nixos-rebuild switch --flake .#$(hostname)
```

#### Step 3: Remove .psk file

```bash
sudo rm /var/lib/iwd/NetworkName.psk
```

#### Step 4: (Optional) Remove from secrets file

```bash
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml
```

Remove the line with the passphrase.

#### Step 5: Commit changes

```bash
cd ~/nixos-dotfiles
git add hosts/common/wifi.nix secrets/wifi/networks.yaml
git commit -m "Remove NetworkName WiFi configuration"
git push
```

---

### 4. View Encrypted WiFi Passwords

**On a host with decryption access:**

```bash
cd ~/nixos-dotfiles/secrets
sops -d wifi/networks.yaml
```

**Using admin key (from machine with admin key):**

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d secrets/wifi/networks.yaml
```

---

### 5. Test WiFi Configuration Without Rebuilding

**Scenario**: Test if secrets decrypt correctly before rebuild

```bash
# Test build without activation
cd ~/nixos-dotfiles
sudo nixos-rebuild dry-build --flake .#$(hostname)

# If successful, proceed with actual rebuild
sudo nixos-rebuild switch --flake .#$(hostname)
```

---

### 6. Handle SSID with Special Characters

**Scenario**: Your SSID has spaces, quotes, or special characters (e.g., "Café WiFi")

#### Option 1: Alphanumeric/spaces/underscores/hyphens (use verbatim)

If SSID is `My Home-Net_5G`:

```nix
"iwd-My Home-Net_5G.psk" = {
  content = ''...'';
  path = "/var/lib/iwd/My Home-Net_5G.psk";
};
```

#### Option 2: Special characters (use hex encoding)

If SSID is `Café WiFi`:

**Step 1: Hex-encode SSID**
```bash
echo -n "Café WiFi" | xxd -p -c 999
# Output: 4361666c8920576946692069
```

**Step 2: Use =<hex>.psk format in wifi.nix**
```nix
"iwd-cafe-wifi.psk" = {
  content = ''
    [Security]
    Passphrase=${config.sops.placeholder."cafe_wifi_passphrase"}

    [Settings]
    AutoConnect=true
  '';
  path = "/var/lib/iwd/=4361666c8920576946692069.psk";
  # Note: = prefix and hex encoding
  mode = "0600";
  owner = "root";
  group = "root";
};
```

**Alternative**: Rename your WiFi SSID to avoid special characters.

---

## Troubleshooting

### WiFi Doesn't Auto-Connect After Rebuild

**Quick fix:**

```bash
# Check iwd service
systemctl status iwd

# Restart iwd
sudo systemctl restart iwd

# Manual connect
iwctl station wlan0 connect MyHomeNet
```

**Verify configuration:**

```bash
# Check .psk file exists
sudo ls -la /var/lib/iwd/MyHomeNet.psk

# Check contents
sudo cat /var/lib/iwd/MyHomeNet.psk

# Should contain:
# [Security]
# Passphrase=YourPassword
# [Settings]
# AutoConnect=true
```

### .psk File Not Created After Rebuild

**Check sops-nix status:**

```bash
sudo systemctl status sops-nix.service
journalctl -u sops-nix.service -n 50
```

**Verify age key:**

```bash
# Check host age key exists
sudo test -f /var/lib/sops-nix/key.txt && echo "Age key exists" || echo "Age key missing"

# Check if host can decrypt WiFi secrets
cd ~/nixos-dotfiles
sops -d secrets/wifi/networks.yaml
```

**Manual fix:**

```bash
# Ensure iwd directory exists
sudo mkdir -p /var/lib/iwd
sudo chmod 0700 /var/lib/iwd

# Rebuild
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Wrong WiFi Password After Update

**Verify secret was updated:**

```bash
cd ~/nixos-dotfiles/secrets
sops -d wifi/networks.yaml | grep home_wifi_passphrase
```

**Check .psk file contents:**

```bash
sudo cat /var/lib/iwd/MyHomeNet.psk
# Verify Passphrase= line matches new password
```

**Force reconnect:**

```bash
iwctl station wlan0 disconnect
sleep 2
iwctl station wlan0 connect MyHomeNet
```

### Can't Edit secrets/wifi/networks.yaml

**Error**: `sops: no key could decrypt the file`

**Cause**: Your user doesn't have decryption access.

**Solution 1: Use on host with access**

```bash
# SSH to mischief (or any host with host age key)
ssh mischief

cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml  # Will decrypt with host key
```

**Solution 2: Use admin key**

```bash
# On machine with admin key (~/.config/sops/age/keys.txt)
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/wifi/networks.yaml
```

### Network Not Showing in iwctl

**Check interface name:**

```bash
# List WiFi interfaces
ip link show | grep wl

# If interface is wlp2s0 instead of wlan0:
iwctl station wlp2s0 show
iwctl station wlp2s0 get-networks
```

**Scan for networks:**

```bash
iwctl station wlan0 scan
sleep 5
iwctl station wlan0 get-networks
```

**Check if in range:**

```bash
# Known networks (configured)
iwctl known-networks list

# Available networks (in range)
iwctl station wlan0 get-networks
```

---

## Reference Commands

### WiFi Status

```bash
# Current connection
iwctl station wlan0 show

# Known (configured) networks
iwctl known-networks list

# Available (in range) networks
iwctl station wlan0 scan
iwctl station wlan0 get-networks

# Connection quality
iwctl station wlan0 show | grep -i rssi
```

### iwd Service

```bash
# Status
systemctl status iwd

# Restart
sudo systemctl restart iwd

# Logs
journalctl -u iwd -f

# Enable (if disabled)
sudo systemctl enable --now iwd
```

### Network Files

```bash
# List all network configs
sudo ls -la /var/lib/iwd/

# View network config
sudo cat /var/lib/iwd/MyHomeNet.psk

# Check permissions (should be 0600 root:root)
sudo stat /var/lib/iwd/MyHomeNet.psk
```

### impala TUI

```bash
# Launch WiFi manager TUI
impala

# Navigate:
#   ↑↓ - Select network
#   Enter - Connect/disconnect
#   r - Rescan
#   q - Quit
```

### sops-nix

```bash
# Edit encrypted secrets
cd ~/nixos-dotfiles/secrets
sops wifi/networks.yaml

# View decrypted secrets
sops -d wifi/networks.yaml

# Check which keys can decrypt
sops -d --verbose wifi/networks.yaml

# Re-encrypt with updated keys
sops updatekeys wifi/networks.yaml
```

### NixOS Rebuild

```bash
# Build and activate
sudo nixos-rebuild switch --flake .#$(hostname)

# Build without activation
sudo nixos-rebuild build --flake .#$(hostname)

# Test build (no changes)
sudo nixos-rebuild dry-build --flake .#$(hostname)

# Remote rebuild
nixos-rebuild switch --flake .#intrepid --target-host intrepid --use-remote-sudo
```

---

## File Locations

### Configuration Files (git-tracked)
- **Encrypted secrets**: `/home/dustin/nixos-dotfiles/secrets/wifi/networks.yaml`
- **WiFi module**: `/home/dustin/nixos-dotfiles/hosts/common/wifi.nix`
- **sops config**: `/home/dustin/nixos-dotfiles/secrets/.sops.yaml`

### Runtime Files (not in git)
- **iwd configs**: `/var/lib/iwd/*.psk` (generated by sops-nix templates)
- **Host age key**: `/var/lib/sops-nix/key.txt` (auto-generated from SSH host key)
- **Admin age key**: `~/.config/sops/age/keys.txt` (on admin machine only)

### Documentation
- **Implementation plan**: `/home/dustin/nixos-dotfiles/plans/008-sops-wifi-passwords-plan.md`
- **This file**: `/home/dustin/nixos-dotfiles/docs/wifi-secrets.md`
- **sops-nix guide**: `/home/dustin/nixos-dotfiles/docs/sops-secrets.md`

---

## Security Notes

### What's Encrypted
- ✅ `secrets/wifi/networks.yaml` - Encrypted in git with age
- ✅ WiFi passwords in transit (decrypted at activation only)

### What's Plaintext
- ⚠️ `/var/lib/iwd/*.psk` - Plaintext on disk (but protected by 0600 permissions)

### Access Control
- **Root**: Can read `/var/lib/iwd/*.psk` (required for iwd to work)
- **Regular users**: Cannot read `.psk` files (protected by permissions)
- **Git repository**: Passwords are encrypted (safe to push to remote)

### Best Practices
- ✅ Keep admin age key backed up securely (password manager, encrypted USB, etc.)
- ✅ Use strong WiFi passwords (WPA2/WPA3, 12+ characters)
- ✅ Rotate WiFi passwords periodically (especially if device is lost/stolen)
- ✅ Use different passwords for guest networks
- ❌ Don't commit unencrypted passwords to git
- ❌ Don't share admin age key via insecure channels (email, Slack, etc.)

---

## Advanced Usage

### Add Work WiFi on Specific Host Only

If you only want a network on one host (e.g., work WiFi on mischief):

**Option 1: Host-specific wifi module**

```bash
# Create host-specific config
nvim ~/nixos-dotfiles/hosts/mischief/wifi-work.nix
```

```nix
{ config, ... }:
{
  sops.secrets."work_wifi_passphrase" = {
    sopsFile = ../../secrets/wifi/mischief-work.yaml;
  };

  sops.templates."iwd-WorkNet.psk" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."work_wifi_passphrase"}
      [Settings]
      AutoConnect=false
    '';
    path = "/var/lib/iwd/WorkNet.psk";
    mode = "0600";
  };
}
```

Import in `hosts/mischief/configuration.nix`:
```nix
imports = [
  ./wifi-work.nix  # Add this
];
```

**Option 2: Conditional in common wifi.nix**

```nix
# In hosts/common/wifi.nix
sops.templates = lib.mkIf (config.networking.hostName == "mischief") {
  "iwd-WorkNet.psk" = { ... };
};
```

### Configure Static IP for WiFi

```nix
# In hosts/common/wifi.nix template
"iwd-MyHomeNet.psk" = {
  content = ''
    [Security]
    Passphrase=${config.sops.placeholder."home_wifi_passphrase"}

    [Settings]
    AutoConnect=true

    [IPv4]
    Address=192.168.1.100
    Netmask=255.255.255.0
    Gateway=192.168.1.1
    DNS=1.1.1.1
  '';
  path = "/var/lib/iwd/MyHomeNet.psk";
  mode = "0600";
};
```

### Use Pre-Shared Key Instead of Passphrase

**Generate PSK:**
```bash
nix-shell -p wpa_supplicant
wpa_passphrase "MyHomeNet" "MyPassword123" | grep "psk="
# Output: psk=924179acd138039828674bb2339a4a2c95cce4a41deb934d99c00380d0be8490
```

**Store PSK in secrets:**
```bash
sops secrets/wifi/networks.yaml
```

```yaml
home_wifi_psk: "924179acd138039828674bb2339a4a2c95cce4a41deb934d99c00380d0be8490"
```

**Use PSK in template:**
```nix
"iwd-MyHomeNet.psk" = {
  content = ''
    [Security]
    PreSharedKey=${config.sops.placeholder."home_wifi_psk"}

    [Settings]
    AutoConnect=true
  '';
  # ...
};
```

**Note**: PSK is SSID-specific. If you rename your network, you must regenerate the PSK.

### Temporary WiFi Connection (No Persistence)

For one-time connections (coffee shops, hotels):

```bash
# Connect manually (won't create .psk file)
iwctl station wlan0 connect CoffeeShopWiFi

# Enter password when prompted

# Later, forget network
iwctl known-networks forget CoffeeShopWiFi
```

---

## FAQ

### Q: Why are passwords stored in plaintext in `/var/lib/iwd/`?

**A**: This is how iwd works. It requires plaintext passphrases to establish WiFi connections. The security comes from:
- File permissions (0600, root-only)
- Encrypted storage in git (`secrets/wifi/networks.yaml`)
- This is standard for all WiFi managers (NetworkManager, wpa_supplicant do the same)

### Q: Can I use this with NetworkManager instead of iwd?

**A**: No, this plan is iwd-specific. NetworkManager uses a different config format (`/etc/NetworkManager/system-connections/`). You'd need to adapt the sops-nix template to generate NetworkManager INI files instead.

### Q: What if I lose my admin age key?

**A**: You can still decrypt WiFi secrets using the host age keys (on each host). But you won't be able to edit secrets from machines without host access. This is why **backing up the admin key is critical** (see `docs/sops-secrets.md`).

### Q: Can I share WiFi passwords with family/roommates?

**A**: Yes, use one of these methods:
1. **QR code**: Generate a QR code from the SSID+password (most phones scan QR codes for WiFi)
2. **Print**: Print the SSID and password on paper
3. **Verbally**: Just tell them the password (it's for home WiFi, not a secret service)

### Q: How do I connect to WPA2 Enterprise (eduroam, university WiFi)?

**A**: WPA2 Enterprise uses 802.1x authentication (username/password or certificates), not PSK. This is more complex and requires a different iwd config format (`.8021x` files). Not covered in this plan.

### Q: Will WiFi work before NixOS fully boots?

**A**: No. sops-nix decrypts secrets during system activation, which happens after boot. If you need WiFi during boot (e.g., for SSH unlock of encrypted root), you'll need to embed the password in the initrd (advanced, not covered here).

### Q: Does this work with WPA3?

**A**: Yes! iwd supports WPA3-SAE. Use the same configuration - iwd will automatically use WPA3 if the network supports it.

---

## Getting Help

### Check Logs

```bash
# iwd logs
journalctl -u iwd -f

# sops-nix logs
journalctl -u sops-nix.service -n 50

# System activation logs
journalctl -b -u nixos-rebuild-switch.service
```

### Debug Mode

```bash
# Run iwctl with verbose output
iwctl --debug

# Check iwd configuration
systemctl cat iwd

# View effective iwd settings
ls -la /var/lib/iwd/
sudo cat /var/lib/iwd/*.psk
```

### Further Reading

- **Implementation plan**: `/home/dustin/nixos-dotfiles/plans/008-sops-wifi-passwords-plan.md`
- **sops-nix guide**: `/home/dustin/nixos-dotfiles/docs/sops-secrets.md`
- **iwd ArchWiki**: https://wiki.archlinux.org/title/Iwd
- **sops-nix GitHub**: https://github.com/Mic92/sops-nix
- **NixOS iwd options**: https://search.nixos.org/options?query=networking.wireless.iwd

---

**Last Updated**: 2026-01-06

**Plan Status**: ✅ Ready for use (after implementing plan 008)

**Applies to**: mischief, intrepid, vigilant (after NixOS migration)
