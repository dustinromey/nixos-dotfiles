{
  description = "Romey NixOS - Multi-host configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Claude
    claude-code.url = "github:ryoppippi/claude-code-overlay";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Fresh text editor
    fresh.url = "github:sinelaw/fresh";
    fresh.inputs.nixpkgs.follows = "nixpkgs";

    # Voxtype voice-to-text
    voxtype.url = "github:peteonrails/voxtype/v0.6.4";
    voxtype.inputs.nixpkgs.follows = "nixpkgs";

    # Ghostty terminal (for latest version)
    ghostty.url = "github:ghostty-org/ghostty";

    # Hardware-specific configurations (includes Surface support)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Helper function to create a host configuration
      mkHost =
        hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${hostname}/configuration.nix
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs; };
                users.dustin = import ./hosts/${hostname}/home.nix;
                backupFileExtension = "backup";
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # Lenovo ThinkPad X270 - Intel i5-6300U, Intel HD 520, test machine
        mischief = mkHost "mischief" "x86_64-linux";

        # Desktop - AMD CPU/GPU, 32GB RAM, daily driver
        intrepid = mkHost "intrepid" "x86_64-linux";

        # Microsoft Surface Laptop 4 - AMD CPU/GPU, 16GB RAM
        vigilant = mkHost "vigilant" "x86_64-linux";
      };
    };
}
