{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
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
}
