{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../common/home.nix
  ];

  # Use Vulkan-accelerated voxtype on AMD Surface Laptop
  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
