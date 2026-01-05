{ config, lib, pkgs, ... }:

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

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.dustin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;
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

  # USB/removable drive mounting (for Dolphin)
  services.udisks2.enable = true;
  services.gvfs.enable = true;  # Virtual filesystem for removable media

  # XDG Portal for file dialogs (uses KDE/Dolphin)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config = {
      common.default = [ "kde" ];
      niri.default = [ "kde" ];  # Override niri's default gnome/gtk portal
    };
  };

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    niri
    ghostty
    brave
    kdePackages.dolphin      # File manager
    kdePackages.qtwayland    # Qt Wayland support
    kdePackages.kio-extras   # Extra protocols for Dolphin (trash, sftp, etc.)
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    hack-font
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";
}
