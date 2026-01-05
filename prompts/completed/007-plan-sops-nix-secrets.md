<objective>
Create a detailed implementation plan for integrating sops-nix into this NixOS dotfiles repository to manage secrets. The plan should cover:
1. Per-host SSH key generation and storage
2. Declarative Syncthing configuration with preserved device identities from existing Arch Linux hosts
3. The complete workflow for encrypting, storing, and deploying secrets

This is a PLANNING task - do not implement yet. Produce a detailed, step-by-step plan that can be reviewed before execution.
</objective>

<context>
This is a multi-host NixOS dotfiles repository with:
- 3 hosts: mischief (ThinkPad X270), intrepid (Desktop), vigilant (Surface Laptop 4)
- Currently only mischief is running NixOS; intrepid and vigilant will be migrated from Arch Linux
- User wants per-host SSH keys (not shared) for better security isolation
- Syncthing is enabled in home-manager but needs declarative folder/device configuration
- The Arch hosts have existing Syncthing identities (key.pem) that should be preserved during migration
- Syncthing folders to sync: ~/Sync and ~/Code across all 3 hosts

Review these files for current structure:
- @./flake.nix - flake structure and inputs
- @./hosts/common/configuration.nix - shared NixOS config
- @./hosts/common/home.nix - shared home-manager config (has services.syncthing.enable = true)
- @./hosts/mischief/configuration.nix - host-specific example
</context>

<planning_requirements>
Thoroughly analyze the sops-nix documentation and NixOS patterns to create a comprehensive plan covering:

1. **sops-nix Integration**
   - How to add sops-nix to flake.nix inputs
   - Where to store the age key for decryption (~/.config/sops/age/keys.txt or /etc/sops/age/keys.txt)
   - Directory structure for encrypted secrets in the repo (e.g., ./secrets/)
   - The .sops.yaml configuration file structure

2. **Per-Host SSH Key Strategy**
   - How to generate ed25519 keys for each host
   - Naming convention (e.g., secrets/ssh/mischief.key, secrets/ssh/intrepid.key)
   - How sops-nix will decrypt and deploy keys to ~/.ssh/
   - File permissions handling (SSH requires strict permissions)
   - How to handle the public keys (can be unencrypted in repo)

3. **Syncthing Configuration**
   - How to backup existing key.pem/cert.pem from Arch hosts
   - Where to store encrypted Syncthing identities in the repo
   - Declarative device and folder configuration in home.nix
   - How device IDs are obtained and stored
   - Complete services.syncthing.settings structure for the 2 folders (~/Sync, ~/Code)

4. **Encryption Workflow**
   - How to generate the age keypair for encryption/decryption
   - Command examples for encrypting secrets with sops
   - How secrets are decrypted at activation time
   - Handling secrets that need to exist before home-manager activation

5. **Migration Path**
   - Step-by-step process for migrating each Arch host
   - Order of operations (backup → install NixOS → restore secrets → rebuild)
   - How to test the setup on mischief first before migrating others

6. **Security Considerations**
   - Where the age private key should be stored (NOT in repo)
   - Backup strategy for the age key itself
   - What happens if a host is compromised

7. **Documentation**
   - Create docs inside ./docs/ folder
   - **SSH documentation** (`./docs/ssh-keys.md`):
     - How to rotate SSH keys for a host
     - How to add a new host's SSH key
     - How to revoke/remove a host's key from GitHub and remote servers
     - Emergency key rotation procedure if a host is compromised
   - **Syncthing documentation** (`./docs/syncthing.md`):
     - How to add/remove a device from the Syncthing cluster
     - How to add/remove a shared folder
     - How to migrate a host from Arch to NixOS (preserving identity)
     - Troubleshooting: what to do if devices can't connect
   - **sops-nix documentation** (`./docs/sops-secrets.md`):
     - How to add a new secret to the repo
     - How to update an existing secret
     - How to re-encrypt secrets when adding a new host
     - Backup and recovery of the age master key
</planning_requirements>

<output>
Create the following deliverables:

**Implementation Plan** (`./plans/007-sops-nix-secrets-plan.md`):
- Overview section explaining the architecture
- Prerequisites (tools needed, backups to make)
- Numbered implementation steps with exact commands and code snippets
- File structure diagram showing where secrets will live
- Example Nix code for each configuration file that will be modified
- Verification steps to confirm each part works
- Rollback procedures if something goes wrong
- A section on "manual steps required" (things that can't be automated)

**Documentation Files**:
- `./docs/ssh-keys.md` - SSH key lifecycle management
- `./docs/syncthing.md` - Syncthing device and folder management
- `./docs/sops-secrets.md` - sops-nix secrets workflow

Format the plan so it can be directly executed step-by-step in a future session.
</output>

<verification>
Before completing, verify the plan:
- Addresses all 3 hosts (mischief, intrepid, vigilant)
- Covers both system-level and home-manager secrets
- Includes exact file paths and code examples
- Has clear success criteria for each step
- Considers the migration from Arch Linux scenario
- Documentation files are actionable (user can follow steps without external research)
- Each doc covers: normal operations, edge cases, and recovery procedures
</verification>

<success_criteria>
- Complete plan document in ./plans/007-sops-nix-secrets-plan.md
- Documentation files created: ./docs/ssh-keys.md, ./docs/syncthing.md, ./docs/sops-secrets.md
- Plan is detailed enough to execute without additional research
- All secrets (SSH keys, Syncthing identities) are covered
- Security best practices are followed
- Migration path from Arch is clearly documented
- Each doc file covers all lifecycle operations (add, remove, rotate, troubleshoot)
</success_criteria>
