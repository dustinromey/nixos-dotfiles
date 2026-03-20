{
  config,
  pkgs,
  inputs,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  bindir = "${config.home.homeDirectory}/nixos-dotfiles/bin";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Android SDK for React Native / Expo development
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      platformVersions = [
        "34"
        "35"
      ];
      buildToolsVersions = [
        "34.0.0"
        "35.0.0"
      ];
      includeEmulator = true;
      includeSystemImages = true;
      systemImageTypes = [ "google_apis_playstore" ];
      abiVersions = [ "x86_64" ];
    }).androidsdk;

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
    obs-studio = "obs-studio";
  };
in

{
  imports = [
    inputs.voxtype.homeManagerModules.default
  ];

  # 1. Install Zed and the required Language Servers
  home.packages = with pkgs; [
    # --- Language Servers (LSPs) & Formatters ---
    nixd
    nixfmt-rfc-style
    rust-analyzer
    rustfmt
    pyright # Type checker / LSP
    black # Formatter
    lua-language-server
    stylua
    gopls
    gotools # contains goimports, etc.
    nodePackages.typescript-language-server
    nodePackages.prettier # Common formatter
    nodePackages.bash-language-server
    shfmt
    nodePackages.vscode-langservers-extracted # Contains JSON LS
    sqls # SQL Language Server
    fish-lsp

    # Fonts (Required for your 'Hack' terminal setting)
    hack-font

    # command-line programs
    neovim
    bat # cat replacement with syntax highlighting
    ripgrep
    jq # JSON processor
    curl # HTTP client
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
    python3
    gcc
    rofi-wayland # Works on both X11 (Qtile) and Wayland (Niri)
    zed-editor
    fastfetch
    btop
    claude-code
    inputs.fresh.packages.${pkgs.system}.default # Fresh text editor
    waybar
    impala # WiFi TUI
    bluetui # Bluetooth TUI
    obsidian # Markdown notes app
    wl-clipboard # Wayland clipboard (wl-copy, wl-paste)
    xclip # X11 clipboard
    cliphist # Clipboard history manager
    xorg.xhost # X11 access control (for Docker GUI apps)
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-pipewire-audio-capture
      ];
    }) # OBS with plugins
    v4l-utils # Webcam configuration tools
    mpv # Video player
    filezilla # FTP/SFTP client
    nmap # Network scanner

    # Niri/Wayland utilities
    swaylock-effects # Lock screen with effects
    swayosd # On-screen display for volume/brightness
    swww # Wallpaper daemon
    mako # Notification daemon
    libnotify # notify-send command (for STT notifications)
    playerctl # Media player control
    brightnessctl # Brightness control

    # Database tools
    pgcli # PostgreSQL CLI with autocomplete
    pspg # Pager for PostgreSQL

    # Android / React Native development
    androidSdk
    jdk17
    eas-cli
    watchman
  ];

  home.username = "dustin";
  home.homeDirectory = "/home/dustin";

  # Environment variables
  home.sessionVariables = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    TERMINAL = "ghostty";
  };
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

  # GTK Theming (Tokyo Night for Thunar and other GTK apps)
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Enable dconf (required for GTK theme settings to persist)
  dconf.enable = true;

  # Add gnome-keyring for Zed
  services.gnome-keyring.enable = true;

  # Syncthing - continuous file synchronization
  services.syncthing = {
    enable = true;
  };

  # Custom desktop entries
  xdg.desktopEntries.files = {
    name = "Files";
    genericName = "File Manager";
    exec = "thunar %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [
      "Utility"
      "Core"
      "FileManager"
    ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries.brave-browser = {
    name = "Brave";
    genericName = "Web Browser";
    exec = "brave --password-store=basic %U";
    icon = "brave-browser";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  xdg.desktopEntries.ghostty = {
    name = "Ghostty";
    genericName = "Terminal Emulator";
    exec = "ghostty";
    icon = "ghostty";
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
  };

  xdg.desktopEntries.xtuple = {
    name = "xTuple ERP";
    genericName = "ERP Client";
    exec = "${config.home.homeDirectory}/.local/bin/xtuple";
    icon = "applications-office";
    terminal = false;
    categories = [
      "Office"
      "Finance"
    ];
    comment = "xTuple ERP Desktop Client";
  };

  # Set default applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/terminal" = [ "ghostty.desktop" ];
    };
  };

  # Load config files for list from top of file
  xdg.configFile = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) configs;

  # Symlink ~/.local/bin for custom scripts
  home.file.".local/bin" = {
    source = create_symlink bindir;
    recursive = true;
  };
}
