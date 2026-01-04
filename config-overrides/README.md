# Config Overrides

This directory contains per-host overrides for application configurations.

## Purpose

While the main `config/` directory contains shared application configurations used across all hosts, this directory allows you to override specific configs for individual hosts.

## Usage

To override a config for a specific host:

1. Create a subdirectory matching the application name (e.g., `intrepid/nvim/`)
2. Place the override config files in that directory
3. Update the host's `home.nix` to symlink the override instead of the common config

## Example

To use a different Neovim config on `intrepid`:

```bash
mkdir -p config-overrides/intrepid/nvim
# Copy and modify config files...
```

Then in `hosts/intrepid/home.nix`:

```nix
xdg.configFile.nvim = {
  source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-dotfiles/config-overrides/intrepid/nvim";
  recursive = true;
};
```

## Current Hosts

- `intrepid/` - Desktop AMD overrides
- `vigilant/` - Surface Laptop overrides
