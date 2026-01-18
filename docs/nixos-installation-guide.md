
# NixOS Installation Guide for Intrepid and Vigilant

This guide covers installing NixOS on the `intrepid` (desktop) and `vigilant` (Surface Laptop 4) hosts, then migrating to this dotfiles configuration. Both hosts are currently running Arch Linux and need to be completely reinstalled with NixOS.

## Table of Contents

- [Overview](#overview)
- [Pre-Installation Preparation](#pre-installation-preparation)
- [NixOS Installation](#nixos-installation)
- [Switching to This Configuration](#switching-to-this-configuration)
- [Post-Installation: sops-nix Setup](#post-installation-sops-nix-setup)
- [Post-Installation: Verification](#post-installation-verification)
- [Host-Specific Notes](#host-specific-notes)
- [Troubleshooting](#troubleshooting)

---

## Overview

**Target hosts:**
- **intrepid**: Desktop PC, AMD CPU/GPU, 32GB RAM, daily driver
- **vigilant**: Microsoft Surface Laptop 4, AMD CPU/GPU, 16GB RAM

**Current state:**
- Both hosts running Arch Linux
- Will be completely wiped and reinstalled with NixOS
- Configuration already exists in this repository (with placeholder hardware configs)

**Migration approach:**
1. Backup critical data (Syncthing identity, SSH keys, local files)
2. Create NixOS installation media
3. Boot from USB and install NixOS with minimal config
4. Clone this repository and switch to flake configuration
5. Set up sops-nix secrets (SSH keys, Syncthing identity)
6. Verify all services working

---

## Pre-Installation Preparation

**CRITICAL**: Complete ALL backup steps BEFORE wiping Arch Linux!

### 1. Backup Syncthing Identity

Syncthing device identities are unique and cannot be regenerated. Backup the identity files:

```bash
# On intrepid or vigilant (while still on Arch)
mkdir -p ~/nixos-migration-backup

# Backup Syncthing identity
cp ~/.local/state/syncthing/key.pem ~/nixos-migration-backup/
cp ~/.local/state/syncthing/cert.pem ~/nixos-migration-backup/

# Record device ID for verification
curl http://127.0.0.1:8384/rest/system/status 2>/dev/null | jq -r '.myID' > ~/nixos-migration-backup/device-id.txt
echo "Syncthing Device ID: $(cat ~/nixos-migration-backup/device-id.txt)"
```

**Verification:**
```bash
ls -la ~/nixos-migration-backup/
# Should show:
# -rw------- 1 dustin dustin  227 ... cert.pem
# -rw------- 1 dustin dustin  288 ... key.pem
# -rw-r--r-- 1 dustin dustin   64 ... device-id.txt
```

### 2. Backup SSH Keys (Optional)

If you have existing SSH keys you want to preserve:

```bash
# Backup SSH keys
cp ~/.ssh/id_ed25519 ~/nixos-migration-backup/
cp ~/.ssh/id_ed25519.pub ~/nixos-migration-backup/
```

**Note**: You can also generate new SSH keys on NixOS. If you do, update authorized_keys on servers where you use these keys.

### 3. Backup WiFi Passwords (Vigilant Only)

For the Surface Laptop, record current WiFi credentials:

```bash
# List saved networks
nmcli connection show

# For each network, extract password (replace "NetworkName")
nmcli connection show "NetworkName" | grep psk
```

**Note**: WiFi passwords will be managed by sops-nix. See [wifi-secrets.md](./wifi-secrets.md) for setup.

### 4. Copy Backups to Safe Location

Transfer backups to another machine or external storage:

```bash
# Option 1: Copy to mischief via SSH
scp -r ~/nixos-migration-backup dustin@mischief:~/intrepid-backup/

# Option 2: Copy to external USB drive
cp -r ~/nixos-migration-backup /media/usb-drive/

# Option 3: Upload to cloud storage (ensure it's encrypted!)
tar -czf nixos-migration-backup.tar.gz ~/nixos-migration-backup
age -p < nixos-migration-backup.tar.gz > nixos-migration-backup.tar.gz.age
# Upload nixos-migration-backup.tar.gz.age to cloud
```

**Verification checklist:**
- [ ] Syncthing key.pem and cert.pem backed up
- [ ] Syncthing device ID recorded
- [ ] SSH keys backed up (if preserving)
- [ ] WiFi passwords recorded (vigilant)
- [ ] Backups copied to mischief or external storage
- [ ] Backups verified readable

### 5. Document Current Hardware

Record current partition scheme (helpful for NixOS installation):

```bash
# List disks and partitions
lsblk -f

# Record disk layout
sudo fdisk -l > ~/nixos-migration-backup/disk-layout.txt

# Record hardware info
lspci > ~/nixos-migration-backup/hardware-lspci.txt
lsusb > ~/nixos-migration-backup/hardware-lsusb.txt
```

---

## NixOS Installation

### Recommended Installation Method

**Use the Minimal ISO** for both hosts.

**Why minimal over graphical:**
- Smaller download (~1GB vs ~3GB)
- Faster installation
- You'll be switching to this flake config immediately anyway
- Minimal ISO includes everything needed (terminal, network tools, partitioning utilities)

### 1. Download NixOS ISO

```bash
# On mischief or another machine
cd ~/Downloads

# Download NixOS 25.05 minimal ISO (stable release)
wget https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso

# Verify checksum (optional but recommended)
wget https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso.sha256
sha256sum -c latest-nixos-minimal-x86_64-linux.iso.sha256
```

**Latest downloads**: https://nixos.org/download#nixos-iso

### 2. Create Bootable USB

```bash
# Find USB drive device (usually /dev/sdb or /dev/sdc)
lsblk

# CAUTION: This will ERASE the USB drive!
# Replace /dev/sdX with your USB drive
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Eject safely
sudo eject /dev/sdX
```

**Verification**: USB drive should now have "NIXOS_ISO" label.

### 3. Boot from USB

1. Insert USB drive into target machine (intrepid or vigilant)
2. Reboot and enter BIOS/UEFI (usually F2, F12, DEL, or ESC during boot)
3. Disable Secure Boot (if enabled)
4. Set USB as first boot device
5. Save and exit

The NixOS installer should boot to a root shell.

### 4. Connect to Internet

**For wired connection** (intrepid):
```bash
# Should work automatically via DHCP
ping -c 3 nixos.org
```

**For WiFi** (vigilant):
```bash
# The NixOS minimal ISO uses wpa_supplicant, not iwd
# So use wpa_cli or wpa_passphrase (not iwctl)

# Find your wireless interface name
ip link
# Look for something like wlan0, wlp2s0, etc.

# Option 1: Quick one-liner approach
wpa_passphrase "YourNetworkName" "YourPassword" | sudo tee /etc/wpa_supplicant.conf
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
sudo dhcpcd wlan0

# Option 2: Interactive wpa_cli
sudo systemctl start wpa_supplicant
wpa_cli
# Inside wpa_cli:
> scan
> scan_results
> add_network
> set_network 0 ssid "YourNetworkName"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Get an IP address
sudo dhcpcd wlan0

# Verify connection
ping -c 3 nixos.org
```

### 5. Partition the Disk

**CAUTION**: This will ERASE all data on the disk!

**Recommended layout** (UEFI + GPT):

```bash
# Identify target disk (usually /dev/nvme0n1 or /dev/sda)
lsblk

# Start partitioning tool
sudo parted /dev/nvme0n1  # Or /dev/sda for SATA drives

# Inside parted:
(parted) mklabel gpt
(parted) mkpart ESP fat32 1MiB 512MiB
(parted) set 1 esp on
(parted) mkpart primary ext4 512MiB 100%
(parted) print  # Verify layout
(parted) quit
```

**Result:**
- `/dev/nvme0n1p1` (or `/dev/sda1`): 512 MiB EFI boot partition
- `/dev/nvme0n1p2` (or `/dev/sda2`): Remaining space for root filesystem

### 6. Format Partitions

```bash
# Format EFI partition
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format root partition
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

**For SSD drives**, enable TRIM:
```bash
sudo fstrim -v /dev/nvme0n1p2
```

### 7. Mount Partitions

```bash
# Mount root
sudo mount /dev/disk/by-label/nixos /mnt

# Create boot mount point
sudo mkdir -p /mnt/boot

# Mount EFI partition
sudo mount /dev/disk/by-label/boot /mnt/boot

# Verify mounts
lsblk
```

### 8. Generate Initial Configuration

```bash
# Generate hardware config and minimal configuration
sudo nixos-generate-config --root /mnt

# View generated config
cat /mnt/etc/nixos/configuration.nix
cat /mnt/etc/nixos/hardware-configuration.nix
```

### 9. Edit Initial Configuration (Optional)

For a smoother first boot, edit `/mnt/etc/nixos/configuration.nix`:

```bash
sudo nano /mnt/etc/nixos/configuration.nix
```

**Minimal changes needed:**
```nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network
  networking.hostName = "intrepid";  # Or "vigilant"
  networking.networkmanager.enable = true;  # Easy WiFi management

  # User account
  users.users.dustin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";  # CHANGE ON FIRST BOOT
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
  ];

  # Enable SSH (optional, for remote access)
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # Flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";
}
```

### 10. Install NixOS

```bash
# Run the installation
sudo nixos-install

# This will:
# - Build the system
# - Install bootloader
# - Set up initial configuration
# Takes 5-15 minutes depending on internet speed
```

**If asked to set root password**: Choose a secure password (you'll rarely need it).

### 11. Reboot

```bash
# Unmount filesystems
sudo umount -R /mnt

# Reboot
sudo reboot
```

Remove the USB drive during reboot. The system should boot into NixOS.

### 12. First Boot

1. At login prompt, login as `dustin` with the password you set ("changeme")
2. Change password immediately:
   ```bash
   passwd
   ```
3. Verify network connection:
   ```bash
   ping -c 3 nixos.org
   ```
4. If WiFi not connected (vigilant):
   ```bash
   nmcli device wifi list
   nmcli device wifi connect "NetworkName" password "YourPassword"
   ```

---

## Switching to This Configuration

Now that NixOS is installed with a minimal config, switch to this repository's configuration.

### 1. Install Git

```bash
# Enter temporary shell with git
nix-shell -p git
```

### 2. Clone This Repository

```bash
# Clone the dotfiles repo
cd ~
git clone https://github.com/your-username/nixos-dotfiles.git  # Update with actual URL

# Or if using SSH (after setting up SSH keys)
git clone git@github.com:your-username/nixos-dotfiles.git
```

**Alternative**: If you backed up the repo to mischief, copy it over:
```bash
scp -r dustin@mischief:~/nixos-dotfiles ~/
```

### 3. Generate Hardware Configuration

Generate the actual hardware config for this machine:

```bash
cd ~/nixos-dotfiles
sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
```

### 4. Compare and Update Hardware Config

Compare the generated config with the placeholder:

```bash
# View differences
diff /tmp/hardware-configuration.nix hosts/intrepid/hardware-configuration.nix
# Or for vigilant:
diff /tmp/hardware-configuration.nix hosts/vigilant/hardware-configuration.nix
```

**Update the repository's hardware config:**

```bash
# For intrepid:
cp /tmp/hardware-configuration.nix hosts/intrepid/hardware-configuration.nix

# For vigilant:
cp /tmp/hardware-configuration.nix hosts/vigilant/hardware-configuration.nix
```

**Important sections to verify:**
- `boot.initrd.availableKernelModules` - Kernel modules for boot
- `fileSystems."/"` - Root partition UUID
- `fileSystems."/boot"` - EFI partition UUID
- `networking.useDHCP` - Network settings
- `hardware.cpu.amd.updateMicrocode` - CPU microcode updates

### 5. First Rebuild

Build the system with this flake configuration:

```bash
cd ~/nixos-dotfiles

# For intrepid:
sudo nixos-rebuild switch --flake .#intrepid

# For vigilant:
sudo nixos-rebuild switch --flake .#vigilant
```

**This will:**
- Download and install all packages (Firefox, Qtile, Ghostty, etc.)
- Set up home-manager
- Configure the system according to hosts/common/ and hosts/{intrepid,vigilant}/
- Take 10-30 minutes depending on internet speed

**Errors you might see:**
- **sops-nix errors**: Expected! Secrets aren't set up yet. The build should still complete.
- **"collision between..."**: File conflicts, usually handled by home-manager's `backupFileExtension = "backup"`.

### 6. Reboot into New Configuration

```bash
sudo reboot
```

After reboot:
- **Display manager**: Ly login screen should appear
- **Login**: Use your password
- **Window manager**: Qtile should start automatically
- **Terminal**: Press `Super+Enter` to open Ghostty
- **Launcher**: Press `Super+Space` for Rofi

---

## Post-Installation: sops-nix Setup

Now configure secrets management for this host.

**Prerequisites:**
- Admin age key accessible (should be at `~/.config/sops/age/keys.txt` on mischief)
- Syncthing backup accessible (from Pre-Installation step)
- Repository cloned on the new host

**Recommendation**: Perform these steps from **mischief** to avoid juggling keys and backups.

### 1. Extract Host Age Key

On the new host (intrepid or vigilant):

```bash
# First, ensure SSH host keys exist (they may not if openssh wasn't enabled)
# Check if the key exists:
ls /etc/ssh/ssh_host_ed25519_key.pub

# If it doesn't exist, generate SSH host keys:
sudo ssh-keygen -A

# Extract age public key from SSH host key
# (ssh-to-age may not be installed yet, use nix-shell)
nix-shell -p ssh-to-age --run "sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"

# Copy this output (starts with "age1...")
```

**Alternative**: Extract remotely from mischief:
```bash
# From mischief
ssh dustin@intrepid "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age
```

### 2. Update Host Key in Repository

On mischief (or wherever you have the admin age key):

```bash
cd ~/nixos-dotfiles/secrets/keys/hosts

# For intrepid:
echo "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > intrepid.txt

# For vigilant:
echo "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > vigilant.txt
```

### 3. Update .sops.yaml

Edit `secrets/.sops.yaml` to add the host key reference and uncomment creation rules:

```bash
cd ~/nixos-dotfiles/secrets
nano .sops.yaml
```

**Changes needed:**

```yaml
keys:
  # Admin key (can decrypt everything)
  - &admin age10dggc9ndceshqs7zhljzjn72zch3ft9z3p0ynzfdvt5hd03l7pesvm3yp8

  # Host keys (derived from SSH host keys)
  - &mischief age1pldnhgr34hn375eufrrzlsv69qzwzjea3qhszlqkf73au0ruzflqp9yl9l
  - &intrepid $(cat keys/hosts/intrepid.txt)     # ADD THIS LINE
  - &vigilant $(cat keys/hosts/vigilant.txt)     # ADD THIS LINE (when setting up vigilant)

creation_rules:
  # ... existing rules ...

  # SSH keys for intrepid - UNCOMMENT THESE
  - path_regex: ssh/intrepid\.yaml$
    key_groups:
      - age:
          - *admin
          - *intrepid

  # Syncthing identity for intrepid - UNCOMMENT THESE
  - path_regex: syncthing/intrepid\.yaml$
    key_groups:
      - age:
          - *admin
          - *intrepid

  # (Same for vigilant when setting up that host)
```

### 4. Generate and Encrypt SSH Keys

**Option A: Generate new SSH keys**

```bash
cd ~/nixos-dotfiles/secrets

# Generate new key pair
ssh-keygen -t ed25519 -C "dustin@intrepid" -f /tmp/intrepid_ssh_key -N ""

# Create encrypted secret file
sops ssh/intrepid.yaml
```

In your editor, add:

```yaml
# SSH keys for intrepid
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [paste contents of /tmp/intrepid_ssh_key]
  -----END OPENSSH PRIVATE KEY-----

ssh_public_key: "ssh-ed25519 AAAA... dustin@intrepid"
```

Save and exit. sops will encrypt the file.

```bash
# Clean up temporary key
rm /tmp/intrepid_ssh_key /tmp/intrepid_ssh_key.pub
```

**Option B: Encrypt backed-up SSH keys**

If you backed up existing SSH keys and want to preserve them:

```bash
cd ~/nixos-dotfiles/secrets

# Retrieve backup from mischief (or external storage)
scp dustin@mischief:~/intrepid-backup/id_ed25519 /tmp/
scp dustin@mischief:~/intrepid-backup/id_ed25519.pub /tmp/

# Create encrypted secret file
sops ssh/intrepid.yaml
```

In editor:

```yaml
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [paste contents of /tmp/id_ed25519]
  -----END OPENSSH PRIVATE KEY-----

ssh_public_key: "[paste contents of /tmp/id_ed25519.pub]"
```

Save and exit.

```bash
# Clean up temporary files
shred -u /tmp/id_ed25519 /tmp/id_ed25519.pub
```

### 5. Encrypt Syncthing Identity

Retrieve the Syncthing backup:

```bash
# From mischief (or external storage)
scp dustin@mischief:~/intrepid-backup/key.pem /tmp/
scp dustin@mischief:~/intrepid-backup/cert.pem /tmp/
```

Encrypt the Syncthing identity:

```bash
cd ~/nixos-dotfiles/secrets
sops syncthing/intrepid.yaml
```

In editor:

```yaml
# Syncthing identity for intrepid
syncthing_key: |
  -----BEGIN EC PRIVATE KEY-----
  [paste contents of /tmp/key.pem]
  -----END EC PRIVATE KEY-----

syncthing_cert: |
  -----BEGIN CERTIFICATE-----
  [paste contents of /tmp/cert.pem]
  -----END CERTIFICATE-----
```

Save and exit.

```bash
# Clean up temporary files
shred -u /tmp/key.pem /tmp/cert.pem
```

**Verify encryption:**

```bash
# File should be encrypted
cat syncthing/intrepid.yaml
# Should show gibberish

# Decrypt to verify
sops -d syncthing/intrepid.yaml
# Should show your keys
```

### 6. Create secrets.nix for the Host

Copy mischief's secrets.nix as a template:

```bash
cd ~/nixos-dotfiles
cp hosts/mischief/secrets.nix hosts/intrepid/secrets.nix

# Edit for intrepid
nano hosts/intrepid/secrets.nix
```

**Update hostname throughout** (change "mischief" to "intrepid"):

```nix
{ config, ... }:

{
  # sops-nix configuration for intrepid
  sops = {
    # Default sops file for this host
    defaultSopsFile = ../../secrets/ssh/intrepid.yaml;

    # Validate sops files at build time
    validateSopsFiles = false;

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
        sopsFile = ../../secrets/ssh/intrepid.yaml;
        path = "/home/dustin/.ssh/id_ed25519";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # SSH public key
      "ssh_public_key" = {
        sopsFile = ../../secrets/ssh/intrepid.yaml;
        path = "/home/dustin/.ssh/id_ed25519.pub";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };

      # Syncthing private key
      "syncthing_key" = {
        sopsFile = ../../secrets/syncthing/intrepid.yaml;
        path = "/home/dustin/.local/state/syncthing/key.pem";
        owner = "dustin";
        group = "users";
        mode = "0600";
      };

      # Syncthing certificate
      "syncthing_cert" = {
        sopsFile = ../../secrets/syncthing/intrepid.yaml;
        path = "/home/dustin/.local/state/syncthing/cert.pem";
        owner = "dustin";
        group = "users";
        mode = "0644";
      };
    };
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /home/dustin/.ssh 0700 dustin users"
    "d /home/dustin/.local/state/syncthing 0700 dustin users"
  ];
}
```

### 7. Import secrets.nix in Host Configuration

Edit the host's main configuration to import secrets:

```bash
nano hosts/intrepid/configuration.nix
```

Add the import:

```nix
{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix  # ADD THIS LINE
  ];

  networking.hostName = "intrepid";
  # ... rest of config
}
```

### 8. Rebuild with Secrets

Copy the repository to the target host (if you were working on mischief):

```bash
# From mischief
cd ~/nixos-dotfiles
rsync -av --exclude '.git' . dustin@intrepid:~/nixos-dotfiles/
```

On the target host (intrepid):

```bash
cd ~/nixos-dotfiles
sudo nixos-rebuild switch --flake .#intrepid
```

**This rebuild should:**
- Generate the host's age key at `/var/lib/sops-nix/key.txt`
- Decrypt secrets using the host's age key
- Deploy secrets to specified paths (`~/.ssh/id_ed25519`, `~/.local/state/syncthing/`, etc.)

**Check for errors:**
```bash
# View rebuild output for sops errors
sudo journalctl -u sops-nix
```

### 9. Verify Secrets Deployed

Check that secrets were created:

```bash
# SSH keys
ls -la ~/.ssh/
# Should show:
# -rw------- 1 dustin users 411 ... id_ed25519
# -rw-r--r-- 1 dustin users  99 ... id_ed25519.pub

# Syncthing identity
ls -la ~/.local/state/syncthing/
# Should show:
# -rw------- 1 dustin users 227 ... key.pem
# -rw-r--r-- 1 dustin users 730 ... cert.pem

# Test SSH key
ssh-keygen -l -f ~/.ssh/id_ed25519.pub
# Should show key fingerprint
```

### 10. Commit Changes

From mischief or intrepid (wherever you have git configured):

```bash
cd ~/nixos-dotfiles
git add secrets/.sops.yaml
git add secrets/keys/hosts/intrepid.txt
git add secrets/ssh/intrepid.yaml
git add secrets/syncthing/intrepid.yaml
git add hosts/intrepid/secrets.nix
git add hosts/intrepid/configuration.nix
git add hosts/intrepid/hardware-configuration.nix
git commit -m "feat: add sops-nix secrets for intrepid"
git push
```

---

## Post-Installation: Verification

After secrets are deployed and the system rebuilt, verify everything works.

### 1. Verify SSH Keys

```bash
# Check key is loaded
ssh-add -l
# If no agent running:
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519

# Test SSH to a known server (e.g., GitHub)
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

### 2. Verify Syncthing

Start Syncthing:

```bash
# Syncthing should auto-start via home-manager
systemctl --user status syncthing

# If not running:
systemctl --user start syncthing
```

Access Syncthing web UI:

```bash
# Open browser to Syncthing UI
firefox http://127.0.0.1:8384
```

**Verify device ID matches backup:**

```bash
# In Syncthing UI: Actions > Show ID
# Compare with backed-up device ID:
cat ~/nixos-migration-backup/device-id.txt
```

**Should match!** If it matches, your Syncthing identity was successfully restored. Other devices will recognize this as the same device.

### 3. Verify WiFi Connection (Vigilant Only)

```bash
# Check connection
nmcli device status

# List saved networks
nmcli connection show

# Connect to a network
nmcli device wifi connect "NetworkName" password "YourPassword"
```

**Note**: For persistent WiFi password management, see [wifi-secrets.md](./wifi-secrets.md).

### 4. Verify Graphics/Display

Test graphics stack:

```bash
# Check GPU recognized
lspci | grep VGA

# For AMD GPUs
lspci | grep AMD

# Test Vulkan
vulkaninfo | grep deviceName

# Test OpenGL
glxinfo | grep "OpenGL renderer"
```

### 5. Verify Window Manager

Test Qtile keybindings:

- `Super+Enter`: Open terminal (Ghostty)
- `Super+Space`: Open launcher (Rofi)
- `Super+h/j/k/l`: Navigate windows (vim-style)
- `Super+Shift+q`: Close window
- `Super+Shift+r`: Restart Qtile
- `Super+Shift+e`: Exit Qtile

### 6. Verify Services

```bash
# Syncthing
systemctl --user status syncthing

# Bluetooth
systemctl status bluetooth

# Sound (PipeWire)
systemctl --user status pipewire
```

### 7. Verify evremap (Intrepid Only)

If you set up evremap for the RK-S70 keyboard on intrepid:

```bash
# Check service status
sudo systemctl status evremap

# Test key mappings
# (Type on RK-S70 keyboard and verify remappings work)
```

---

## Host-Specific Notes

### Intrepid (Desktop)

**Hardware:**
- AMD CPU/GPU
- 32GB RAM
- RK-S70 mechanical keyboard

**Configuration specifics:**

1. **AMD GPU drivers**: Already configured in `hosts/intrepid/configuration.nix`:
   ```nix
   hardware.graphics.enable = true;
   hardware.graphics.extraPackages = with pkgs; [ amdvlk ];
   environment.variables.AMD_VULKAN_ICD = "RADV";
   ```

2. **evremap for RK-S70 keyboard**: Add systemd service if using the RK-S70 keyboard:

   Edit `hosts/intrepid/configuration.nix`:

   ```nix
   { config, lib, pkgs, ... }:

   {
     imports = [
       ./hardware-configuration.nix
       ../common/configuration.nix
       ./secrets.nix
     ];

     networking.hostName = "intrepid";

     # AMD GPU support
     hardware.graphics.enable = true;
     hardware.graphics.extraPackages = with pkgs; [ amdvlk ];
     environment.variables.AMD_VULKAN_ICD = "RADV";

     # evremap for RK-S70 keyboard
     systemd.services.evremap = {
       description = "evdev key remapper";
       wantedBy = [ "multi-user.target" ];
       serviceConfig = {
         Type = "simple";
         ExecStart = "${pkgs.evremap}/bin/evremap remap /home/dustin/nixos-dotfiles/config/evremap/rk-s70.toml";
         Restart = "always";
         RestartSec = "1";
       };
     };
   }
   ```

   Then rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#intrepid
   sudo systemctl status evremap
   ```

3. **Multiple monitors**: If you have multiple monitors, configure in Qtile:
   - Edit `config/qtile/config.py`
   - See Qtile documentation for multi-monitor setup

**Verification:**
- AMD GPU driver loaded: `lspci -k | grep -A 3 VGA`
- Vulkan working: `vulkaninfo | head -20`
- evremap running: `sudo systemctl status evremap`

### Vigilant (Surface Laptop 4)

**Hardware:**
- AMD Ryzen CPU/GPU
- 16GB RAM
- Touchpad, touchscreen (optional)
- WiFi required

**Configuration specifics:**

1. **AMD GPU drivers**: Already configured in `hosts/vigilant/configuration.nix`.

2. **Touchpad**: Already configured:
   ```nix
   services.libinput.enable = true;
   services.libinput.touchpad = {
     tapping = true;
     naturalScrolling = true;
     disableWhileTyping = true;
   };
   ```

3. **WiFi**: Managed by NetworkManager:
   ```bash
   nmcli device wifi list
   nmcli device wifi connect "NetworkName" password "YourPassword"
   ```

   For persistent management, see [wifi-secrets.md](./wifi-secrets.md).

4. **Optional: linux-surface kernel**: If you need better Surface hardware support (touchscreen, cameras, etc.):

   Add to `hosts/vigilant/configuration.nix`:

   ```nix
   { config, lib, pkgs, ... }:

   {
     imports = [
       ./hardware-configuration.nix
       ../common/configuration.nix
       ./secrets.nix
       "${builtins.fetchTarball {
         url = "https://github.com/linux-surface/nixos-surface/archive/main.tar.gz";
       }}/module.nix"
     ];

     networking.hostName = "vigilant";

     # Surface-specific kernel and firmware
     microsoft-surface.ipts.enable = true;
     microsoft-surface.surface-control.enable = true;

     # ... rest of config
   }
   ```

   **Note**: This adds the linux-surface kernel patches. Only needed if touchscreen/cameras don't work with default kernel.

**Verification:**
- WiFi connected: `nmcli device status`
- Touchpad working: Test two-finger scroll, tap-to-click
- Battery info: `cat /sys/class/power_supply/BAT*/capacity`

---

## Troubleshooting

### NixOS Installation Issues

**Problem: Boot hangs at "Starting kernel..."**

**Solution**: Disable `quiet` boot option to see detailed logs:
1. At GRUB/systemd-boot menu, press `e` to edit boot entry
2. Remove `quiet` from kernel parameters
3. Press `Ctrl+x` to boot
4. Note the error message for debugging

---

**Problem: WiFi not working during installation**

**Solution**: Use USB tethering from phone:
1. Connect phone via USB
2. Enable USB tethering on phone
3. NixOS should detect and use the connection automatically

---

**Problem: Disk not found during partitioning**

**Solution**:
```bash
# List all disks
lsblk
ls /dev/disk/by-id/

# Use disk ID instead of /dev/sdX
sudo parted /dev/disk/by-id/nvme-Samsung_SSD_...
```

---

### Configuration Switch Issues

**Problem: "error: attribute 'intrepid' missing"**

**Cause**: Typo in hostname or flake not recognizing the host.

**Solution**:
```bash
cd ~/nixos-dotfiles
nix flake show
# Should list: intrepid, mischief, vigilant

# Check flake.nix has the host defined
grep -A 2 "intrepid" flake.nix
```

---

**Problem: "hash mismatch in fixed-output derivation"**

**Cause**: Downloaded package hash doesn't match expected hash (common with flakes).

**Solution**:
```bash
# Update flake lock
nix flake update

# Try rebuild again
sudo nixos-rebuild switch --flake .#intrepid
```

---

**Problem: Build fails with "insufficient space"**

**Cause**: Not enough disk space for Nix store.

**Solution**:
```bash
# Clean old generations
sudo nix-collect-garbage -d

# Check disk usage
df -h /nix/store
```

---

### sops-nix Issues

**Problem: "no key could decrypt the file"**

**Cause**: Host's age key not in `.sops.yaml` creation rules.

**Solution**:
```bash
cd ~/nixos-dotfiles/secrets

# Verify host key exists
cat keys/hosts/intrepid.txt

# Verify host key in .sops.yaml
grep "intrepid" .sops.yaml

# Re-encrypt the secret
sops updatekeys ssh/intrepid.yaml
```

---

**Problem: Secrets not deployed to expected paths**

**Cause**: Paths misconfigured in `secrets.nix` or directories don't exist.

**Solution**:
```bash
# Check secret deployment
sudo systemctl status sops-nix

# Check logs
sudo journalctl -u sops-nix -n 50

# Verify tmpfiles rules created directories
sudo systemctl status systemd-tmpfiles-setup

# Manually verify directory exists
ls -la ~/.ssh
ls -la ~/.local/state/syncthing
```

---

**Problem: "Failed to get data key"**

**Cause**: Secret file corrupted or encrypted with wrong keys.

**Solution**:
```bash
cd ~/nixos-dotfiles/secrets

# Try decrypting with admin key
sops -d ssh/intrepid.yaml

# If fails, re-create the secret
sops ssh/intrepid.yaml
# Paste keys again
```

---

### Syncthing Issues

**Problem: Syncthing shows different device ID than backup**

**Cause**: Wrong key.pem/cert.pem deployed.

**Solution**:
```bash
# Check deployed identity
cat ~/.local/state/syncthing/key.pem

# Compare with backup
cat ~/nixos-migration-backup/key.pem

# If different, re-encrypt the backup
cd ~/nixos-dotfiles/secrets
sops syncthing/intrepid.yaml
# Paste correct key.pem and cert.pem

# Rebuild
sudo nixos-rebuild switch --flake .#intrepid
```

---

**Problem: Syncthing won't start**

**Cause**: Service not enabled or dependency issue.

**Solution**:
```bash
# Check service status
systemctl --user status syncthing

# Enable and start
systemctl --user enable syncthing
systemctl --user start syncthing

# Check logs
journalctl --user -u syncthing -n 50
```

---

### Hardware Issues

**Problem: AMD GPU not detected**

**Cause**: Missing firmware or wrong drivers.

**Solution**:
```bash
# Verify GPU detected
lspci | grep VGA

# Check kernel modules loaded
lsmod | grep amdgpu

# If not loaded, add to configuration.nix:
boot.kernelModules = [ "amdgpu" ];
hardware.enableRedistributableFirmware = true;

# Rebuild
sudo nixos-rebuild switch --flake .#intrepid
```

---

**Problem: Touchpad not working (vigilant)**

**Cause**: libinput not configured or wrong driver.

**Solution**:
```bash
# Check libinput enabled
systemctl status libinput

# Test touchpad detected
libinput list-devices

# If not listed, check kernel modules
lsmod | grep input

# Force module load
sudo modprobe -v i2c_hid
```

---

### Recovery

**Problem: System won't boot after rebuild**

**Solution**: Boot into previous generation:

1. At boot menu (systemd-boot), select "NixOS - Previous Generation"
2. Boot into working configuration
3. Investigate error:
   ```bash
   sudo nixos-rebuild switch --flake .#intrepid --show-trace
   ```
4. Fix configuration and rebuild

---

**Problem: Forgot user password**

**Solution**: Reset from root:

1. Reboot and add `init=/bin/sh` to kernel parameters
2. At root shell:
   ```bash
   mount -o remount,rw /
   passwd dustin
   # Enter new password
   sync
   reboot -f
   ```

---

## Additional Resources

**Documentation:**
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [sops-nix Documentation](./sops-secrets.md) (this repository)
- [Syncthing Setup](./syncthing.md) (this repository)
- [WiFi Secrets Management](./wifi-secrets.md) (this repository)
- [SSH Keys Management](./ssh-keys.md) (this repository)

**External guides:**
- [NixOS Installation Guide](https://nixos.org/manual/nixos/stable/#sec-installation)
- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [linux-surface for NixOS](https://github.com/linux-surface/nixos-surface)

**Getting help:**
- NixOS Discourse: https://discourse.nixos.org/
- NixOS Wiki: https://nixos.wiki/
- /r/NixOS subreddit

---

## Quick Reference Checklist

**Pre-Installation:**
- [ ] Backup Syncthing identity (key.pem, cert.pem)
- [ ] Record Syncthing device ID
- [ ] Backup SSH keys (optional)
- [ ] Record WiFi passwords (vigilant)
- [ ] Copy backups to safe location
- [ ] Document disk layout

**Installation:**
- [ ] Download NixOS minimal ISO
- [ ] Create bootable USB
- [ ] Boot from USB
- [ ] Connect to internet
- [ ] Partition disk (512MB EFI + root)
- [ ] Format partitions
- [ ] Mount partitions
- [ ] Generate initial config
- [ ] Run nixos-install
- [ ] Reboot

**Configuration Switch:**
- [ ] Install git
- [ ] Clone dotfiles repository
- [ ] Generate hardware-configuration.nix
- [ ] Update repository's hardware config
- [ ] Run nixos-rebuild switch --flake
- [ ] Reboot

**sops-nix Setup:**
- [ ] Extract host age key
- [ ] Update secrets/keys/hosts/{hostname}.txt
- [ ] Update secrets/.sops.yaml
- [ ] Encrypt SSH keys
- [ ] Encrypt Syncthing identity
- [ ] Create hosts/{hostname}/secrets.nix
- [ ] Import secrets.nix in configuration.nix
- [ ] Rebuild system
- [ ] Verify secrets deployed

**Verification:**
- [ ] SSH keys working
- [ ] Syncthing device ID matches backup
- [ ] WiFi connected (vigilant)
- [ ] Graphics/GPU working
- [ ] Window manager (Qtile) working
- [ ] Services running (Syncthing, Bluetooth)
- [ ] evremap working (intrepid, if configured)

**Commit:**
- [ ] Add all changed files to git
- [ ] Commit with descriptive message
- [ ] Push to repository

---

**Estimated time:**
- Pre-installation backup: 15 minutes
- NixOS installation: 30-60 minutes
- Configuration switch: 20-40 minutes (download time varies)
- sops-nix setup: 30-45 minutes
- Verification: 15-30 minutes

**Total: 2-4 hours** (mostly waiting for downloads)

Good luck with the migration!
