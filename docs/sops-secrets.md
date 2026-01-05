# sops-nix Secrets Management Guide

This guide covers day-to-day operations for managing secrets in the Romey NixOS dotfiles repository using sops-nix.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Common Operations](#common-operations)
  - [Adding a New Secret](#adding-a-new-secret)
  - [Updating an Existing Secret](#updating-an-existing-secret)
  - [Viewing a Secret](#viewing-a-secret)
  - [Deleting a Secret](#deleting-a-secret)
- [Advanced Operations](#advanced-operations)
  - [Adding a New Host](#adding-a-new-host)
  - [Re-encrypting Secrets](#re-encrypting-secrets)
  - [Rotating Secrets](#rotating-secrets)
  - [Changing Encryption Keys](#changing-encryption-keys)
- [Backup and Recovery](#backup-and-recovery)
  - [Backing Up the Admin Key](#backing-up-the-admin-key)
  - [Recovering from Lost Admin Key](#recovering-from-lost-admin-key)
  - [Recovering from Lost Host Key](#recovering-from-lost-host-key)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Overview

**sops-nix** (Secrets OPerationS for NixOS) provides encrypted secrets management for NixOS systems. Key features:

- **Age encryption**: Modern, simple encryption (alternative to GPG)
- **Declarative**: Secrets defined in Nix configuration
- **Per-host encryption**: Each host can only decrypt its own secrets
- **Git-friendly**: Encrypted files safe to commit to version control

**Architecture:**

```
You (admin)                    Git Repository              NixOS Hosts
    |                                |                           |
    |-- Admin age key ----------> .sops.yaml              Host age key
    |                                |                           |
    |-- Encrypt secret ---------> secrets/foo.yaml              |
    |   (sops edit)                  |                           |
    |                                |-- NixOS rebuild --------> |
    |                                |                           |
    |                                |                    Decrypt secret
    |                                |                    Deploy to /run/secrets/
```

**Key concepts:**

- **Admin key**: Your personal age key, used to create and edit secrets
- **Host keys**: Per-host age keys derived from SSH host keys, used to decrypt secrets on that host
- **Creation rules**: Define which keys can decrypt which secrets (.sops.yaml)
- **Secret definitions**: Nix code that deploys decrypted secrets to specific paths (hosts/*/secrets.nix)

---

## Prerequisites

**Tools required:**

```bash
# Install sops and age (if not already installed)
nix-shell -p sops age ssh-to-age
```

**Environment setup:**

```bash
# Set admin key location (add to ~/.bashrc or ~/.config/bash_aliases.sh)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Verify admin key exists
test -f "$SOPS_AGE_KEY_FILE" && echo "Admin key found" || echo "Admin key missing!"
```

**Repository location:**

```bash
# All examples assume you're in the dotfiles repo
cd ~/nixos-dotfiles
```

---

## Common Operations

### Adding a New Secret

**Scenario**: You want to add a GitHub API token.

**Step 1: Choose a location**

Secrets are organized by:
- **Type**: `secrets/ssh/`, `secrets/syncthing/`, `secrets/api/`, etc.
- **Host**: `mischief.yaml`, `intrepid.yaml`, `vigilant.yaml`, or `shared.yaml`

```bash
# For a host-specific secret (only mischief needs it)
mkdir -p secrets/api

# For a shared secret (all hosts need it)
mkdir -p secrets/shared
```

**Step 2: Update .sops.yaml**

Add a creation rule for your new secret:

```bash
cd secrets
nano .sops.yaml
```

Add this rule:

```yaml
  # GitHub API token for mischief
  - path_regex: secrets/api/github-mischief\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *mischief_key
```

Or for a shared secret (all hosts):

```yaml
  # Shared GitHub API token
  - path_regex: secrets/shared/github\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *mischief_key
          - *intrepid_key
          - *vigilant_key
```

**Step 3: Create and encrypt the secret**

```bash
cd ~/nixos-dotfiles/secrets
sops api/github-mischief.yaml
```

This opens your $EDITOR with an empty file. Add your secret in YAML format:

```yaml
# GitHub API token for mischief
github_api_token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
github_username: "dustinromey"
```

Save and exit. sops will automatically encrypt the file.

**Step 4: Verify encryption**

```bash
# File should be encrypted (gibberish)
cat api/github-mischief.yaml

# But you can decrypt it with your admin key
sops -d api/github-mischief.yaml
```

**Step 5: Deploy the secret**

Edit the host's `secrets.nix`:

```bash
nano ~/nixos-dotfiles/hosts/mischief/secrets.nix
```

Add a new secret definition:

```nix
secrets = {
  # ... existing secrets ...

  # GitHub API token
  "github_api_token" = {
    sopsFile = ../../secrets/api/github-mischief.yaml;
    path = "/run/secrets/github-token";  # Where it will be deployed
    owner = "dustin";
    group = "users";
    mode = "0400";  # Read-only for owner
  };
};
```

**Step 6: Use the secret in your config**

In your NixOS config or home-manager config:

```nix
# Example: Use in an environment variable
home.sessionVariables = {
  GITHUB_TOKEN = builtins.readFile config.sops.secrets.github_api_token.path;
};

# Example: Use in a systemd service
systemd.services.my-service = {
  serviceConfig = {
    EnvironmentFile = config.sops.secrets.github_api_token.path;
  };
};
```

**Step 7: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

**Step 8: Verify deployment**

```bash
# Secret should exist at the specified path
sudo cat /run/secrets/github-token

# Check permissions
ls -la /run/secrets/github-token
# Should show: -r-------- 1 dustin users ... github-token
```

**Step 9: Commit**

```bash
cd ~/nixos-dotfiles
git add secrets/.sops.yaml
git add secrets/api/github-mischief.yaml
git add hosts/mischief/secrets.nix
git commit -m "Add GitHub API token for mischief"
git push
```

---

### Updating an Existing Secret

**Scenario**: Your GitHub API token changed.

**Step 1: Edit the secret**

```bash
cd ~/nixos-dotfiles/secrets
sops api/github-mischief.yaml
```

This decrypts the file, opens it in your $EDITOR, and re-encrypts on save.

**Step 2: Update the value**

```yaml
# Change this:
github_api_token: "ghp_old_token_xxxxxxxxxxxxxxxxxxxx"

# To this:
github_api_token: "ghp_new_token_yyyyyyyyyyyyyyyyyyyy"
```

Save and exit.

**Step 3: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

The new token will be deployed immediately.

**Step 4: Commit**

```bash
git add secrets/api/github-mischief.yaml
git commit -m "Update GitHub API token for mischief"
git push
```

---

### Viewing a Secret

**View with sops:**

```bash
cd ~/nixos-dotfiles/secrets
sops -d api/github-mischief.yaml
```

**View specific key:**

```bash
sops -d --extract '["github_api_token"]' api/github-mischief.yaml
```

**View on the host (after deployment):**

```bash
# As root or with sudo
sudo cat /run/secrets/github-token

# If you're the owner
cat /run/secrets/github-token
```

---

### Deleting a Secret

**Step 1: Remove from secrets.nix**

Edit `hosts/mischief/secrets.nix` and remove the secret definition:

```nix
secrets = {
  # Remove this entire block:
  # "github_api_token" = { ... };

  # Keep other secrets
  "ssh_private_key" = { ... };
};
```

**Step 2: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

The secret file will be removed from `/run/secrets/`.

**Step 3: Optionally delete encrypted file**

```bash
cd ~/nixos-dotfiles/secrets
rm api/github-mischief.yaml
```

**Step 4: Optionally remove from .sops.yaml**

Edit `secrets/.sops.yaml` and remove the creation rule:

```yaml
# Remove this:
# - path_regex: secrets/api/github-mischief\.yaml$
#   key_groups:
#     - age:
#         - *admin_key
#         - *mischief_key
```

**Step 5: Commit**

```bash
git add hosts/mischief/secrets.nix
git add secrets/.sops.yaml
git add secrets/api/github-mischief.yaml  # If deleted
git commit -m "Remove GitHub API token secret"
git push
```

---

## Advanced Operations

### Adding a New Host

**Scenario**: You're adding a fourth host called "endeavor".

**Step 1: Generate host's age key**

After installing NixOS on endeavor:

```bash
# On endeavor
sudo ssh-keygen -A  # Generate SSH host keys
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

Copy the output (starts with `age1...`).

**Step 2: Add age public key to repo**

On your admin machine (mischief):

```bash
cd ~/nixos-dotfiles/secrets/keys/hosts
echo "age1endeavor..." > endeavor.txt
```

**Step 3: Update .sops.yaml**

Edit `secrets/.sops.yaml`:

```yaml
keys:
  - &admin_key $(cat keys/users/admin.txt)
  - &mischief_key $(cat keys/hosts/mischief.txt)
  - &intrepid_key $(cat keys/hosts/intrepid.txt)
  - &vigilant_key $(cat keys/hosts/vigilant.txt)
  - &endeavor_key $(cat keys/hosts/endeavor.txt)  # Add this

creation_rules:
  # Add rules for endeavor
  - path_regex: secrets/ssh/endeavor\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *endeavor_key

  - path_regex: secrets/syncthing/endeavor\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *endeavor_key

  # Update shared secrets to include endeavor
  - path_regex: secrets/shared/.*\.yaml$
    key_groups:
      - age:
          - *admin_key
          - *mischief_key
          - *intrepid_key
          - *vigilant_key
          - *endeavor_key  # Add this
```

**Step 4: Re-encrypt existing shared secrets**

```bash
cd ~/nixos-dotfiles/secrets

# Re-encrypt each shared secret to include endeavor's key
sops updatekeys shared/wifi.yaml
sops updatekeys shared/vpn.yaml
# ... repeat for all shared secrets
```

**Step 5: Create endeavor-specific secrets**

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "dustin@endeavor" -f /tmp/endeavor_key -N ""

# Encrypt it
sops ssh/endeavor.yaml
# Paste the private key content
```

**Step 6: Create secrets.nix for endeavor**

```bash
cp ~/nixos-dotfiles/hosts/mischief/secrets.nix ~/nixos-dotfiles/hosts/endeavor/secrets.nix
# Edit to change "mischief" to "endeavor" throughout
```

**Step 7: Update flake.nix**

Add endeavor to `flake.nix`:

```nix
nixosConfigurations = {
  mischief = mkHost "mischief" "x86_64-linux";
  intrepid = mkHost "intrepid" "x86_64-linux";
  vigilant = mkHost "vigilant" "x86_64-linux";
  endeavor = mkHost "endeavor" "x86_64-linux";  # Add this
};
```

**Step 8: Rebuild on endeavor**

```bash
# On endeavor
sudo nixos-rebuild switch --flake .#endeavor
```

**Step 9: Commit**

```bash
git add flake.nix
git add secrets/.sops.yaml
git add secrets/keys/hosts/endeavor.txt
git add secrets/ssh/endeavor.yaml
git add hosts/endeavor/
git commit -m "Add endeavor host"
git push
```

---

### Re-encrypting Secrets

**When to re-encrypt:**
- After adding a new host (to give it access to shared secrets)
- After removing a host (to revoke its access)
- After rotating the admin key

**Re-encrypt all secrets:**

```bash
cd ~/nixos-dotfiles/secrets

# Find all encrypted files
find . -name "*.yaml" -type f

# Re-encrypt each one
sops updatekeys ssh/mischief.yaml
sops updatekeys ssh/intrepid.yaml
sops updatekeys ssh/vigilant.yaml
sops updatekeys syncthing/mischief.yaml
# ... etc
```

**Re-encrypt with a script:**

```bash
cd ~/nixos-dotfiles/secrets

# Re-encrypt all .yaml files
for file in $(find . -name "*.yaml" -type f); do
  echo "Re-encrypting $file..."
  sops updatekeys "$file"
done
```

**Verify:**

```bash
# Each file should still decrypt correctly
for file in $(find . -name "*.yaml" -type f); do
  echo "Testing $file..."
  sops -d "$file" > /dev/null && echo "✓ OK" || echo "✗ FAILED"
done
```

---

### Rotating Secrets

**Scenario**: You suspect a secret was compromised.

**Example: Rotate GitHub API token**

**Step 1: Generate new token**

- Go to GitHub → Settings → Developer settings → Personal access tokens
- Generate new token with same permissions
- Copy the new token

**Step 2: Update the secret**

```bash
cd ~/nixos-dotfiles/secrets
sops api/github-mischief.yaml
```

Replace the old token with the new one:

```yaml
github_api_token: "ghp_new_secure_token_here"
```

**Step 3: Rebuild**

```bash
sudo nixos-rebuild switch --flake .#mischief
```

**Step 4: Revoke old token**

- Go to GitHub → Settings → Developer settings → Personal access tokens
- Find the old token and click "Delete"

**Step 5: Commit**

```bash
git add secrets/api/github-mischief.yaml
git commit -m "Rotate GitHub API token"
git push
```

---

### Changing Encryption Keys

**Scenario**: You're rotating the admin age key (e.g., after a security incident).

**CRITICAL**: This requires access to existing secrets, so do this BEFORE losing the old key!

**Step 1: Generate new admin key**

```bash
# Backup old key first
cp ~/.config/sops/age/keys.txt ~/.config/sops/age/keys.txt.old

# Generate new key
age-keygen -o ~/.config/sops/age/keys-new.txt

# Note the new public key
cat ~/.config/sops/age/keys-new.txt | grep "# public key:"
```

**Step 2: Update keys/users/admin.txt**

```bash
cd ~/nixos-dotfiles/secrets
echo "age1new_public_key_here" > keys/users/admin.txt
```

**Step 3: Temporarily use both keys**

```bash
# Combine old and new keys
cat ~/.config/sops/age/keys.txt.old > ~/.config/sops/age/keys-combined.txt
cat ~/.config/sops/age/keys-new.txt >> ~/.config/sops/age/keys-combined.txt

# Use combined keys for re-encryption
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys-combined.txt"
```

**Step 4: Re-encrypt all secrets**

```bash
cd ~/nixos-dotfiles/secrets

for file in $(find . -name "*.yaml" -type f); do
  echo "Re-encrypting $file with new admin key..."
  sops updatekeys "$file"
done
```

**Step 5: Test with new key only**

```bash
# Use only the new key
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys-new.txt"

# Test decryption
sops -d ssh/mischief.yaml
# Should work!
```

**Step 6: Replace admin key**

```bash
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt
```

**Step 7: Backup new key**

```bash
# Copy to password manager, encrypted USB, etc.
cat ~/.config/sops/age/keys.txt
```

**Step 8: Securely delete old key**

```bash
shred -u ~/.config/sops/age/keys.txt.old
shred -u ~/.config/sops/age/keys-combined.txt
```

**Step 9: Commit**

```bash
git add secrets/keys/users/admin.txt
git add secrets/  # Re-encrypted files
git commit -m "Rotate admin age key"
git push
```

---

## Backup and Recovery

### Backing Up the Admin Key

**CRITICAL**: The admin key is the master key. If lost, you cannot edit secrets!

**Backup methods:**

**1. Password manager (recommended)**

```bash
cat ~/.config/sops/age/keys.txt
# Copy the entire contents into 1Password, Bitwarden, etc.
# Store as "Romey NixOS - Admin Age Key"
```

**2. Encrypted USB drive**

```bash
# Encrypt to USB drive
sudo cryptsetup luksFormat /dev/sdX
sudo cryptsetup open /dev/sdX backup-drive
sudo mkfs.ext4 /dev/mapper/backup-drive
sudo mount /dev/mapper/backup-drive /mnt

# Copy key
sudo cp ~/.config/sops/age/keys.txt /mnt/romey-nixos-admin-key.txt
sudo umount /mnt
sudo cryptsetup close backup-drive

# Store USB drive in safe location
```

**3. Paper backup (disaster recovery)**

```bash
cat ~/.config/sops/age/keys.txt
# Print this
# Store in fireproof safe
# Use OCR to recover if needed (age keys are text-friendly)
```

**4. Cloud backup (encrypted)**

```bash
# Encrypt with a strong passphrase
age -p < ~/.config/sops/age/keys.txt > romey-admin-key.age
# Upload romey-admin-key.age to cloud storage (Dropbox, Google Drive, etc.)

# To recover:
age -d romey-admin-key.age > ~/.config/sops/age/keys.txt
```

**Verification:**

```bash
# Test backup works
SOPS_AGE_KEY_FILE=/path/to/backup/keys.txt sops -d secrets/ssh/mischief.yaml
# Should decrypt successfully
```

---

### Recovering from Lost Admin Key

**If you have a backup:**

```bash
# Restore from backup
cp /path/to/backup/keys.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Test
sops -d secrets/ssh/mischief.yaml
```

**If you DON'T have a backup but have access to hosts:**

The host keys can still decrypt their own secrets. You need to:

1. Generate a new admin key
2. Use each host to decrypt its secrets
3. Re-encrypt with new admin key

```bash
# Generate new admin key
age-keygen -o ~/.config/sops/age/keys-new.txt
NEW_ADMIN_KEY=$(grep "public key:" ~/.config/sops/age/keys-new.txt | awk '{print $4}')

# Update admin key in repo
echo "$NEW_ADMIN_KEY" > ~/nixos-dotfiles/secrets/keys/users/admin.txt

# For EACH host, decrypt and re-encrypt its secrets
# On mischief:
cd ~/nixos-dotfiles/secrets
sudo sops -d ssh/mischief.yaml > /tmp/mischief-ssh.yaml

# Re-encrypt with new admin key (and mischief's host key)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys-new.txt
sops -e /tmp/mischief-ssh.yaml > ssh/mischief.yaml
rm /tmp/mischief-ssh.yaml

# Repeat for intrepid and vigilant (on those hosts)
```

This is tedious but recoverable!

---

### Recovering from Lost Host Key

**If a host loses its age key** (e.g., `/var/lib/sops-nix/key.txt` deleted):

**Good news**: Host keys are deterministic - they're derived from SSH host keys.

```bash
# On the host, regenerate age key
sudo rm /var/lib/sops-nix/key.txt  # If corrupt
sudo nixos-rebuild switch --flake .#hostname

# sops-nix will regenerate the key from /etc/ssh/ssh_host_ed25519_key
```

**If SSH host key is also lost:**

Now you need to rotate the host's secrets:

1. Generate new SSH host key:
   ```bash
   sudo ssh-keygen -A
   ```

2. Extract new age public key:
   ```bash
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
   ```

3. Update in repo:
   ```bash
   echo "age1new_key..." > ~/nixos-dotfiles/secrets/keys/hosts/mischief.txt
   ```

4. Re-encrypt all of mischief's secrets:
   ```bash
   cd ~/nixos-dotfiles/secrets
   sops updatekeys ssh/mischief.yaml
   sops updatekeys syncthing/mischief.yaml
   ```

5. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#mischief
   ```

---

## Troubleshooting

### Error: "no key could decrypt the file"

**Symptom:**
```
sops -d secrets/ssh/mischief.yaml
error decrypting key: [error decrypting key: no key could decrypt the file]
```

**Cause**: Your age key is not in the file's allowed keys.

**Solution 1: Check you're using the right key**

```bash
# Check which key you're using
echo $SOPS_AGE_KEY_FILE
cat $SOPS_AGE_KEY_FILE | grep "# public key:"

# Check which keys can decrypt the file
sops -d --verbose secrets/ssh/mischief.yaml 2>&1 | grep "age key"
```

**Solution 2: Re-encrypt the file**

```bash
# If your key is in .sops.yaml but file wasn't updated
cd ~/nixos-dotfiles/secrets
sops updatekeys ssh/mischief.yaml
```

**Solution 3: Check .sops.yaml is correct**

```bash
cd ~/nixos-dotfiles/secrets
cat .sops.yaml

# Ensure the regex matches your file
# - path_regex: secrets/ssh/mischief\.yaml$
#   Should match: secrets/ssh/mischief.yaml
```

---

### Error: "Failed to get the data key required to decrypt the SOPS file"

**Symptom:**
```
Failed to get the data key required to decrypt the SOPS file.
```

**Cause**: File is corrupted or was encrypted with a different configuration.

**Solution**: Re-encrypt from backup

```bash
# If you have a decrypted backup
cd ~/nixos-dotfiles/secrets
sops -e /tmp/backup.yaml > ssh/mischief.yaml

# If you don't have a backup but can still decrypt
sops -d ssh/mischief.yaml > /tmp/mischief.yaml
sops -e /tmp/mischief.yaml > ssh/mischief.yaml
rm /tmp/mischief.yaml
```

---

### Secret file deployed with wrong permissions

**Symptom:**
```bash
ls -la /run/secrets/ssh_key
-rw-r--r-- 1 root root 1234 Jan 01 12:00 /run/secrets/ssh_key
# Should be 600, not 644!
```

**Cause**: Wrong `mode` in secrets.nix

**Solution**:

Edit `hosts/mischief/secrets.nix`:

```nix
"ssh_private_key" = {
  sopsFile = ../../secrets/ssh/mischief.yaml;
  path = "/home/dustin/.ssh/id_ed25519";
  owner = "dustin";
  group = "users";
  mode = "0600";  # Make sure this is correct
};
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake .#mischief
```

---

### Secret not deployed after rebuild

**Symptom**: Secret file doesn't exist at expected path after `nixos-rebuild`.

**Cause 1: Secret not defined in secrets.nix**

Check `hosts/mischief/secrets.nix`:

```nix
sops.secrets = {
  "my_secret" = { ... };  # Must be defined here
};
```

**Cause 2: sops-nix service failed**

```bash
systemctl status sops-nix
# Check for errors
journalctl -u sops-nix
```

**Cause 3: Age key missing**

```bash
ls -la /var/lib/sops-nix/key.txt
# Should exist with mode 600
```

If missing:

```bash
sudo nixos-rebuild switch --flake .#mischief
# sops-nix will generate it from SSH host key
```

---

### YAML syntax error when editing with sops

**Symptom:**
```
Error: yaml: line 5: mapping values are not allowed in this context
```

**Cause**: Invalid YAML syntax (indentation, special characters, etc.)

**Common issues:**

```yaml
# WRONG: Inconsistent indentation
ssh_key: |
    -----BEGIN PRIVATE KEY-----
  xxxxx  # Mixed 4 spaces and 2 spaces

# CORRECT: Consistent indentation
ssh_key: |
  -----BEGIN PRIVATE KEY-----
  xxxxx

# WRONG: Missing quotes for special characters
password: my$ecret!pass

# CORRECT: Quote special characters
password: "my$ecret!pass"

# WRONG: Colon in unquoted string
api_url: http://example.com

# CORRECT: Quote strings with colons
api_url: "http://example.com"
```

**Solution**: Fix YAML syntax and try again.

---

## Security Best Practices

### DO:

- **Keep admin key secure**: Use a password manager or encrypted storage
- **Backup admin key**: Multiple secure locations
- **Use per-host secrets**: Don't share secrets across hosts unless necessary
- **Rotate secrets regularly**: Especially API tokens and passwords
- **Review .sops.yaml**: Ensure only intended hosts can decrypt each secret
- **Commit encrypted files**: Encrypted secrets are safe to push to git
- **Use strong ownership/permissions**: `mode = "0400"` for read-only secrets, `owner = "dustin"` not `owner = "root"` unless needed

### DON'T:

- **Commit plaintext secrets**: NEVER commit unencrypted secrets
- **Share admin key**: One admin key per person (use multiple admin keys if needed)
- **Use weak passwords**: For age key encryption (if using `age -p`)
- **Ignore backup**: Losing admin key = losing all secrets
- **Hard-code secrets**: Use sops-nix, not strings in Nix files
- **Over-share secrets**: Only encrypt to hosts that need the secret

### Audit checklist:

```bash
# 1. No plaintext secrets in repo
git grep -i "password\|token\|secret\|api.key" --all-match *.nix
# Should not find actual secrets

# 2. Admin key is backed up
test -f ~/.config/sops/age/keys.txt.backup && echo "Backed up" || echo "NOT BACKED UP!"

# 3. Encrypted files are actually encrypted
for f in secrets/**/*.yaml; do
  if grep -q "BEGIN.*KEY" "$f"; then
    echo "⚠️  $f may contain plaintext!"
  fi
done

# 4. Deployed secrets have correct permissions
sudo find /run/secrets -ls
# Check owner, group, mode for each

# 5. .sops.yaml is valid
cd ~/nixos-dotfiles/secrets
sops -d --verbose ssh/mischief.yaml 2>&1 | grep -i error
# Should be empty
```

---

## Quick Reference

**Common commands:**

```bash
# Create/edit a secret
sops secrets/ssh/mischief.yaml

# View a secret
sops -d secrets/ssh/mischief.yaml

# View specific key
sops -d --extract '["password"]' secrets/api/github.yaml

# Update encryption keys
sops updatekeys secrets/ssh/mischief.yaml

# Re-encrypt all secrets
find secrets -name "*.yaml" -exec sops updatekeys {} \;

# Check which keys can decrypt a file
sops -d --verbose secrets/ssh/mischief.yaml 2>&1 | grep "age"

# Test decryption without output
sops -d secrets/ssh/mischief.yaml > /dev/null && echo "OK" || echo "FAILED"
```

**File locations:**

```
~/.config/sops/age/keys.txt         Admin private key (BACKUP THIS!)
~/nixos-dotfiles/secrets/.sops.yaml Creation rules
~/nixos-dotfiles/secrets/keys/      Age public keys (safe to commit)
/var/lib/sops-nix/key.txt           Host private key (auto-generated)
/run/secrets/                       Deployed secrets (decrypted)
```

**Getting help:**

```bash
# sops help
sops --help

# age help
age --help
age-keygen --help

# ssh-to-age help
ssh-to-age --help
```

---

## Additional Resources

- [sops documentation](https://github.com/mozilla/sops)
- [age encryption](https://github.com/FiloSottile/age)
- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [NixOS Wiki: sops-nix](https://nixos.wiki/wiki/Sops-nix)
