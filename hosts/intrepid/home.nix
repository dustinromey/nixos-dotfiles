{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home/shared.nix
    ../../modules/home/linux.nix
  ];

  # Host-specific home configuration overrides for intrepid
}
