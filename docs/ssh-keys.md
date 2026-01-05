# SSH Key Management Guide

This guide covers the complete lifecycle of SSH keys in the Romey NixOS dotfiles repository, including generation, deployment, rotation, and revocation.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Normal Operations](#normal-operations)
  - [Adding SSH Key to GitHub](#adding-ssh-key-to-github)
  - [Adding SSH Key to Remote Server](#adding-ssh-key-to-remote-server)
  - [Using SSH Keys](#using-ssh-keys)
- [Key Rotation](#key-rotation)
  - [Rotating a Host's SSH Key](#rotating-a-hosts-ssh-key)
  - [Emergency Key Rotation](#emergency-key-rotation)
- [Host Management](#host-management)
  - [Adding a New Host](#adding-a-new-host)
  - [Removing a Host](#removing-a-host)
- [Revocation and Recovery](#revocation-and-recovery)
  - [Revoking a Key from GitHub](#revoking-a-key-from-github)
  - [Revoking a Key from Remote Servers](#revoking-a-key-from-remote-servers)
  - [Recovering from Compromised Key](#recovering-from-compromised-key)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

**Per-host SSH keys** means each NixOS host (mischief, intrepid, vigilant) has its own unique SSH key pair. This provides:

- **Security isolation**: Compromising one host doesn't expose others
- **Audit trail**: Know which host accessed what
- **Granular revocation**: Revoke one host's access without affecting others

**Key storage:**
- Private keys: Encrypted in git using sops-nix (`secrets/ssh/*.yaml`)
- Public keys: Can be plaintext in repo or extracted from encrypted files
- Deployed location: `~/.ssh/id_ed25519` (private), `~/.ssh/id_ed25519.pub` (public)

**Key types used:**
- **ed25519**: Modern, secure, fast (256-bit security)
- **RSA 4096**: Legacy, if needed for compatibility (avoid if possible)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Git Repository                          │
│                                                             │
│  secrets/ssh/                                               │
│  ├── mischief.yaml   ← Encrypted private + public key      │
│  ├── intrepid.yaml   ← Encrypted private + public key      │
│  └── vigilant.yaml   ← Encrypted private + public key      │
│                                                             │
│  hosts/*/secrets.nix  ← Deployment configuration           │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    nixos-rebuild switch
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       NixOS Host                            │
│                                                             │
│  /run/secrets/                                              │
│  ├── ssh_private_key  → symlink → ~/.ssh/id_ed25519        │
│  └── ssh_public_key   → symlink → ~/.ssh/id_ed25519.pub    │
│                                                             │
│  Permissions: 600 (private), 644 (public)                  │
│  Owner: dustin                                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
              Used for: git, ssh, scp, rsync, etc.
```

---

## Normal Operations

### Adding SSH Key to GitHub

After deploying SSH keys to a host, add the public key to GitHub:

**Step 1: Get the public key**

```bash
# On the host (e.g., mischief)
cat ~/.ssh/id_ed25519.pub
```

Copy the entire line (starts with `ssh-ed25519 AAAA...`).

**Step 2: Add to GitHub**

1. Go to https://github.com/settings/keys
2. Click "New SSH key"
3. Title: `mischief` (or the hostname)
4. Key type: "Authentication Key"
5. Paste the public key
6. Click "Add SSH key"

**Step 3: Test**

```bash
ssh -T git@github.com
# Should output: Hi <username>! You've successfully authenticated...
```

**Step 4: Configure git to use SSH**

```bash
# Change remote from HTTPS to SSH
cd ~/nixos-dotfiles
git remote set-url origin git@github.com:username/nixos-dotfiles.git

# Verify
git remote -v
# Should show: git@github.com:username/nixos-dotfiles.git
```

**Step 5: Test git operations**

```bash
git pull
git push
# Should work without password prompts
```

---

### Adding SSH Key to Remote Server

**Method 1: Using ssh-copy-id (easiest)**

```bash
# From the host (e.g., mischief)
ssh-copy-id dustin@remote-server.com

# Enter password when prompted
# Your public key is now in ~/.ssh/authorized_keys on the remote server
```

**Method 2: Manual copy**

```bash
# Get public key
cat ~/.ssh/id_ed25519.pub

# Copy it

# SSH to remote server (with password)
ssh dustin@remote-server.com

# On remote server, add to authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... dustin@mischief" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit

# Test
ssh dustin@remote-server.com
# Should log in without password
```

**Method 3: Using Ansible/automation**

If you manage servers with Ansible:

```yaml
# playbook.yml
- name: Add SSH public key for mischief
  authorized_key:
    user: dustin
    key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
    state: present
```

---

### Using SSH Keys

**Git operations:**

```bash
git clone git@github.com:username/repo.git
git pull
git push
```

**SSH to servers:**

```bash
ssh dustin@example.com
scp file.txt dustin@example.com:~/
rsync -av ~/dir/ dustin@example.com:~/dir/
```

**VS Code Remote SSH:**

1. Install "Remote - SSH" extension
2. Command Palette → "Remote-SSH: Connect to Host"
3. Enter `dustin@example.com`
4. VS Code will use your SSH key automatically

**SSH config for aliases:**

Edit `~/.ssh/config` (or add to home-manager):

```
Host myserver
  HostName example.com
  User dustin
  IdentityFile ~/.ssh/id_ed25519

Host github
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
```

Then use:

```bash
ssh myserver  # Instead of ssh dustin@example.com
```

---

## Key Rotation

### Rotating a Host's SSH Key

**When to rotate:**
- Regularly (every 1-2 years as best practice)
- After a security incident
- When moving to a new server
- When key is potentially exposed

**Step 1: Generate new key**

```bash
# On your admin machine (mischief), not the target host
ssh-keygen -t ed25519 -C "dustin@mischief" -f /tmp/mischief_new_key -N ""

# This creates:
# /tmp/mischief_new_key       (private)
# /tmp/mischief_new_key.pub   (public)
```

**Step 2: Encrypt the new key**

```bash
cd ~/nixos-dotfiles/secrets
sops ssh/mischief.yaml
```

Replace the `ssh_private_key` and `ssh_public_key` fields with the new key:

```yaml
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [new private key content]
  -----END OPENSSH PRIVATE KEY-----

ssh_public_key: "ssh-ed25519 AAAA[new public key] dustin@mischief"
```

Save and exit.

**Step 3: Deploy the new key**

```bash
# On mischief
cd ~/nixos-dotfiles
git pull  # Get the updated secret

sudo nixos-rebuild switch --flake .#mischief
```

**Step 4: Verify deployment**

```bash
cat ~/.ssh/id_ed25519.pub
# Should show the new public key
```

**Step 5: Update GitHub**

1. Go to https://github.com/settings/keys
2. Find the old "mischief" key
3. Click "Delete"
4. Add the new key (see "Adding SSH Key to GitHub")

**Step 6: Update remote servers**

For each server that had the old key:

```bash
# Copy new key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub dustin@remote-server.com

# Then remove old key (if different)
# On remote server:
ssh dustin@remote-server.com
nano ~/.ssh/authorized_keys
# Remove the old key line, keep the new one
```

**Step 7: Test everything**

```bash
# Test GitHub
ssh -T git@github.com

# Test remote servers
ssh dustin@server1.com
ssh dustin@server2.com

# Test git operations
cd ~/nixos-dotfiles
git pull
```

**Step 8: Clean up**

```bash
# Remove temporary key files
rm /tmp/mischief_new_key /tmp/mischief_new_key.pub
```

**Step 9: Commit**

```bash
cd ~/nixos-dotfiles
git add secrets/ssh/mischief.yaml
git commit -m "Rotate SSH key for mischief"
git push
```

---

### Emergency Key Rotation

**Scenario**: You suspect a host's SSH key has been compromised.

**IMMEDIATE ACTIONS (within 1 hour):**

**1. Revoke key from critical services:**

```bash
# Remove from GitHub (highest priority)
# Go to https://github.com/settings/keys
# Delete the compromised key

# Remove from servers with sensitive access
ssh root@important-server.com
sed -i '/mischief/d' ~/.ssh/authorized_keys
# Or edit manually: nano ~/.ssh/authorized_keys
```

**2. Disable the host (if still compromised):**

```bash
# Disconnect from network
sudo systemctl stop NetworkManager
sudo ip link set down eth0  # Or relevant interface

# Or shut down entirely
sudo poweroff
```

**3. Generate and deploy new key immediately:**

Follow "Rotating a Host's SSH Key" steps above, but expedited:

```bash
# Generate new key
ssh-keygen -t ed25519 -C "dustin@mischief-emergency" -f /tmp/emergency_key -N ""

# Encrypt
cd ~/nixos-dotfiles/secrets
sops ssh/mischief.yaml
# Paste new key

# If host is still accessible and not compromised
sudo nixos-rebuild switch --flake .#mischief

# If host is compromised, don't deploy yet
# Rebuild from scratch (see below)
```

**4. Audit access:**

Check GitHub:
```bash
# View recent authentication logs
# GitHub → Settings → Security log
# Look for any unexpected access from the compromised key
```

Check servers:
```bash
# On each server, check auth logs
ssh server.com
sudo grep "mischief" /var/log/auth.log
sudo last -f /var/log/wtmp | grep dustin
```

**5. Rebuild host from scratch (if compromised):**

If you suspect the host itself is compromised:

```bash
# 1. Backup important data
# 2. Reinstall NixOS
# 3. Deploy with new key
# 4. Do NOT restore ~/.ssh/ from backup
```

**FOLLOW-UP ACTIONS (within 24 hours):**

**1. Rotate all secrets for that host:**

```bash
# Rotate Syncthing identity (if Syncthing data is sensitive)
# See docs/syncthing.md

# Rotate any API tokens or passwords stored for that host
cd ~/nixos-dotfiles/secrets
sops api/mischief-tokens.yaml
# Change all tokens
```

**2. Review and update all servers:**

```bash
# Make a list of all servers the compromised key had access to
# Manually verify each one no longer accepts the old key

# Test with old key (should FAIL):
ssh -i /tmp/old_key_backup dustin@server.com
# Connection should be refused

# Test with new key (should SUCCEED):
ssh dustin@server.com
```

**3. Document the incident:**

```bash
# Create incident report
cat > ~/nixos-dotfiles/docs/incidents/YYYY-MM-DD-mischief-key-compromise.md <<EOF
# SSH Key Compromise Incident - mischief

**Date**: $(date)
**Host**: mischief
**Severity**: High/Medium/Low

## Timeline
- XX:XX - Detected suspicious activity
- XX:XX - Revoked key from GitHub
- XX:XX - Revoked key from servers
- XX:XX - Deployed new key

## Impact
- GitHub access: [compromised/not compromised]
- Server access: [list servers affected]
- Data exposure: [describe any data potentially exposed]

## Actions Taken
1. Revoked old key from GitHub
2. Removed from servers: [list]
3. Generated and deployed new key
4. Audited access logs

## Lessons Learned
[What could be improved]

## Follow-up
- [ ] Monitor for further suspicious activity (1 week)
- [ ] Review access patterns (1 month)
- [ ] Update incident response procedures
EOF
```

**4. Update procedures:**

If this revealed gaps in security:
- Update this documentation
- Improve monitoring
- Consider additional security measures (2FA, hardware keys, etc.)

---

## Host Management

### Adding a New Host

**Scenario**: You're setting up a fourth host called "endeavor".

**Step 1: Generate SSH key for endeavor**

```bash
ssh-keygen -t ed25519 -C "dustin@endeavor" -f /tmp/endeavor_key -N ""
```

**Step 2: Encrypt the key**

```bash
cd ~/nixos-dotfiles/secrets

# First, ensure endeavor is configured in .sops.yaml
# (See docs/sops-secrets.md for adding a new host)

# Create encrypted secret
sops ssh/endeavor.yaml
```

Add content:

```yaml
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [paste /tmp/endeavor_key content]
  -----END OPENSSH PRIVATE KEY-----

ssh_public_key: "ssh-ed25519 AAAA[paste /tmp/endeavor_key.pub content] dustin@endeavor"
```

**Step 3: Create secrets.nix for endeavor**

```bash
cp ~/nixos-dotfiles/hosts/mischief/secrets.nix ~/nixos-dotfiles/hosts/endeavor/secrets.nix
```

Edit to change "mischief" to "endeavor" in file paths:

```nix
sops.secrets = {
  "ssh_private_key" = {
    sopsFile = ../../secrets/ssh/endeavor.yaml;  # Change here
    path = "/home/dustin/.ssh/id_ed25519";
    owner = "dustin";
    group = "users";
    mode = "0600";
  };

  "ssh_public_key" = {
    sopsFile = ../../secrets/ssh/endeavor.yaml;  # And here
    path = "/home/dustin/.ssh/id_ed25519.pub";
    owner = "dustin";
    group = "users";
    mode = "0644";
  };
};
```

**Step 4: Import secrets.nix in configuration.nix**

Edit `hosts/endeavor/configuration.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix  # Add this line
  ];

  networking.hostName = "endeavor";
}
```

**Step 5: Deploy on endeavor**

```bash
# On endeavor (after NixOS installation)
sudo nixos-rebuild switch --flake .#endeavor
```

**Step 6: Verify**

```bash
ls -la ~/.ssh/id_ed25519*
cat ~/.ssh/id_ed25519.pub
```

**Step 7: Add to GitHub and servers**

Follow "Adding SSH Key to GitHub" and "Adding SSH Key to Remote Server" sections above.

**Step 8: Commit**

```bash
cd ~/nixos-dotfiles
git add secrets/ssh/endeavor.yaml
git add hosts/endeavor/secrets.nix
git add hosts/endeavor/configuration.nix
git commit -m "Add SSH key for endeavor host"
git push
```

---

### Removing a Host

**Scenario**: You're decommissioning "mischief".

**Step 1: Revoke key from all services**

```bash
# Remove from GitHub
# Go to https://github.com/settings/keys
# Delete "mischief" key

# Remove from all remote servers
ssh server1.com
nano ~/.ssh/authorized_keys
# Remove mischief's key line

# Repeat for all servers
```

**Step 2: Remove secret files from repo**

```bash
cd ~/nixos-dotfiles

# Delete encrypted SSH key
rm secrets/ssh/mischief.yaml

# Delete host's secrets.nix
rm hosts/mischief/secrets.nix

# Remove from .sops.yaml
nano secrets/.sops.yaml
# Remove mischief's creation rules

# Remove host's age key
rm secrets/keys/hosts/mischief.txt
```

**Step 3: Update other hosts' secrets (optional)**

If you want to ensure mischief can't decrypt shared secrets:

```bash
cd ~/nixos-dotfiles/secrets

# Re-encrypt all shared secrets (if any) to exclude mischief
sops updatekeys shared/wifi.yaml
sops updatekeys shared/vpn.yaml
```

**Step 4: Remove from flake.nix**

Edit `flake.nix`:

```nix
nixosConfigurations = {
  # Remove this line:
  # mischief = mkHost "mischief" "x86_64-linux";

  intrepid = mkHost "intrepid" "x86_64-linux";
  vigilant = mkHost "vigilant" "x86_64-linux";
};
```

**Step 5: Commit**

```bash
git add -A
git commit -m "Remove mischief host"
git push
```

**Step 6: Wipe the host (optional, for security)**

If donating/selling the hardware:

```bash
# Secure wipe
sudo shred -vfz -n 3 /dev/sda  # Or relevant disk
# WARNING: This destroys all data!
```

---

## Revocation and Recovery

### Revoking a Key from GitHub

**Step 1: Remove from GitHub**

1. Go to https://github.com/settings/keys
2. Find the key to revoke (e.g., "mischief")
3. Click "Delete"
4. Confirm deletion

**Step 2: Verify revocation**

```bash
# On the host with revoked key
ssh -T git@github.com
# Should output: Permission denied (publickey)

# Or if you have a new key:
# Should output: Hi username! You've successfully authenticated...
```

**Step 3: Update repos using HTTPS (temporary)**

If you need to continue working while rotating keys:

```bash
cd ~/nixos-dotfiles
git remote set-url origin https://github.com/username/nixos-dotfiles.git

# Use personal access token for authentication
# GitHub → Settings → Developer settings → Personal access tokens
```

**Step 4: Rotate to new key**

Follow "Rotating a Host's SSH Key" above.

---

### Revoking a Key from Remote Servers

**Single server:**

```bash
ssh dustin@server.com
nano ~/.ssh/authorized_keys
# Find the line with the old key (look for "dustin@mischief" comment)
# Delete that entire line
# Save and exit
```

**Multiple servers (script):**

Create a script to automate:

```bash
#!/usr/bin/env bash
# revoke-ssh-key.sh

OLD_KEY="ssh-ed25519 AAAA... dustin@mischief"
SERVERS=(
  "server1.com"
  "server2.com"
  "server3.com"
)

for server in "${SERVERS[@]}"; do
  echo "Revoking key from $server..."
  ssh "dustin@$server" "sed -i '/$OLD_KEY/d' ~/.ssh/authorized_keys"
  echo "Done: $server"
done
```

Run:

```bash
chmod +x revoke-ssh-key.sh
./revoke-ssh-key.sh
```

**Verify:**

```bash
# Try to SSH with old key (should fail)
ssh -i /tmp/old_key dustin@server.com
# Permission denied

# Try with new key (should work)
ssh dustin@server.com
# Logs in successfully
```

---

### Recovering from Compromised Key

**If a key is compromised but you still control the host:**

Follow "Emergency Key Rotation" above.

**If you've lost control of the host:**

**1. Immediately revoke everywhere:**

```bash
# GitHub (highest priority)
# https://github.com/settings/keys → Delete

# Servers (all of them)
# SSH to each and remove from authorized_keys

# Any other services (GitLab, Bitbucket, etc.)
```

**2. Monitor for abuse:**

```bash
# Check GitHub audit log
# https://github.com/settings/security-log

# Check server logs
ssh server.com
sudo grep "Accepted publickey" /var/log/auth.log | grep dustin
sudo last -f /var/log/wtmp
```

**3. Change all secrets that host had access to:**

```bash
# API tokens
# Passwords
# Database credentials
# VPN configurations
# Anything else stored on that host
```

**4. Consider the host burned:**

- Don't use it again until fully reimaged
- Don't restore from backups (may contain attacker's tools)
- Rebuild from scratch with NixOS

**5. File reports if needed:**

- If work computer: Report to IT/security team
- If VPS: Report to hosting provider
- If malware suspected: Report to abuse contacts

---

## Troubleshooting

### SSH key not working after deployment

**Check permissions:**

```bash
ls -la ~/.ssh/
# id_ed25519 should be 600
# id_ed25519.pub should be 644
# .ssh directory should be 700
```

Fix if needed:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Check ownership:**

```bash
ls -la ~/.ssh/id_ed25519
# Should be owned by your user, not root
```

Fix:

```bash
sudo chown dustin:users ~/.ssh/id_ed25519
sudo chown dustin:users ~/.ssh/id_ed25519.pub
```

**Check key format:**

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
# Should output: 256 SHA256:... dustin@hostname (ED25519)
```

If it fails, the key may be corrupted. Redeploy:

```bash
sudo nixos-rebuild switch --flake .#mischief
```

---

### "Permission denied (publickey)" when accessing GitHub

**Cause 1: Key not added to GitHub**

Solution: Add key to GitHub (see "Adding SSH Key to GitHub")

**Cause 2: Wrong key being used**

```bash
# Check which key SSH is trying
ssh -vT git@github.com 2>&1 | grep "identity file"
# Should show: ~/.ssh/id_ed25519

# If it's trying a different key, specify explicitly
ssh -i ~/.ssh/id_ed25519 -T git@github.com
```

**Cause 3: SSH agent issues**

```bash
# Check agent
ssh-add -l
# Should list your key

# If not, add it
ssh-add ~/.ssh/id_ed25519

# If agent not running, start it
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**Cause 4: Key revoked/removed**

Check GitHub settings: https://github.com/settings/keys

Re-add if needed.

---

### "Host key verification failed"

**This is about SSH HOST keys, not your user SSH keys.**

**Cause**: Server's SSH host key changed (or first time connecting).

**Solution**:

```bash
# For first-time connection
ssh server.com
# Type "yes" to accept fingerprint

# If host key changed (verify it's not a MITM attack!)
ssh-keygen -R server.com
# Then reconnect
ssh server.com
```

**Expected host key change scenarios:**
- Server was reinstalled
- Server's IP was reassigned
- You're connecting from a new machine

**Suspicious scenarios** (possible attack):
- Host key changed unexpectedly
- You didn't do anything that would change it
- Connection is over public WiFi

When in doubt, verify the fingerprint out-of-band (call server admin, check server console, etc.).

---

### sops: error decrypting SSH key

**See docs/sops-secrets.md** for sops troubleshooting.

Quick check:

```bash
# Can you decrypt the file?
cd ~/nixos-dotfiles
sops -d secrets/ssh/mischief.yaml

# If not, check your age key
echo $SOPS_AGE_KEY_FILE
test -f "$SOPS_AGE_KEY_FILE" && echo "Key exists" || echo "Key missing!"
```

---

## Best Practices

### SSH Key Hygiene

**DO:**
- Use ed25519 keys (modern, secure)
- Use unique keys per host (security isolation)
- Add keys to ssh-agent for convenience
- Use descriptive comments (`dustin@mischief`, not `id_ed25519`)
- Rotate keys periodically (every 1-2 years)
- Back up encrypted keys in git (via sops-nix)
- Set up key-based auth for all remote access

**DON'T:**
- Use the same key everywhere (reduces security)
- Use RSA 2048 or less (weak)
- Share private keys between machines (defeats per-host isolation)
- Commit private keys in plaintext (use sops-nix)
- Leave private keys unencrypted on disk (sops-nix handles this)
- Use password-protected keys for automated tasks (use ssh-agent)

### GitHub-Specific

**DO:**
- Use separate keys for GitHub vs servers (optional, extra paranoid)
- Add multiple keys (one per host) to GitHub account
- Name keys clearly ("mischief", "intrepid", etc.)
- Enable 2FA on GitHub (security beyond SSH keys)
- Review GitHub security log periodically

**DON'T:**
- Reuse keys across multiple GitHub accounts
- Leave old/unused keys on GitHub (remove them)
- Share keys with CI/CD systems (use deploy keys instead)

### Server Access

**DO:**
- Use SSH config file for aliases and settings
- Disable password authentication on servers (force key-only)
- Use Jump/Bastion hosts for multi-hop access
- Log SSH connections for auditing
- Use SSH certificates for large deployments (advanced)

**DON'T:**
- Allow root login with SSH keys (use sudo instead)
- Allow password fallback (defeats purpose of keys)
- Use `PermitRootLogin yes` in sshd_config

### Rotation Schedule

**Regular rotation:**
- Personal machines: Every 1-2 years
- Work machines: Follow company policy (often 6-12 months)
- Servers: When employees leave, annually otherwise

**Immediate rotation:**
- After suspected compromise
- When machine is stolen/lost
- After malware infection
- When employee with access leaves

**Optional rotation:**
- After major security announcements
- When upgrading to newer key types
- When consolidating infrastructure

---

## Quick Reference

**Common commands:**

```bash
# View public key
cat ~/.ssh/id_ed25519.pub

# Test GitHub auth
ssh -T git@github.com

# Test server auth
ssh dustin@server.com

# Copy key to server
ssh-copy-id dustin@server.com

# Check SSH agent
ssh-add -l

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Generate new key
ssh-keygen -t ed25519 -C "dustin@hostname" -f /tmp/new_key

# Check key fingerprint
ssh-keygen -lf ~/.ssh/id_ed25519.pub

# Remove host from known_hosts
ssh-keygen -R server.com
```

**File locations:**

```
~/.ssh/id_ed25519           Your private key (600)
~/.ssh/id_ed25519.pub       Your public key (644)
~/.ssh/config               SSH client config
~/.ssh/known_hosts          Trusted server fingerprints
~/.ssh/authorized_keys      (on server) Keys allowed to log in
```

**Important URLs:**

- GitHub SSH keys: https://github.com/settings/keys
- GitHub security log: https://github.com/settings/security-log

---

## Additional Resources

- [GitHub: Connecting with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [SSH Academy: Best Practices](https://www.ssh.com/academy/ssh/key-management)
- [ArchWiki: SSH Keys](https://wiki.archlinux.org/title/SSH_keys)
- [NixOS Manual: sops-nix](https://nixos.org/manual/nixos/stable/index.html#module-services-sops)
