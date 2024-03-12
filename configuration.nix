{
  self,
  pkgs,
  microvm,
  ...
}:

let
  unstable = import <nixpkgs-unstable> {};
in {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  microvm.vms = {
    my-microvm = {
      # The package set to use for the microvm. This also determines the microvm's architecture.
      # Defaults to the host system's package set if not given.
      pkgs = import pkgs { system = "x86_64-linux"; };

      # The configuration for the MicroVM.
      # Multiple definitions will be merged as expected.
      config = {
        # It is highly recommended to share the host's nix-store
        # with the VMs to prevent building huge images.
        microvm.shares = [{
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          tag = "ro-store";
          proto = "virtiofs";
        }];
      };

    };
  };

  # microvm.vms.my-microvm = { flake = self; };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "nixie" "root" ];

  boot.loader.systemd-boot.enable = true;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

  networking = {
    useDHCP = false;
    useNetworkd = true;
    hostName = "media";
    enableIPv6 = false;
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    nat = {
      enable = true;
      externalInterface = "lan";
    };
    bridges.bridge.interfaces = [ "lan" ];
  };

  systemd.network = {
    enable = true;

    links = {
      "10-lan" = {
        matchConfig.Path = "pci-0000:05:00.0";
        linkConfig.Name = "lan";
      };
      "10-wifi" = {
        matchConfig.Path = "pci-0000:06:00.0";
        linkConfig.Name = "wifi";
      };
    };

    networks = {
      "10-wifi" = {
        matchConfig.Name = "wifi";
      };
      "20-bridge" = {
        matchConfig.Name = "bridge";
        networkConfig = {
          DHCP = "ipv4";
          IPForward = "yes";
        };
      };
    };

    wait-online.ignoredInterfaces = [ "wifi"];
  };


  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    htop
    ripgrep
    starship
    neovim
    git
    tree
  ];

  environment.variables.EDITOR = "nvim";

  security.sudo.wheelNeedsPassword = false;

  users.users = {
    nixie = {
      isNormalUser = true;
      home = "/home/nixie";
      description = "Nixie Admin";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLpijNKLQTJJXToZRGjRWb2f1EgPG9IzzO85mvbjbaY nixie@router" ];
    };
  };

  services = {
    openssh.enable = true;
  };

  system.stateVersion = "23.05";

}
