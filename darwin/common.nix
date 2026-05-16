{ config, pkgs, lib, ... }:

{
  #############################################################################
  # Identity
  #############################################################################

  system.primaryUser = "dustin";

  users.users.dustin = {
    name = "dustin";
    home = "/Users/dustin";
  };

  system.stateVersion = 6;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  #############################################################################
  # Keyboard — Ctrl <-> Cmd swap (declarative)
  #############################################################################

  # nix-darwin has no direct Ctrl<->Cmd swap option, so we drive hidutil via
  # userKeyMapping. Decimal values for HID usage codes (Nix lacks hex literals):
  #   30064771296 = 0x7000000E0 = Left Control
  #   30064771299 = 0x7000000E3 = Left Command (GUI)
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [
      { HIDKeyboardModifierMappingSrc = 30064771296; HIDKeyboardModifierMappingDst = 30064771299; }
      { HIDKeyboardModifierMappingSrc = 30064771299; HIDKeyboardModifierMappingDst = 30064771296; }
    ];
  };

  #############################################################################
  # macOS settings — typed options (system.defaults)
  #############################################################################

  system.defaults = {
    NSGlobalDomain = {
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      AppleInterfaceStyle = "Dark";
    };

    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 44;
      mru-spaces = false;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  #############################################################################
  # macOS settings — arbitrary domains (CustomUserPreferences)
  #############################################################################
  #
  # Capture workflow:
  #   1. Set the shortcut by hand in System Settings.
  #   2. defaults read com.apple.symbolichotkeys > /tmp/hotkeys.txt
  #      defaults read -g NSUserKeyEquivalents
  #   3. Transcribe the relevant entries into the blocks below.
  #   4. darwin-rebuild switch, then log out / restart the affected app.
  #
  system.defaults.CustomUserPreferences = {
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = { };
    };

    "NSGlobalDomain" = {
      NSUserKeyEquivalents = { };
    };
  };

  #############################################################################
  # nix-homebrew — declarative Homebrew bootstrap
  #############################################################################

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    user = "dustin";
    autoMigrate = true;
  };

  #############################################################################
  # Homebrew — taps, casks, brews, masApps
  #############################################################################

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    taps = [
      "BarutSRB/tap"
    ];

    brews = [
      "mas"
      "mpv"
    ];

    casks = [
      "claude"

      "brave-browser"

      "ghostty"
      "zed"
      "obsidian"

      "bitwarden"
      "raycast"

      # Native macOS mpv front-end (mpv itself has no cask)
      "iina"
      "obs"

      # FileZilla was removed from Homebrew over bundled-installer concerns;
      # Cyberduck is the open-source SFTP/FTP/WebDAV replacement.
      "cyberduck"
      # The bare `tailscale` cask was deprecated; `-app` is the current name.
      "tailscale-app"
      # Native macOS Syncthing GUI (the `syncthing` formula is CLI-only).
      "syncthing-app"

      # Tiling WM with Niri-style scrolling columns (via BarutSRB/tap above).
      "omniwm"

      "font-jetbrains-mono-nerd-font"
      "font-hack"

      # TODO: Anthropic Cowork has no Homebrew cask as of 2026-05-16 —
      # install manually until a tap exists.
    ];

    masApps = { };
  };
}
