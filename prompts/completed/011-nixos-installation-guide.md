<objective>
Create comprehensive documentation for installing NixOS on intrepid and vigilant hosts, then switching to this dotfiles configuration.

This is a DOCUMENTATION task - create a step-by-step installation guide that can be followed to migrate these hosts from Arch Linux to NixOS using this repository's configuration.
</objective>

<context>
This is a multi-host NixOS dotfiles repository with:
- 3 hosts: mischief (ThinkPad X270 - already on NixOS), intrepid (Desktop AMD), vigilant (Surface Laptop 4 AMD)
- Flake-based configuration with home-manager integration
- sops-nix secrets management (SSH keys, Syncthing identity, WiFi passwords)
- Host-specific configurations in `hosts/<hostname>/`

Review these files to understand the current setup:
- @./flake.nix - flake structure showing all hosts
- @./hosts/intrepid/ - intrepid's configuration files
- @./hosts/vigilant/ - vigilant's configuration files
- @./CLAUDE.md - project overview and architecture
- @./plans/007-sops-nix-secrets-plan.md - secrets setup steps (sections on adding new hosts)
- @./docs/sops-secrets.md - secrets management documentation

The target audience is the repository owner who needs clear, copy-paste commands.
</context>

<requirements>
Create documentation covering:

1. **Pre-Installation Preparation** (while still on Arch)
   - Backup critical data (Syncthing identity, SSH keys, any local files)
   - Note hardware details (disk layout, partition scheme)
   - Document current WiFi networks if applicable
   - Copy backups to mischief or external storage

2. **NixOS Installation Options**
   - Recommend the best installation method (minimal ISO vs graphical)
   - Explain why that method is preferred for this use case
   - Link to official NixOS download page
   - Cover creating bootable USB

3. **Initial NixOS Installation**
   - Boot from installer
   - Partition disk (recommend same layout or explain options)
   - Run nixos-install with minimal config
   - First boot and initial setup

4. **Switching to This Configuration**
   - Install git (nix-shell -p git)
   - Clone this repository
   - Generate hardware-configuration.nix for the new host
   - Compare with existing hardware-configuration.nix in repo
   - Run nixos-rebuild switch --flake .#<hostname>

5. **Post-Installation: sops-nix Setup**
   - Extract host age key from SSH host key
   - Update secrets/keys/hosts/<hostname>.txt
   - Update secrets/.sops.yaml to uncomment host rules
   - Generate and encrypt SSH keys for the host
   - Encrypt backed-up Syncthing identity
   - Create/update hosts/<hostname>/secrets.nix
   - Rebuild to deploy secrets

6. **Post-Installation: Verification**
   - Verify all services running (Syncthing, evremap if applicable)
   - Test WiFi connection
   - Verify SSH keys work
   - Confirm Syncthing connects to other devices

7. **Host-Specific Notes**
   - intrepid: Desktop with AMD GPU, uses rk-s70.toml for evremap
   - vigilant: Surface Laptop 4, may need linux-surface kernel/firmware

8. **Troubleshooting**
   - Common installation issues
   - How to recover if rebuild fails
   - How to boot previous generation
</requirements>

<output>
Create documentation at:
`./docs/nixos-installation-guide.md`

Structure:
- Clear section headers
- Copy-paste command blocks
- Checklists for verification steps
- Links to relevant existing documentation (don't duplicate, reference)
- Host-specific sections for intrepid and vigilant
</output>

<verification>
Before completing, verify the documentation:
- Commands are accurate and copy-paste ready
- References existing docs rather than duplicating (sops-secrets.md, etc.)
- Covers both intrepid (desktop) and vigilant (Surface laptop)
- Includes pre-migration backup steps
- Has clear success criteria at each stage
</verification>

<success_criteria>
- Complete installation guide at ./docs/nixos-installation-guide.md
- Covers full journey: Arch backup → NixOS install → config switch → secrets setup
- Host-specific sections for intrepid and vigilant
- All commands are tested/accurate
- References existing documentation where appropriate
</success_criteria>
