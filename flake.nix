{
  description = "Romey NixOS - Multi-host configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Claude
    claude-code.url = "github:ryoppippi/claude-code-overlay";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Helper function to create a host configuration
      mkHost = hostname: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = false;
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
