# darwin.nix — starter nix-darwin module for macOS hosts
#
# A STARTING POINT, not a finished config. It is meant to live in your flake
# next to hosts/common/configuration.nix and be wired in through a
# `darwinConfigurations` output (see macos-dotfiles-prd.md for the flake work).
#
# Two areas need YOUR input:
#   1. homebrew.casks / homebrew.masApps — fill from the PRD app inventory.
#   2. CustomUserPreferences keyboard-shortcut blocks — capture with
#      `defaults read` per the comments below; they cannot be hand-authored
#      reliably from memory.

{ config, pkgs, lib, ... }:

{
  #############################################################################
  # Identity
  #############################################################################

  # Recent nix-darwin wants a primary user for user-scoped options
  # (homebrew, parts of system.defaults). Set to your macOS username.
  system.primaryUser = "dustin";

  users.users.dustin = {
    name = "dustin";
    home = "/Users/dustin";
  };

  # Bump only when the nix-darwin release notes tell you to.
  system.stateVersion = 6;

  nixpkgs.config.allowUnfree = true;

  # Flakes for darwin-rebuild.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NOTE: if you install Nix with the Determinate Systems installer, let it
  # own the Nix daemon and set `nix.enable = false;` here to avoid a conflict.
  # With the stock/nix-darwin-managed Nix, leave nix.enable at its default.

  #############################################################################
  # Keyboard — modifier remapping (first-class, declarative)
  #############################################################################
  #
  # Equivalent to System Settings > Keyboard > Modifier Keys.
  # enableKeyMapping MUST be true for any swap option to take effect.
  #
  system.keyboard = {
    enableKeyMapping = true;

    # Your Ctrl <-> Cmd swap.
    swapLeftCtrlAndLeftCmd = true;

    # Other swaps available (uncomment as needed):
    # swapLeftCommandAndLeftAlt = false;
    # remapCapsLockToControl    = false;
    # remapCapsLockToEscape     = false;
  };
  #
  # This applies per keyboard. After a rebuild, verify on BOTH the internal
  # keyboard and any external keyboard. For per-key remapping finer than
  # whole-modifier swaps, use a launchd `hidutil` agent (example at bottom).

  #############################################################################
  # macOS settings — typed options (system.defaults)
  #############################################################################
  #
  # nix-darwin models a curated subset of `defaults` keys. Anything not
  # modeled here goes in CustomUserPreferences below.
  #
  system.defaults = {
    NSGlobalDomain = {
      # Fast key repeat (good for vim). Lower = faster.
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      # Disable the press-and-hold accent popup so key repeat works everywhere.
      ApplePressAndHoldEnabled = false;
      # Don't auto-substitute smart quotes / dashes (annoying when coding).
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      AppleInterfaceStyle = "Dark";
    };

    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 44;
      mru-spaces = false;          # don't auto-reorder Spaces (matters for tiling WMs)
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv";   # list view
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
    };

    trackpad = {
      Clicking = true;             # tap to click
      TrackpadThreeFingerDrag = true;
    };
  };

  #############################################################################
  # macOS settings — arbitrary domains (CustomUserPreferences)
  #############################################################################
  #
  # For any `defaults` domain/key nix-darwin doesn't model — INCLUDING
  # keyboard shortcuts. No friendly options exist; you write the raw structure.
  #
  # >>> CAPTURE WORKFLOW <<<
  #   1. Set the shortcut once, by hand, in System Settings.
  #   2. Dump the resulting structure:
  #        defaults read com.apple.symbolichotkeys > /tmp/hotkeys.txt
  #        defaults read -g NSUserKeyEquivalents
  #   3. Transcribe the relevant entries into the blocks below.
  #   4. `darwin-rebuild switch`, then LOG OUT / restart the affected app —
  #      these keys are read at login / app launch, not applied live. cfprefsd
  #      also caches prefs, so a change can look like a no-op until it recycles.
  #
  system.defaults.CustomUserPreferences = {

    # --- System-wide shortcuts (Mission Control, screenshots, Spotlight...) ---
    #
    # Each shortcut is a numbered AppleSymbolicHotKey entry. The `parameters`
    # array is [ ASCII-code, virtual-keycode, modifier-bitmask ].
    # Modifier bitmask: Cmd=1048576  Shift=131072  Ctrl=262144  Opt=524288
    # (sum for combos; 65535 in slot 0 means "no ASCII character").
    #
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        # 64 = Spotlight. Example below is the DEFAULT Cmd+Space —
        # replace with your captured values, or disable it (see note).
        "64" = {
          enabled = 1;
          value = {
            type = "standard";
            parameters = [ 32 49 1048576 ];
          };
        };
        # To DISABLE a shortcut (e.g. to free Cmd+Space for a launcher),
        # set `enabled = 0;` and keep the value block.
      };
    };

    # --- Per-app menu shortcuts (NSUserKeyEquivalents) ---
    #
    # Keyed by the EXACT menu item title. Modifier glyphs in the value string:
    #   @ = Cmd   ~ = Opt   ^ = Ctrl   $ = Shift     e.g. "@$t" = Cmd+Shift+T
    #
    "NSGlobalDomain" = {
      NSUserKeyEquivalents = {
        # "Show Help menu" = "~^/";   # example
      };
    };
    # Per specific app — key by the app's bundle preference domain:
    # "com.apple.Safari" = {
    #   NSUserKeyEquivalents = { "Merge All Windows" = "@$m"; };
    # };
  };

  #############################################################################
  # Homebrew — declarative GUI apps
  #############################################################################
  #
  # nix-darwin DRIVES Homebrew but does not install it. Either install
  # Homebrew once per machine, or add the nix-homebrew flake input for a
  # declarative bootstrap (see PRD).
  #
  # cleanup = "zap" removes anything not listed here — true declarative state.
  # Start with "uninstall" if "zap" feels too aggressive.
  #
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [
      # "nikitabobko/tap"   # for aerospace, if adopted
    ];

    # CLI formulae. Most CLI tools should stay in Nix (home.nix) instead —
    # list here only the few that are genuinely better from Homebrew.
    brews = [
      # "mas"   # needed if you use masApps below
    ];

    # GUI applications. FILL FROM THE PRD INVENTORY.
    # Verify each cask name with `brew search <name>` before committing.
    casks = [
      # "ghostty"
      # "obsidian"
      # "brave-browser"
      # "zed"
      # "raycast"
      # "tailscale"
      # "bitwarden"
      # "syncthing"
      # "font-jetbrains-mono-nerd-font"
      # "font-hack"
    ];

    # Mac App Store apps, keyed by numeric ID. Find IDs with `mas search <name>`.
    # Requires `mas` (add to `brews`) and a signed-in App Store.
    masApps = {
      # "Tailscale" = 1475387142;
    };
  };

  #############################################################################
  # Optional: per-key remapping via hidutil
  # (only if whole-modifier swaps above aren't enough)
  #############################################################################
  #
  # launchd.user.agents.hidremap = {
  #   command = ''
  #     /usr/bin/hidutil property --set '{"UserKeyMapping":[
  #       {"HIDKeyboardModifierMappingSrc":0x7000000XX,
  #        "HIDKeyboardModifierMappingDst":0x7000000YY}
  #     ]}'
  #   '';
  #   serviceConfig = {
  #     RunAtLoad = true;
  #     KeepAlive = false;
  #   };
  # };
}
