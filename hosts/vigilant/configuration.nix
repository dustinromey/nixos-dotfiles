{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix
    inputs.nixos-hardware.nixosModules.microsoft-surface-laptop-amd
  ];

  # Enable Surface-patched kernel for better hardware support (camera, etc.)
  hardware.microsoft-surface.kernelVersion = "longterm";

  networking.hostName = "vigilant";

  # AMD GPU support
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    amdvlk
  ];

  # Optional: Force AMD Vulkan driver
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
  };

  # Surface-specific tweaks
  # Enable touchpad support
  services.libinput.enable = true;
  services.libinput.touchpad = {
    tapping = true;
    naturalScrolling = true;
    disableWhileTyping = true;
  };

  # Udev rule to create symlink for RGB webcam (Surface C, not IR)
  services.udev.extraRules = ''
    SUBSYSTEM=="video4linux", ATTR{name}=="Surface Camera Front: Surface C", SYMLINK+="webcam", TAG+="uaccess"
  '';

  # evremap - laptop config (Caps Lock -> Ctrl/Escape)
  systemd.services.evremap = {
    description = "evdev key remapper";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.evremap}/bin/evremap remap /home/dustin/nixos-dotfiles/config/evremap/surface.toml";
      Restart = "always";
      RestartSec = "1";
    };
  };
}
