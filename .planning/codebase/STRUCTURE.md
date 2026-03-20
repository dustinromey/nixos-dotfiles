# Codebase Structure

**Analysis Date:** 2026-03-20

## Directory Layout

```
nixos-dotfiles/
├── flake.nix                    # Entry point: declares inputs, defines mkHost helper, exports nixosConfigurations
├── hosts/                       # Host configurations (system + home)
│   ├── common/                  # Shared configuration across all hosts
│   │   ├── configuration.nix    # Shared NixOS config (services, display, boot, packages)
│   │   └── home.nix             # Shared home-manager config (packages, LSPs, formatters, symlinks)
│   ├── mischief/                # ThinkPad X270 (Intel i5-6300U, test machine)
│   │   ├── configuration.nix    # Host overrides (hostname, evremap service config)
│   │   ├── home.nix             # Host-specific home overrides (currently empty)
│   │   ├── hardware-configuration.nix  # Generated hardware config
│   │   └── secrets.nix          # Host-specific secrets
│   ├── intrepid/                # Desktop (AMD CPU/GPU, 32GB RAM, daily driver)
│   │   ├── configuration.nix    # AMD Vulkan drivers, AMD GPU env vars, evremap service
│   │   ├── home.nix             # Host-specific home overrides (currently empty)
│   │   ├── hardware-configuration.nix  # Generated hardware config
│   │   └── secrets.nix          # Host-specific secrets
│   └── vigilant/                # Surface Laptop 4 (AMD CPU/GPU, 16GB RAM)
│       ├── configuration.nix    # Surface hardware module, AMD drivers, touchpad, udev rules, evremap service
│       ├── home.nix             # Host-specific home overrides (currently empty)
│       ├── hardware-configuration.nix  # Generated hardware config
│       └── secrets.nix          # Host-specific secrets
├── config/                      # Application configurations (symlinked to ~/.config/)
│   ├── nvim/                    # Neovim config
│   │   ├── init.lua             # Entry point (loads config/ modules via require)
│   │   ├── lua/
│   │   │   ├── config/          # Core config (options, keybinds, lazy plugin manager)
│   │   │   └── plugins/         # Plugin specs (LSP, completion, colors, treesitter, harpoon, telescope, orgmode, etc.)
│   │   ├── after/               # Filetype-specific configs (nix, jsonc, man)
│   │   ├── plugin/              # Plugin initialization (lsp keybinds, quickformat, flterm)
│   │   └── README.md            # Neovim usage guide
│   ├── qtile/                   # Qtile window manager config
│   │   ├── config.py            # Window manager keybinds (vim-style hjkl), layouts, groups, bars
│   │   └── icons/               # Icon assets for taskbar
│   ├── niri/                    # Niri Wayland compositor config
│   │   └── config.kdl           # Niri configuration (KDL format)
│   ├── rofi/                    # Application launcher config
│   │   ├── config.rasi          # Main rofi config (Tokyo Night theme)
│   │   ├── tokyonight.rasi      # Color theme
│   │   ├── stt.rasi             # Speech-to-text specific theme
│   │   └── dwm-config.rasi      # Alternate config
│   ├── ghostty/                 # Terminal emulator config
│   ├── zed/                     # Zed editor config
│   │   └── themes/              # Custom themes
│   ├── waybar/                  # Status bar config (for Niri)
│   │   ├── config               # Waybar layout and widgets
│   │   ├── style.css            # Styling
│   │   ├── icons/               # Icon assets
│   │   └── scripts/             # Custom scripts for widgets
│   ├── mako/                    # Notification daemon config
│   ├── evremap/                 # Key remapping configs (per-host)
│   │   ├── laptop.toml          # Mischief/Vigilant caps lock remapping
│   │   ├── surface.toml         # Vigilant-specific key remapping
│   │   └── rk-s70.toml          # Intrepid desktop keyboard config
│   ├── obs-studio/              # OBS recording config and state
│   │   ├── basic/               # Scene collections and profiles
│   │   ├── plugin_config/       # Plugin settings
│   │   ├── logs/                # Generated logs
│   │   ├── updates/             # Update cache
│   │   └── profiler_data/       # Profiler output
│   ├── bash_aliases.sh          # Bash aliases (sourced in home.nix)
│   ├── bash_functions.sh        # Bash functions (sourced in home.nix)
│   └── fastfetch/               # System info display config
├── bin/                         # User scripts (symlinked to ~/.local/bin/)
│   ├── xtuple                   # xTuple ERP launcher script
│   ├── stt-toggle.sh            # Speech-to-text toggle
│   ├── niri-meeting-setup.sh    # Niri meeting mode setup
│   └── swaylock-random          # Random wallpaper lock screen
├── packages/                    # Custom Nix package definitions
│   └── waystt/                  # Wayland speech-to-text package
│       └── default.nix          # Rust package build with Vulkan GPU acceleration
├── secrets/                     # Encrypted secrets (sops-nix managed)
│   ├── keys/                    # SSH/GPG keys for decryption
│   └── ssh/                     # Host SSH keys
│   └── syncthing/               # Syncthing configuration
├── .planning/                   # GSD planning artifacts (created by /gsd commands)
│   └── codebase/                # Codebase analysis documents
├── docs/                        # Documentation
├── plans/                       # Completed GSD implementation plans
│   └── completed/               # Archive of past plans
├── prompts/                     # GSD prompts (reusable command templates)
│   └── completed/               # Archive of past prompts
├── CLAUDE.md                    # Claude Code project guidelines
├── QUICK-REFERENCE.md           # Quick command reference
├── MIGRATION-GUIDE.md           # NixOS migration guide
├── REFACTOR-SUMMARY.md          # Recent refactoring summary
├── TO-DOS.md                    # Outstanding tasks
├── whats-next.md                # Future plans
└── waystt-nixos-prd.md          # Product requirements for waystt package
```

## Directory Purposes

**flake.nix:**
- Purpose: Flake entry point defining all inputs, outputs, and host configurations
- Contains: Input declarations (nixpkgs, home-manager, sops-nix, ghostty, nixos-hardware, fresh), custom overlay definition, mkHost helper function
- Key code: mkHost function (lines 35-56) encapsulates host configuration assembly

**hosts/common/:**
- Purpose: Shared declarative configuration applied to all hosts
- Contains: System services (X11/Wayland, audio, Bluetooth, printing, VPN), display manager, base packages, boot configuration
- Key files:
  - `configuration.nix`: System-level services, hardware enablement, global packages
  - `home.nix`: User packages (LSPs, formatters, dev tools), symlink definitions, environment variables

**hosts/{hostname}/:**
- Purpose: Host-specific overrides and hardware configuration
- Contains: Hostname declaration, hardware-specific drivers (GPU, touchpad), keyboard remapping service config, secrets import
- Responsibilities per host:
  - **mischief**: ThinkPad config, Intel graphics
  - **intrepid**: Desktop config, AMD Vulkan drivers, RK S70 keyboard
  - **vigilant**: Surface Laptop config, AMD Vulkan drivers, touchpad tweaks, Surface hardware module

**config/:**
- Purpose: Application configurations (symlinked to ~/.config/ by home-manager)
- Structure: One directory per application
- Symlink mechanism: Defined in `hosts/common/home.nix` (lines 227-232) using `xdg.configFile`
- Key point: Configs remain in dotfiles repo, not copied into Nix store (uses `mkOutOfStoreSymlink`)

**bin/:**
- Purpose: Custom user scripts
- Symlink destination: ~/.local/bin/ (symlinked in `hosts/common/home.nix` lines 235-238)
- Usage: Executable from command line as if installed system-wide

**packages/:**
- Purpose: Custom Nix package definitions not in nixpkgs
- Current: waystt speech-to-text with Vulkan GPU acceleration
- Build mechanism: Overlay applied in flake.nix (lines 31-33), used in home.nix

**secrets/:**
- Purpose: Encrypted credentials managed by sops-nix
- Structure: GPG/SSH keys in `secrets/keys/`, host-specific secrets in `hosts/*/secrets.nix`
- Management: Referenced in host configs, decrypted during system activation

## Key File Locations

**Entry Points:**
- `flake.nix`: Flake evaluation entry point, defines all hosts
- `hosts/{hostname}/configuration.nix`: System configuration entry point (imports hardware + common)
- `hosts/{hostname}/home.nix`: Home-manager entry point (imports common)
- `config/nvim/init.lua`: Neovim entry point (requires config modules)
- `config/qtile/config.py`: Qtile entry point (Python configuration)
- `config/niri/config.kdl`: Niri entry point (KDL configuration)

**Configuration:**
- `hosts/common/configuration.nix`: Shared system config (boot, services, packages, hardware)
- `hosts/common/home.nix`: Shared user config (packages, LSPs, formatters, symlinks)
- `hosts/{hostname}/secrets.nix`: Host-specific secrets (sops-nix encrypted)
- `config/{app}/`: Application-specific configs (symlinked to ~/.config/{app}/)

**Core Logic:**
- `flake.nix` (lines 35-56): mkHost helper abstracts host configuration pattern
- `hosts/common/home.nix` (lines 3-6): create_symlink and configs abstraction for application configs
- `hosts/common/home.nix` (lines 227-232): xdg.configFile mapAttrs applies symlink pattern to all apps
- `config/nvim/lua/config/lazy.lua`: Lazy.nvim plugin manager bootstrap

**Testing:**
- Not applicable (declarative infrastructure, tested via `nix flake check` and system activation)

## Naming Conventions

**Files:**
- Nix files: `*.nix` (configuration.nix, home.nix, default.nix, secrets.nix)
- Config files: Lowercase with appropriate extension (config.py, config.rasi, config.kdl, config.toml, init.lua)
- Scripts: Lowercase with `.sh` extension or no extension if executable (bash_aliases.sh, xtuple)
- Generated files: `hardware-configuration.nix` (auto-generated by nixos-generate-config)

**Directories:**
- Lowercase, plural for collections (hosts, packages, config, secrets, bin, docs, plans)
- Host directories: Hostname (mischief, intrepid, vigilant) matching `networking.hostName`
- Application config dirs: App name lowercase (nvim, qtile, rofi, ghostty, zed, waybar, mako, niri, evremap, obs-studio)

**Variables in Nix:**
- Attribute names: camelCase (e.g., homeDirectory, configFile, sessionVariables)
- Functions: camelCase (mkHost, mkDefault, mkOutOfStoreSymlink)
- Let bindings: camelCase (dotfiles, bindir, androidSdk, configs)

## Where to Add New Code

**New host configuration:**
1. Create directory: `mkdir -p hosts/{newhost}`
2. Create `hosts/{newhost}/configuration.nix`:
   ```nix
   { config, lib, pkgs, inputs, ... }:
   {
     imports = [
       ./hardware-configuration.nix
       ../common/configuration.nix
     ];
     networking.hostName = "newhost";
     # Add host-specific overrides
   }
   ```
3. Create `hosts/{newhost}/home.nix`:
   ```nix
   { config, pkgs, inputs, ... }:
   {
     imports = [ ../common/home.nix ];
     # Add host-specific home overrides
   }
   ```
4. Generate hardware config on target: `nixos-generate-config --show-hardware-config > hosts/{newhost}/hardware-configuration.nix`
5. Create `hosts/{newhost}/secrets.nix` (can be empty: `{}`)
6. Add to `flake.nix` outputs: `newhost = mkHost "newhost" "x86_64-linux";`

**New application configuration:**
1. Create directory: `mkdir -p config/{appname}`
2. Add config files appropriate to app
3. Update `hosts/common/home.nix` configs attribute (line 18-31) to include new app
4. Add to home-manager symlink definition

**New system package:**
- Global (all hosts): Add to `hosts/common/configuration.nix` `environment.systemPackages` (line 164)
- Host-specific: Add to `hosts/{hostname}/configuration.nix` `environment.systemPackages`

**New user package (home-manager):**
- Global: Add to `hosts/common/home.nix` `home.packages` (line 36)
- Host-specific: Add to `hosts/{hostname}/home.nix` `home.packages`

**New custom package:**
1. Create `packages/{packagename}/default.nix` with Nix build recipe
2. Reference in overlay in `flake.nix` (lines 31-33)
3. Use in home.packages or environment.systemPackages

**New shell script:**
1. Create in `bin/{scriptname}` (no .sh extension for direct invocation)
2. Add executable flag: `chmod +x bin/{scriptname}`
3. Symlink to ~/.local/bin/ automatically via `hosts/common/home.nix` line 235-238

**New LSP or formatter:**
1. Add package to `hosts/common/home.nix` home.packages (line 36)
2. Configure in `config/nvim/lua/plugins/lsp.lua` if applicable
3. Set keybinds in `config/nvim/lua/config/keybinds.lua`

## Special Directories

**secrets/:**
- Purpose: Store encrypted credentials (sops-nix managed)
- Generated: No (manually created encrypted files)
- Committed: Yes (to git, encrypted by sops-nix)
- Usage: Imported in `hosts/{hostname}/secrets.nix`, values available during activation

**config-overrides/:**
- Purpose: Per-host configuration overrides (optional, currently not in use)
- Generated: No
- Committed: Yes
- Structure: `config-overrides/{hostname}/` for overrides

**docs/:**
- Purpose: Additional documentation
- Generated: No
- Committed: Yes

**.planning/codebase/:**
- Purpose: GSD codebase analysis documents (ARCHITECTURE.md, STRUCTURE.md, STACK.md, CONVENTIONS.md, TESTING.md, CONCERNS.md)
- Generated: Yes (by /gsd:map-codebase)
- Committed: Yes (to git)

**plans/ and prompts/:**
- Purpose: Archive of GSD implementation plans and reusable prompts
- Generated: Yes (by /gsd commands)
- Committed: Yes

---

*Structure analysis: 2026-03-20*
