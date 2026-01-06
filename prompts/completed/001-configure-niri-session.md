<objective>
Configure Niri as an available session option in the display manager, ensuring the existing config.kdl symlink works properly.

Niri is already installed in configuration.nix and the config symlink is set up in home.nix. The goal is to make Niri selectable from the ly display manager at login.
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Current state:
- Niri package is in `configuration.nix` environment.systemPackages
- Config symlink configured in `home.nix` configs map (niri = "niri")
- Display manager is ly (services.displayManager.ly.enable = true)
- Currently using X11 + Qtile as window manager

@flake.nix - Current flake structure
@configuration.nix - System configuration
@home.nix - Home-manager configuration
@config/niri/config.kdl - Niri configuration file
</context>

<requirements>
1. Enable Niri as a Wayland compositor session option
2. Ensure ly display manager shows Niri as a selectable session
3. Keep Qtile as an option (don't remove existing X11 setup)
4. Verify the config.kdl symlink path will work (~/.config/niri/config.kdl)
</requirements>

<implementation>
In NixOS, Niri can be enabled via `programs.niri.enable = true` which automatically:
- Creates the session file for display managers
- Sets up proper Wayland environment variables

Add to configuration.nix:
```nix
programs.niri.enable = true;
```

This is the lightweight approach - the package is already installed, this just enables the session.
</implementation>

<output>
Modify `./configuration.nix` to enable the Niri session.
</output>

<verification>
After changes, user should:
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. Log out and check ly display manager for "niri" session option
</verification>

<success_criteria>
- Niri appears as a session option in ly display manager
- Selecting Niri boots into the Wayland compositor
- Existing Qtile/X11 session still available
</success_criteria>
