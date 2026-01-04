# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a NixOS dotfiles repository ("Romey NixOS") managing a complete development environment across multiple hosts. It uses Nix flakes with home-manager integration and a modular configuration structure.

## Supported Hosts

- **mischief**: Lenovo ThinkPad X270, Intel i5-6300U, Intel HD 520 GPU (test machine)
- **intrepid**: Desktop, AMD CPU/GPU, 32GB RAM (daily driver)
- **vigilant**: Microsoft Surface Laptop 4, AMD CPU/GPU, 16GB RAM

## Common Commands

**Rebuild NixOS system (host-specific):**
```bash
# On mischief:
sudo nixos-rebuild switch --flake .#mischief

# On intrepid:
sudo nixos-rebuild switch --flake .#intrepid

# On vigilant:
sudo nixos-rebuild switch --flake .#vigilant
```

**Rebuild home-manager configuration:**
```bash
home-manager switch --flake .#dustin
```

**Format Nix files:**
```bash
nixfmt-rfc-style <file.nix>
```

**Check flake validity:**
```bash
nix flake check
```

## Architecture

```
flake.nix                    # Entry point: defines all hosts (mischief, intrepid, vigilant)
├── hosts/
│   ├── common/
│   │   ├── configuration.nix  # Shared NixOS config (boot, display, services, fonts)
│   │   └── home.nix           # Shared home-manager config (symlinks config/*, dev packages)
│   ├── mischief/              # ThinkPad X270 (Intel)
│   │   ├── configuration.nix  # Host-specific overrides + hostname
│   │   ├── home.nix           # Host-specific home overrides
│   │   └── hardware-configuration.nix
│   ├── intrepid/              # Desktop (AMD)
│   │   ├── configuration.nix  # AMD GPU drivers + hostname
│   │   ├── home.nix           # Host-specific home overrides
│   │   └── hardware-configuration.nix
│   └── vigilant/              # Surface Laptop (AMD)
│       ├── configuration.nix  # AMD GPU + touchpad + hostname
│       ├── home.nix           # Host-specific home overrides
│       └── hardware-configuration.nix
├── config/                    # Shared application configs (symlinked to ~/.config/)
│   ├── nvim/                 # Primary editor (Lua config, lazy.nvim)
│   ├── qtile/                # Window manager (Python, vim-style keybinds)
│   ├── rofi/                 # App launcher (Tokyo Night theme)
│   ├── ghostty/              # Terminal emulator
│   ├── zed/                  # Secondary editor
│   ├── niri/                 # Wayland compositor
│   ├── waybar/               # Status bar
│   └── fastfetch/            # System info display
└── config-overrides/          # Per-host config overrides (optional)
    ├── intrepid/
    └── vigilant/
```

## Key Design Decisions

- **Modular multi-host setup**: Common configuration in `hosts/common/`, host-specific overrides in `hosts/<hostname>/`
- **LSP servers installed via Nix** (home.nix), not Mason - maintains full system control
- **Config symlinks**: All app configs live in `config/` and are symlinked to `~/.config/` by home-manager
- **Hardware-specific configurations**: AMD GPU support for intrepid/vigilant, Intel for mischief
- **Shared by default**: All hosts share the same base configuration unless overridden
- **lib.mkDefault**: Used in common config to allow host-specific overrides
- **Neovim**: Uses lazy.nvim package manager, LSP keybinds are `gd` (definition), `gr` (references), `K` (hover), `<F2>` (rename), `<F3>` (format), `<F4>` (code actions)
- **Window manager**: Qtile with vim-style navigation (Super+hjkl), Super+Space for Rofi launcher

## Adding a New Host

1. Create directory: `mkdir -p hosts/newhost`
2. Create `hosts/newhost/configuration.nix`:
   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [
       ./hardware-configuration.nix
       ../common/configuration.nix
     ];
     networking.hostName = "newhost";
     # Add host-specific overrides here
   }
   ```
3. Create `hosts/newhost/home.nix`:
   ```nix
   { config, pkgs, inputs, ... }:
   {
     imports = [ ../common/home.nix ];
     # Add host-specific home overrides here
   }
   ```
4. Generate hardware config on the target machine:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/newhost/hardware-configuration.nix
   ```
5. Add to `flake.nix` outputs:
   ```nix
   nixosConfigurations.newhost = mkHost "newhost" "x86_64-linux";
   ```

## Installed Language Servers

Defined in hosts/common/home.nix: nixd, pyright, rust-analyzer, gopls, typescript-language-server, lua-language-server, bash-language-server, sqls, fish-lsp

## Installed Formatters

nixfmt-rfc-style, black (Python), rustfmt, stylua (Lua), prettier (JS/TS), shfmt (Bash), goimports (Go)
