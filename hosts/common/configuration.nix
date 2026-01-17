{ config, lib, pkgs, inputs, ... }:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Using iwd for WiFi (required for impala TUI)
  networking.wireless.iwd.enable = lib.mkDefault true;

  # Set your time zone.
  time.timeZone = lib.mkDefault "America/New_York";

  # Enable the X11 windowing system.
  services.xserver = {
    enable = lib.mkDefault true;
    autoRepeatDelay = lib.mkDefault 200;
    autoRepeatInterval = lib.mkDefault 35;
    windowManager.qtile.enable = lib.mkDefault true;
  };
  services.displayManager.ly.enable = lib.mkDefault true;

  # Enable CUPS to print documents.
  services.printing.enable = lib.mkDefault true;

  # Enable sound.
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  # Enable Bluetooth
  hardware.bluetooth.enable = lib.mkDefault true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault true;

  # Enable uinput for evremap (key remapping)
  hardware.uinput.enable = lib.mkDefault true;

  # Docker
  virtualisation.docker.enable = lib.mkDefault true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.dustin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "uinput" "docker" "video" ]; # Enable 'sudo' for the user.
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox = {
    enable = true;
    preferences = {
      # Use KDE file picker via xdg-desktop-portal instead of GTK
      "widget.use-xdg-desktop-portal.file-picker" = 1;
    };
  };
  programs.niri.enable = true;

  boot.plymouth.enable = true;

  # Polkit authentication agent (for mounting drives, etc.)
  security.polkit.enable = true;
  systemd.user.services.polkit-kde-authentication-agent-1 = {
    description = "polkit-kde-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # xwayland-satellite for rootless XWayland support (needed for niri)
  systemd.user.services.xwayland-satellite = {
    description = "xwayland-satellite";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # USB/removable drive mounting (for Dolphin)
  services.udisks2.enable = true;
  services.gvfs.enable = true;  # Virtual filesystem for removable media

  # evremap package and uinput enabled in common config
  # Host-specific configs define the systemd service with appropriate config file

  # XDG Portal for file dialogs and screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gnome  # Required for screen capture on Niri
    ];
    config = {
      common.default = [ "kde" ];
      niri = {
        default = [ "gnome" "kde" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
      };
    };
  };

  # Disable KWallet (we don't use full Plasma, so wallet prompts are annoying)
  environment.sessionVariables.KWALLET_DISABLED = "1";

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    niri
    inputs.ghostty.packages.x86_64-linux.default  # Use flake for latest version
    brave
    kdePackages.dolphin      # File manager
    kdePackages.qtwayland    # Qt Wayland support
    kdePackages.kio-extras   # Extra protocols for Dolphin (trash, sftp, etc.)
    kdePackages.ffmpegthumbs # Video thumbnails in Dolphin/KDE file picker
    kdePackages.systemsettings # KDE settings (theming, icons, fonts)
    kdePackages.breeze       # KDE Breeze theme
    kdePackages.breeze-icons # Breeze icon theme
    kdePackages.kded         # KDE daemon for default applications
    kdePackages.kde-gtk-config # Sync KDE settings to GTK apps
    kdePackages.breeze-gtk   # GTK Breeze theme for consistency
    kdePackages.plasma-integration # Qt/KDE theming integration (lighter than plasma-workspace)
    glib                     # Contains gsettings
    dconf                    # Backend for gsettings
    nwg-look                 # GTK theming GUI
    evremap                  # evdev-based key remapper (works with X11 and Wayland)
    xwayland                 # X11 compatibility layer for Wayland
    xwayland-satellite       # Rootless XWayland for compositors without built-in support
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    hack-font
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Create /bin/bash symlink for scripts with #!/bin/bash shebang
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  system.stateVersion = "25.05";
}
