<objective>
Install Obsidian notes app and wl-clipboard for Wayland clipboard support.

- Obsidian: Markdown-based note-taking app
- wl-clipboard: Provides wl-copy and wl-paste for Wayland clipboard operations
</objective>

<context>
This is a NixOS flake-based system. Read CLAUDE.md for project conventions.

Obsidian is unfree software - may need allowUnfree configuration.
wl-clipboard is needed for clipboard operations in Wayland (Niri).

@home.nix - Add packages here (user-level installation)
</context>

<requirements>
1. Add `obsidian` to home.nix home.packages
2. Add `wl-clipboard` to home.nix home.packages
3. Ensure unfree packages are allowed for obsidian (check allowUnfreePredicate)
</requirements>

<implementation>
Step 1: Add to home.nix home.packages:
```nix
obsidian
wl-clipboard
```

Step 2: Add "obsidian" to the allowUnfreePredicate list if not already allowed:
```nix
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (pkgs.lib.getName pkg) [
    "claude-code"
    "obsidian"
  ];
```
</implementation>

<output>
Modify `./home.nix`:
- Add obsidian and wl-clipboard to home.packages
- Add "obsidian" to allowUnfreePredicate list
</output>

<verification>
1. Run `sudo nixos-rebuild switch --flake .#mischief`
2. Run `obsidian` to launch the app
3. Test clipboard: `echo "test" | wl-copy && wl-paste`
</verification>

<success_criteria>
- Obsidian launches successfully
- wl-copy and wl-paste commands work
</success_criteria>
