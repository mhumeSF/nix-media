{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    microvm,
    disko,
    ...
  }@inputs:

  {
    nixosConfigurations.media = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix

        microvm.nixosModules.host
        {
          microvm.autostart = [
            "router"
          ];
        }

        {
          microvm.vms = {
            router = {
              # The package set to use for the microvm. This also determines the microvm's architecture.
              # Defaults to the host system's package set if not given.
              pkgs = import nixpkgs {system = "x86_64-linux";};

              # (Optional) A set of special arguments to be passed to the MicroVM's NixOS modules.
              #specialArgs = {};

              # The configuration for the MicroVM.
              # Multiple definitions will be merged as expected.
              config = import ./vms/router.nix;
            };
          };
        }
      ];
    };

  }; # outputs

}
