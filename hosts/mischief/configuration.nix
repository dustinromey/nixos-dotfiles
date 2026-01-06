{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix
  ];

  networking.hostName = "mischief";
}
