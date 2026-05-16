{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Android SDK for React Native / Expo development
  androidSdk = (pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "34" "35" ];
    buildToolsVersions = [ "34.0.0" "35.0.0" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "x86_64" ];
  }).androidsdk;

  # Linux-only config dirs (window managers, status bars, notification daemons)
  linuxConfigs = {
    qtile = "qtile";
    rofi = "rofi";
    niri = "niri";
    waybar = "waybar";
    mako = "mako";
    obs-studio = "obs-studio";
  };
in
{
  home.packages = with pkgs; [
    # Native toolchain
    gcc

    # Fonts
    hack-font

    # GUI apps (cask-on-macOS counterparts)
    zed-editor
    obsidian
    mpv
    filezilla

    # Wayland / X11 desktop utilities
    rofi-wayland
    waybar
    wl-clipboard
    xclip
    cliphist
    xorg.xhost
    swaylock-effects
    swayosd
    swww
    mako
    libnotify
    playerctl
    brightnessctl

    # Hardware / OS TUIs
    impala
    bluetui
    v4l-utils

    # OBS with Linux-only PipeWire audio plugin
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-pipewire-audio-capture
      ];
    })

    # Android / React Native
    androidSdk
    jdk17
    eas-cli
    watchman
  ];

  home.sessionVariables = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  };

  # GTK theming (Tokyo Night for Thunar and other GTK apps)
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

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  dconf.enable = true;

  services.gnome-keyring.enable = true;

  services.syncthing = {
    enable = true;
  };

  xdg.desktopEntries.files = {
    name = "Files";
    genericName = "File Manager";
    exec = "thunar %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "Utility" "Core" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries.brave-browser = {
    name = "Brave";
    genericName = "Web Browser";
    exec = "brave --password-store=basic %U";
    icon = "brave-browser";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };

  xdg.desktopEntries.ghostty = {
    name = "Ghostty";
    genericName = "Terminal Emulator";
    exec = "ghostty";
    icon = "ghostty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
  };

  xdg.desktopEntries.xtuple = {
    name = "xTuple ERP";
    genericName = "ERP Client";
    exec = "${config.home.homeDirectory}/.local/bin/xtuple";
    icon = "applications-office";
    terminal = false;
    categories = [ "Office" "Finance" ];
    comment = "xTuple ERP Desktop Client";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/terminal" = [ "ghostty.desktop" ];
    };
  };

  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    linuxConfigs;
}
