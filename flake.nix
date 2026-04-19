{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    nixpkgs-unstable,
    agenix,
    disko,
    microvm,
    ...
  }@inputs:

  {
    nixosConfigurations.media = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
      };
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        agenix.nixosModules.default

        microvm.nixosModules.host
        {
          microvm.autostart = [
            "vmrouter"
            "k3s"
            "sandbox"
          ];
        }

        {
          microvm.vms = {
            vmrouter = {
              pkgs = import nixpkgs { system = "x86_64-linux"; };
              specialArgs = { inherit agenix; };
              config = import ./vms/vmrouter.nix;
            };
            k3s = {
              pkgs = import nixpkgs { system = "x86_64-linux"; };
              specialArgs = {
                inherit agenix;
                unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
              };
              config = import ./vms/k3s.nix;
            };
            sandbox = {
              pkgs = import nixpkgs { system = "x86_64-linux"; };
              specialArgs = {
                inherit agenix;
                unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
              };
              config = import ./vms/sandbox.nix;
            };
          };
        }
      ];
    };

  }; # outputs

}
