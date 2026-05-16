{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
    ./secrets.nix
  ];

  networking.hostName = "intrepid";

  # Workaround for WD_BLACK SN770 NVMe kernel oops during I/O (APST power-state bug).
  # On 2026-04-08 the machine hard-froze mid-meeting with a NULL-ptr deref in
  # nvme_irq -> nvme_poll_cq -> __blk_mq_free_request (journalctl -b -2).
  # Drive SMART is clean (0 media errors, 0% wear) but unsafe_shutdowns = 54/186
  # power cycles, consistent with repeated hangs. Disabling deep NVMe power states
  # is the standard workaround until WD firmware (currently 731100WD) is updated.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # AMD GPU support with Vulkan (for whisper.cpp acceleration)
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    amdvlk
    vulkan-loader
  ];

  # Vulkan debugging tools
  environment.systemPackages = with pkgs; [
    vulkan-tools
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
