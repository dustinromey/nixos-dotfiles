{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix
  ];

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
