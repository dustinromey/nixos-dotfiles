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

  # Use Vulkan-accelerated voxtype on AMD desktop
  programs.voxtype.package = inputs.voxtype.packages.${pkgs.system}.vulkan;
}
