{ config, lib, pkgs, ... }:

{
  imports = [
    ../common.nix
  ];

  networking.hostName = "swift";
}
