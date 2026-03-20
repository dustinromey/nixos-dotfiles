# Testing Patterns

**Analysis Date:** 2026-03-20

## Test Framework

**Runner:**
- Not detected - No automated test framework integrated

**Assertion Library:**
- Not applicable - No test framework present

**Run Commands:**
- No test commands configured
- Manual validation via `nix flake check` for Nix syntax
- Manual validation via `nixos-rebuild switch --flake .#hostname` for system config

## Test File Organization

**Location:**
- Not applicable - No test files in codebase

**Naming:**
- Not applicable

**Structure:**
- Not applicable

## Test Structure

**Suite Organization:**
- Not applicable - No test suites present

**Patterns:**
- Not applicable

## Mocking

**Framework:**
- Not applicable

**Patterns:**
- Not applicable

**What to Mock:**
- Not applicable

**What NOT to Mock:**
- Not applicable

## Fixtures and Factories

**Test Data:**
- Not applicable

**Location:**
- Not applicable

## Coverage

**Requirements:**
- None enforced

**View Coverage:**
- Not applicable

## Test Types

**Unit Tests:**
- Not present - This is a NixOS dotfiles configuration repository, not a library or application with testable units

**Integration Tests:**
- Not present - Configuration validation done through:
  - `nix flake check` for flake syntax validation
  - `nixos-rebuild switch --flake .#hostname` for actual system rebuild (on target host)
  - Manual host-specific testing (rebuild on test machine first)

**E2E Tests:**
- Not used - Manual testing on physical hardware (mischief, intrepid, vigilant)

## Testing Strategy & Validation

**Manual Validation Process:**

Configuration changes are validated through a staged approach:

1. **Syntax Check:** `nix flake check` validates Nix syntax before rebuild
2. **Dry Run:** `nixos-rebuild switch --flake .#hostname -d` (from CLAUDE.md) shows what will change
3. **Test Machine First:** Always rebuild on mischief (ThinkPad X270) before rolling out to intrepid/vigilant
4. **Full Rebuild:** `sudo nixos-rebuild switch --flake .#hostname` applies changes to system

**Module Validation:**
- Home-manager configuration validated via `home-manager switch --flake .#dustin`
- System configuration validated via rebuild to target host

**Script Testing:**
- Bash scripts in `bin/` are tested manually on target system
- Scripts follow defensive patterns: `set -euo pipefail` prevents silent failures
- Error handling visible through exit codes and echo output

Examples of testable concerns:
- `bin/stt-toggle.sh`: Tests waystt process lifecycle (check if running, lock file management)
- `bin/xtuple`: Tests directory existence, Docker image presence, X11 display detection
- `bin/swaylock-random`: Tests wallpaper file detection and locking

## Validation Tools Present

**Nix Tools (from hosts/common/home.nix):**
- `nixd` (line 38): Nix language server - detects syntax errors
- `nixfmt-rfc-style` (line 39): Nix code formatter - enforces style

**Formatters (from hosts/common/home.nix):**
- `nixfmt-rfc-style` (line 39): Nix formatter
- `black` (line 43): Python formatter
- `rustfmt` (line 41): Rust formatter
- `stylua` (line 45): Lua formatter
- `prettier` (line 49): JavaScript/TypeScript formatter
- `shfmt` (line 51): Bash script formatter

**Usage:**
```bash
# Format Nix files
nixfmt-rfc-style <file.nix>

# Check for syntax errors
nix flake check

# Dry run rebuild to see what changes
sudo nixos-rebuild switch --flake .#hostname -d

# Build without switching system
sudo nixos-rebuild build --flake .#hostname
```

## Testing Limitations & Considerations

**Why No Automated Tests:**
1. Configuration repository - Testing happens at system level, not unit level
2. Hardware-specific (three different hosts with different GPUs, inputs)
3. Services and integrations (Tailscale, Docker, Syncthing) require runtime environment
4. Desktop environment dependencies (X11, Wayland, window managers)

**Practical Testing Approach:**
- Stage changes on test machine (`mischief`) first
- Use dry-run rebuilds to preview system changes
- Manual smoke tests on each host after rebuild
- Document known issues in system logs via `journalctl`

**Risk Mitigation:**
- Use `lib.mkDefault` throughout common configuration to allow host-specific overrides without errors
- Separate common and host-specific configurations to isolate impact
- Keep backups by setting `backupFileExtension = "backup"` in flake.nix (line 52)

## Common Testing Patterns in Scripts

**Bash Script Testing Patterns (from bin/ directory):**

**File/Directory Checks:**
From `bin/xtuple` lines 8-17:
```bash
if [[ ! -d "$XTUPLE_DIR" ]]; then
    echo "Error: xTuple-Portable directory not found at $XTUPLE_DIR"
    exit 1
fi

if [[ ! -x "$RUN_SCRIPT" ]]; then
    echo "Error: run-xtuple.sh not found or not executable at $RUN_SCRIPT"
    exit 1
fi
```

**Process Checks:**
From `bin/stt-toggle.sh` line 54:
```bash
if pgrep -x waystt > /dev/null; then
    stop_recording
else
    start_recording
fi
```

**Docker/Service Checks:**
From `bin/xtuple` lines 20-23:
```bash
if ! docker image inspect xtuple-cpal:latest &>/dev/null; then
    echo "xTuple Docker image not found. Building..."
    cd "$XTUPLE_DIR/qt-client" && ./build-xtuple.sh
fi
```

**Display/Environment Detection:**
From `bin/xtuple` lines 27-32:
```bash
XTUPLE_DPI="${XTUPLE_DPI:-168}"
for d in 0 1 2; do
    if [ -S "/tmp/.X11-unix/X$d" ]; then
        DISPLAY=":$d" xrdb -merge <<< "Xft.dpi: $XTUPLE_DPI" 2>/dev/null
        break
    fi
done
```

## Configuration Testing Pattern

**Nix Dry-Run Workflow:**

When making changes to configuration:

1. **Make changes** to `hosts/<hostname>/configuration.nix` or `hosts/common/configuration.nix`
2. **Run syntax check:**
   ```bash
   nix flake check
   ```
3. **Preview changes (dry-run):**
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname> -d
   ```
4. **Review output** for unintended changes
5. **Apply if safe:**
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

This approach provides safety without requiring test suites.

---

*Testing analysis: 2026-03-20*
