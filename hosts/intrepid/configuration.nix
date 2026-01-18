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
}
