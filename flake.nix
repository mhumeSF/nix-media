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
      ];
    };

    # nixosConfigurations.my-microvm = nixpkgs.lib.nixosSystem {
    #   system = "x86_64-linux";
    #   modules = [
    #     microvm.nixosModules.microvm
    #     {
    #       networking.hostName = "my-microvm";
    #       users.users.root.password = "";
    #       microvm = {
    #         volumes = [ {
    #           mountPoint = "/var";
    #           image = "var.img";
    #           size = 256;
    #         } ];
    #         shares = [ {
    #           # use "virtiofs" for MicroVMs that are started by systemd
    #           proto = "9p";
    #           tag = "ro-store";
    #           # a host's /nix/store will be picked up so that no
    #           # squashfs/erofs will be built for it.
    #           source = "/nix/store";
    #           mountPoint = "/nix/.ro-store";
    #         } ];

    #         hypervisor = "qemu";
    #         socket = "control.socket";
    #       };
    #     }
    #   ];
    # };

  }; # outputs

}
