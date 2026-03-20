# Coding Conventions

**Analysis Date:** 2026-03-20

## Naming Patterns

**Files:**
- Nix files: `lowercase-with-hyphens.nix` (e.g., `configuration.nix`, `hardware-configuration.nix`)
- Lua files: `kebab-case.lua` for module/plugin files (e.g., `lazy.lua`, `lsp.lua`)
- Python files: `snake_case.py` (e.g., `config.py`)
- Bash/shell scripts: `kebab-case` with `.sh` extension or no extension (e.g., `stt-toggle.sh`)

**Functions:**
- Lua: `snake_case` for local functions, `camelCase` for Neovim API calls (e.g., `enable_transparency()`, `vim.lsp.buf.format()`)
- Python (Qtile): `snake_case` for function definitions and variable names
- Bash: `snake_case` for function definitions (e.g., `start_recording()`, `stop_recording()`)
- Nix: `camelCase` for function names in let bindings (e.g., `mkHost`, `create_symlink`)

**Variables:**
- Local variables: `snake_case` in Lua, Python, Bash
- Global constants: `UPPERCASE_WITH_UNDERSCORES` in Bash (e.g., `LOCK_FILE`, `YDOTOOL_SOCKET`)
- Lua table keys: lowercase (e.g., `vim.opt`, `config.home`)
- Nix attribute names: `camelCase` (e.g., `networking.hostName`, `services.tailscale.enable`)

**Types:**
- Nix attribute sets use nested lowercase paths (e.g., `boot.loader.systemd-boot.enable`)

## Code Style

**Formatting:**
- Nix: 2-space indentation (via `nixfmt-rfc-style` as noted in CLAUDE.md)
- Lua: 4-space indentation (observed in `config/nvim/lua/config/options.lua`)
- Python: 4-space indentation (standard PEP 8)
- Bash: 4-space indentation for nested structures

**Linting:**
- Nix: `nixfmt-rfc-style` is the standard formatter (installed in `hosts/common/home.nix` line 39)
- Lua: No explicit linter configured; follows Neovim conventions
- Python: No explicit linter configured
- Bash: `shfmt` is installed in `hosts/common/home.nix` line 51

## Import Organization

**Nix:**
Order is semantic rather than strict:
1. Module imports (`imports = [...]`)
2. Let bindings for local definitions
3. Configuration attributes

Example from `flake.nix` lines 28-57:
```nix
outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    overlay = final: prev: { ... };
    mkHost = hostname: system: ...;
  in
  { nixosConfigurations = { ... }; };
```

**Lua:**
Order follows lazy.nvim plugin structure:
1. Table return statement
2. Plugin dependencies array
3. Configuration functions

Example from `config/nvim/lua/plugins/telescope.lua` lines 1-6:
```lua
return {
    'nvim-telescope/telescope.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
    config = function() ... end
}
```

**Python:**
Standard Python convention - imports at top:
1. Standard library imports
2. Third-party imports

Example from `config/qtile/config.py` lines 1-6:
```python
from libqtile import bar, extension, hook, layout, qtile, widget
from libqtile.config import Click, Drag, Group, Key, KeyChord, Match, Screen
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal
import os
import subprocess
```

**Bash:**
Minimal organization:
1. Shebang `#!/usr/bin/env bash`
2. File header comment with description
3. `set` options (e.g., `set -euo pipefail`)
4. Global variable definitions

Example from `bin/stt-toggle.sh` lines 1-14:
```bash
#!/usr/bin/env bash
# stt-toggle.sh - Toggle waystt with Rofi visual feedback
# Usage: stt-toggle.sh [type|clipboard]

set -euo pipefail

LOCK_FILE="/tmp/waystt-recording"
ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/stt.rasi"
```

**Path Aliases:**
Not used in this codebase. Absolute paths with variable substitution instead:
- Nix: `${config.home.homeDirectory}`, `${pkgs.path}`, `${inputs.package}`
- Bash: `$HOME`, `$(id -u)`, `$(pwd)`

## Error Handling

**Patterns:**

**Bash:** Defensive scripting patterns:
- Exit on error: `set -euo pipefail` at top of script
- Safe variable access: `${VAR:-default}` for defaults
- Check command existence: `if [[ ! -x "$RUN_SCRIPT" ]]`
- Redirect errors to `/dev/null`: `2>/dev/null` or `2>&1`
- Null output suppression: `&>/dev/null` for conditional checks

Example from `bin/xtuple` lines 7-22:
```bash
if [[ ! -d "$XTUPLE_DIR" ]]; then
    echo "Error: xTuple-Portable directory not found at $XTUPLE_DIR"
    echo "Please ensure xTuple-Portable is synced via Syncthing."
    exit 1
fi
```

**Lua:** Vim API patterns with direct returns:
- No explicit try-catch; rely on Vim's error handling
- Check client availability before operations: `if not client then return end`
- Use `if not ... then return` pattern for guard clauses

Example from `config/nvim/lua/plugins/lsp.lua` (commented) lines 24-26:
```lua
local client = vim.lsp.get_client_by_id(args.data.client_id)
if not client then return end
```

**Nix:** Configuration-based error prevention:
- Assertions and type checking via module system
- Use `lib.mkDefault` to allow overrides without errors: `boot.loader.systemd-boot.enable = lib.mkDefault true;`

## Logging

**Framework:** `console` (Bash, Lua, Python) - no structured logging framework

**Patterns:**

**Bash:**
- Echo to stdout for messages: `echo "message"`
- Echo to stderr for errors: `echo "Error: message" >&2`
- Use `notify-send` for desktop notifications from scripts: `notify-send -t 2000 "STT" "Transcription complete"`

Example from `bin/stt-toggle.sh` line 45:
```bash
notify-send -t 2000 "STT" "Transcription complete"
```

**Lua (Neovim):**
- Print to Neovim: `print("message")`
- Use vim API for echo: `vim.api.nvim_echo({{"message"}}, true, {})`
- Debug output via `vim.notify()` when available

**Python:**
- Standard `print()` for output
- No structured logging observed

## Comments

**When to Comment:**
- Explain non-obvious decisions (e.g., "We therefore defer the check until the key binding is run by using .when(func=...)" in `config/qtile/config.py` line 67)
- Mark sections with single-line headers: `-- KEYBINDS` (Lua), `# OPTIONS` (Lua), `mod = "mod4"` (Python)
- Document workarounds and exceptions
- Keep comments aligned with code logic

**JSDoc/TSDoc:**
Not applicable - no TypeScript/JavaScript in primary codebase

**Style Examples:**

Nix comments:
```nix
# Enable CUPS to print documents.
services.printing.enable = lib.mkDefault true;
```

Lua section markers (from `config/nvim/lua/config/options.lua` line 1):
```lua
-- OPTIONS
local set = vim.opt
```

Bash inline comments:
```bash
# ydotool socket location (NixOS default)
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}"
```

## Function Design

**Size:**
- Bash functions: 10-50 lines typical (e.g., `start_recording()` is ~30 lines)
- Lua functions: 5-20 lines typical, keep plugins under 50 lines
- Python classes/functions: Qile config style inline definitions

**Parameters:**

**Bash:**
- Positional parameters only: `$1`, `$2`
- Default values via `${param:-default}`: `MODE="${1:-type}"`

Example from `bin/stt-toggle.sh` line 14:
```bash
MODE="${1:-type}"
```

**Lua:**
- Table-based configuration passed to functions
- Anonymous functions for callbacks: `function() ... end`

Example from `config/nvim/lua/plugins/telescope.lua` line 28:
```lua
vim.keymap.set('n', '<leader>fg', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)
```

**Return Values:**

**Bash:** Exit codes only (0 for success, non-zero for failure)

**Lua:** Return values in tables or direct values
- Functions can return multiple values (via tables)
- Commonly return tables for configuration

**Python:** Direct return values or tuples

## Module Design

**Exports:**

**Lua plugins:** Always return a table from plugin files:
```lua
return {
    'plugin/name',
    config = function() ... end
}
```

Example from `config/nvim/lua/plugins/colors.lua` lines 7-15:
```lua
return {
    {
        "folke/tokyonight.nvim",
        config = function()
            vim.cmd.colorscheme "tokyonight"
        end
    },
}
```

**Bash scripts:** Single responsibility per script, no module exports (functions are local)

**Nix modules:** Use `imports` to compose, attributes define configuration:
```nix
{ config, lib, pkgs, ... }:
{
  imports = [ ../common/configuration.nix ];
  networking.hostName = "hostname";
}
```

**Barrel Files:**
Not used in this codebase. Config files are directly imported or sourced.

**Load Pattern in Nix (home.nix):**
From `hosts/common/home.nix` lines 227-232:
```nix
xdg.configFile = builtins.mapAttrs
  (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  })
  configs;
```
This maps config directories to `.config/` via symlinks.

---

*Convention analysis: 2026-03-20*
