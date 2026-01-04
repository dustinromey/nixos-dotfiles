{ config, pkgs, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  bindir = "${config.home.homeDirectory}/nixos-dotfiles/bin";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Standard .config/directory
  configs = {
    qtile = "qtile";
    nvim = "nvim";
    ghostty = "ghostty";
    zed = "zed";
    rofi = "rofi";
    fastfetch = "fastfetch";
    niri = "niri";
    btop = "btop";
    waybar = "waybar";
    mako = "mako";
  };
in

{
# --- Config for Claude Code & Gemini CLI ---
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code"
      "obsidian"
      "unrar"
    ];

  # 1. Install Zed and the required Language Servers
  home.packages = with pkgs; [
    # --- Language Servers (LSPs) & Formatters ---
    nixd
    nixfmt-rfc-style
    rust-analyzer
    rustfmt
    pyright       # Type checker / LSP
    black         # Formatter
    lua-language-server
    stylua
    gopls
    gotools       # contains goimports, etc.
    nodePackages.typescript-language-server
    nodePackages.prettier # Common formatter
    nodePackages.bash-language-server
    shfmt
    nodePackages.vscode-langservers-extracted # Contains JSON LS
    sqls          # SQL Language Server
    fish-lsp

    # Fonts (Required for your 'Hack' terminal setting)
    hack-font

    # command-line programs
    neovim
    bat              # cat replacement with syntax highlighting
    ripgrep
    curl             # HTTP client
    # Archive tools (for extract function)
    unzip
    unrar
    p7zip
    gnutar
    gzip
    bzip2
    nil
    nixpkgs-fmt
    nodejs_22
    gcc
    rofi-wayland  # Works on both X11 (Qtile) and Wayland (Niri)
    zed-editor
    fastfetch
    btop
    claude-code
    waybar
    impala       # WiFi TUI
    bluetui      # Bluetooth TUI
    obsidian     # Markdown notes app
    wl-clipboard # Wayland clipboard (wl-copy, wl-paste)
    cliphist     # Clipboard history manager

    # Niri/Wayland utilities
    swaylock-effects  # Lock screen with effects
    swayosd          # On-screen display for volume/brightness
    swww             # Wallpaper daemon
    mako             # Notification daemon
    playerctl        # Media player control
    brightnessctl    # Brightness control

    # Database tools
    pgcli            # PostgreSQL CLI with autocomplete
    pspg             # Pager for PostgreSQL
  ];


  home.username = "dustin";
  home.homeDirectory = "/home/dustin";
  programs.git = {
    enable = true;
    userName = "Dustin";
    userEmail = "dustinromey@gmail.com";
  };
  home.stateVersion = "25.05";
  programs.bash = {
    enable = true;
    initExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
      ${builtins.readFile ../../config/bash_aliases.sh}
      ${builtins.readFile ../../config/bash_functions.sh}
    '';
  };

  # Cursor Setup
  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true; # Optional, depending on your setup
    package = pkgs.bibata-cursors; # or pkgs.vanilla-dmz, etc.
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Add gnome-keyring for Zed
  services.gnome-keyring.enable = true;

  # Syncthing - continuous file synchronization
  services.syncthing = {
    enable = true;
  };

# Load config files for list from top of file
  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    configs;

  # Symlink ~/.local/bin for custom scripts
  home.file.".local/bin" = {
    source = create_symlink bindir;
    recursive = true;
  };
}
