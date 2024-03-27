{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = {
    self,
    nixpkgs,
    agenix,
    disko,
    microvm,
    ...
  }@inputs:

  {
    nixosConfigurations.media = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        agenix.nixosModules.default

        microvm.nixosModules.host
        {
          microvm.autostart = [
            "router"
            "k3s"
          ];
        }

        {
          microvm.vms = {
            router = {
              pkgs = import nixpkgs { system = "x86_64-linux"; };
              config = import ./vms/router.nix;
            };

            k3s = {
              pkgs = import nixpkgs { system = "x86_64-linux"; };
              config = import ./vms/k3s.nix;
            };
          };
        }
      ];
    };

  }; # outputs

}
