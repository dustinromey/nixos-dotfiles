{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix
  ];

  networking.hostName = "intrepid";

  # AMD GPU support
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    amdvlk
  ];

  # Optional: Force AMD Vulkan driver
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
  };

  # evremap - desktop keyboard config (RK S70)
  systemd.services.evremap = {
    description = "evdev key remapper";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.evremap}/bin/evremap remap /home/dustin/nixos-dotfiles/config/evremap/rk-s70.toml";
      Restart = "always";
      RestartSec = "1";
    };
  };
}
