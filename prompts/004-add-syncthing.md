<objective>
Add Syncthing for continuous file synchronization between devices.

Syncthing is a decentralized sync tool - files sync directly between your devices without a central server.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Syncthing on NixOS can be configured as:
1. A system service (services.syncthing) - runs as a specific user
2. A home-manager service (services.syncthing) - runs in user session

Home-manager approach is cleaner for single-user systems and keeps config with other user services.

@configuration.nix - System services
@home.nix - Home-manager configuration (preferred for user services)
</context>

<requirements>
1. Enable Syncthing service to run automatically
2. Configure for user "dustin" with home directory /home/dustin
3. Web GUI accessible at default port (8384)
4. Service should start on login
</requirements>

<implementation>
Add to home.nix:
```nix
services.syncthing = {
  enable = true;
};
```

This enables the home-manager Syncthing module which:
- Starts syncthing as a user service
- Web GUI at http://localhost:8384
- Default sync folder at ~/Sync

No additional configuration needed for basic setup - further device/folder configuration is done via the web GUI.
</implementation>

<output>
Modify `./home.nix` - Add services.syncthing.enable = true
</output>

<verification>
1. Run `home-manager switch --flake .#dustin` (or full nixos-rebuild)
2. Open http://localhost:8384 in browser
3. Syncthing web GUI should load
</verification>

<success_criteria>
- Syncthing service running after rebuild
- Web GUI accessible at localhost:8384
- Service starts automatically on login
</success_criteria>
