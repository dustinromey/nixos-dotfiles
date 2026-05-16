{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home/shared.nix
    ../../modules/home/darwin.nix
  ];
}
