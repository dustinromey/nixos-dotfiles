{
  description = "Romey NixOS - Multi-host configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix-darwin for macOS hosts (resolute, swift)
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative Homebrew bootstrap (used by darwin hosts).
    # Pinned to last commit before the ruby_4_0 bump — nixpkgs-25.05 only ships
    # up to ruby_3_4. Unpin once we move to nixpkgs-25.11+.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew/0406ffd7d3a4e285b618a226a837f4fe9b1a36b7";

    # Claude
    claude-code.url = "github:ryoppippi/claude-code-overlay";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Fresh text editor (Linux-only; consumed conditionally in modules/home/shared.nix)
    fresh.url = "github:sinelaw/fresh";
    fresh.inputs.nixpkgs.follows = "nixpkgs";

    # Ghostty terminal (NixOS only; macOS uses the Homebrew cask)
    ghostty.url = "github:ghostty-org/ghostty";

    # Hardware-specific configurations (includes Surface support)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Linux-only overlay (waystt is a Wayland speech-to-text package)
      linuxOverlay = final: prev: {
        waystt = final.callPackage ./packages/waystt { };
      };

      mkHost = hostname: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ linuxOverlay ];

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

      mkDarwinHost = hostname: system: inputs.nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./darwin/${hostname}/configuration.nix
          inputs.nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.dustin = import ./darwin/${hostname}/home.nix;
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

      darwinConfigurations = {
        # Mac desktop (assumed Apple Silicon — change system to x86_64-darwin for Intel)
        resolute = mkDarwinHost "resolute" "aarch64-darwin";

        # Mac laptop
        swift = mkDarwinHost "swift" "aarch64-darwin";
      };
    };
}
