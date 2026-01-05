<objective>
Create a detailed implementation plan for storing WiFi passwords using sops-nix in this NixOS dotfiles repository. This plan should be consistent with and build upon the sops-nix secrets infrastructure designed in plan 007.

This is a PLANNING task - do not implement yet. Produce a detailed, step-by-step plan that can be reviewed before execution.
</objective>

<context>
This is a multi-host NixOS dotfiles repository with:
- 3 hosts: mischief (ThinkPad X270), intrepid (Desktop), vigilant (Surface Laptop 4)
- All hosts use iwd for WiFi management
- Home networks only (1-2 fixed SSIDs shared across all hosts)
- sops-nix will use SSH host keys for decryption (from /etc/ssh/ssh_host_ed25519_key)
- Plan 007 establishes the base sops-nix infrastructure (age keys, .sops.yaml, secrets directory)

Review these files for current structure:
- @./flake.nix - flake structure and inputs
- @./hosts/common/configuration.nix - shared NixOS config
- @./hosts/mischief/configuration.nix - host-specific example
- @./prompts/007-plan-sops-nix-secrets.md - the base sops-nix plan this builds upon
</context>

<planning_requirements>
Thoroughly analyze iwd and sops-nix integration patterns to create a comprehensive plan covering:

1. **iwd + sops-nix Compatibility**
   - How iwd stores network configurations (/var/lib/iwd/*.psk files)
   - Whether iwd works on AMD hosts (intrepid, vigilant) - confirm compatibility
   - NixOS options for declarative iwd configuration (networking.wireless.iwd)
   - How sops-nix can provide secrets to iwd at boot time

2. **Secret Structure**
   - File format for iwd .psk files (what fields are required)
   - Where to store encrypted WiFi secrets in the repo (e.g., ./secrets/wifi/)
   - Naming convention for network files
   - Whether to encrypt entire .psk file or just the passphrase

3. **sops-nix Integration**
   - How to reference WiFi secrets in sops.secrets configuration
   - Correct file permissions for iwd (owner, group, mode)
   - Path where sops-nix should deploy the decrypted files
   - Ensuring secrets are available before iwd starts (systemd ordering)

4. **NixOS Configuration**
   - Module structure for iwd with sops secrets
   - Where this config should live (common vs per-host)
   - How to handle hosts that might need different networks in the future
   - Integration with existing networking configuration

5. **Workflow**
   - How to add a new WiFi network to the encrypted secrets
   - How to update a WiFi password
   - Testing the configuration on mischief first
   - Verification that WiFi connects automatically after rebuild

6. **Documentation**
   - Create runbook in ./docs/wifi-secrets.md
   - Document lifecycle operations:
     - How to add a new WiFi network
     - How to update an existing WiFi password
     - How to remove a WiFi network
     - How to troubleshoot connection failures
   - Include command examples that can be copy-pasted
   - Reference the sops-nix base docs from plan 007 rather than duplicating
</planning_requirements>

<output>
Create a detailed implementation plan saved to:
`./plans/008-sops-wifi-passwords-plan.md`

Also create user documentation:
`./docs/wifi-secrets.md`

The plan should include:
- Overview explaining how WiFi secrets integrate with the sops-nix infrastructure from plan 007
- Prerequisites (assumes plan 007 infrastructure is in place)
- iwd .psk file format reference
- Exact sops.secrets configuration for WiFi networks
- NixOS module code for iwd integration
- Commands for encrypting WiFi passwords with sops
- Verification steps to confirm WiFi connects after rebuild
- Troubleshooting section for common issues

Format the plan so it can be directly executed step-by-step after plan 007 is complete.
</output>

<verification>
Before completing, verify the plan:
- Confirms iwd works on AMD systems (no Intel-specific dependencies)
- Shows exact file format for iwd .psk files
- Includes correct systemd ordering (secrets before iwd)
- Has clear success criteria (WiFi auto-connects after rebuild)
- Is consistent with the sops-nix patterns established in plan 007
- Documentation includes all lifecycle operations with exact commands
</verification>

<success_criteria>
- Complete plan document in ./plans/008-sops-wifi-passwords-plan.md
- User documentation in ./docs/wifi-secrets.md with copy-paste commands
- Plan builds upon (not duplicates) the infrastructure from plan 007
- iwd configuration is fully declarative with sops-managed passwords
- Works across all 3 hosts with shared home network credentials
- Clear workflow for adding/updating/removing WiFi networks
</success_criteria>
