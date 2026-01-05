<objective>
Add Fresh text editor to the NixOS configuration using its official flake input.

Fresh is a terminal-based text editor with standard keybindings (Ctrl+S, Ctrl+Z, etc.), full mouse support, LSP integration, multi-cursor editing, and a built-in file explorer. It's designed to be immediately usable without learning vim/emacs keybindings.

Flake URL: github:sinelaw/fresh
</objective>

<context>
This is a multi-host NixOS dotfiles repository using flakes with home-manager integration.

Review the existing patterns:
- @./flake.nix - See how other flake inputs (claude-code, sops-nix) are added
- @./hosts/common/home.nix - User packages are installed here

Fresh is a user-level application (like neovim, zed-editor) so it belongs in home-manager, not system configuration.
</context>

<requirements>
1. Add Fresh as a flake input in flake.nix:
   ```nix
   fresh.url = "github:sinelaw/fresh";
   fresh.inputs.nixpkgs.follows = "nixpkgs";
   ```

2. Pass the fresh input through to home-manager (similar to how claude-code is handled)

3. Add the fresh package to home.packages in hosts/common/home.nix

4. Run `nix flake update` to lock the new input
</requirements>

<implementation>
Follow the existing pattern for external flake inputs:
1. Add input to flake.nix inputs section
2. Include in the `@inputs` passed to modules
3. Reference as `inputs.fresh.packages.${system}.default` or similar in home.nix

Check the fresh flake's outputs to determine the correct package attribute path. Common patterns:
- `inputs.fresh.packages.${pkgs.system}.default`
- `inputs.fresh.packages.${pkgs.system}.fresh`
</implementation>

<output>
Modify these files:
- `./flake.nix` - Add fresh input
- `./hosts/common/home.nix` - Add fresh to home.packages

Run after editing:
```bash
nix flake update
```
</output>

<verification>
After implementation:
1. Run `nix flake check` to verify syntax
2. Run `nix flake update` to fetch the new input
3. The configuration should be ready for rebuild
4. After rebuild, verify with: `which fresh` or `fresh --version`
</verification>

<success_criteria>
- Fresh flake input added to flake.nix
- Fresh package added to home.packages
- `nix flake check` passes
- After rebuild, `fresh` command is available in PATH
</success_criteria>
