{
  self,
  pkgs,
  unstable,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./common/nixie.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "nixie" "root" ];
  # Precarious compatibility pin: the host currently needs OpenZFS 2.4.x from
  # unstable plus a 6.19 kernel so the microvm/virtiofs overlayfs workflow keeps
  # working. nixpkgs marks this ZFS package broken, so evaluation must allow it.
  nixpkgs.config.allowBroken = true;

  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_6_19;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.package = unstable.zfs;
  boot.zfs.forceImportRoot = false;
  environment.systemPackages = [ unstable.zfs ];
  networking.hostId = "2518ac65";

  networking = {
    useDHCP     = false;
    useNetworkd = true;
    hostName    = "media";
    enableIPv6  = false;
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    nat = {
      enable            = true;
      externalInterface = "lan";
    };
    bridges.bridge.interfaces = [ "lan" ];

    nftables.enable = true;
    firewall = {
      enable = true;
      allowedUDPPorts = [ 5353 ];
    };
  };

  # Disable br_netfilter for bridged VM traffic
  # This prevents k8s/docker iptables rules from affecting VM network traffic
  boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" = 0;
  boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" = 0;

  systemd.network = {
    enable = true;

    links = {
      "10-lan" = {
        matchConfig.Path = "pci-0000:04:00.0";
        linkConfig.Name  = "lan";
      };
      "10-wifi" = {
        matchConfig.Path = "pci-0000:05:00.0";
        linkConfig.Name  = "wifi";
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
          IPv4Forwarding = true;
          MulticastDNS = true;
        };
      };
    };

    wait-online.ignoredInterfaces = [ "wifi" "vm-internal" "vm-sandbox" "virbr-internal" ];

    # Bridge for internal VM network (vmrouter <-> sandbox)
    netdevs."10-virbr-internal" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "virbr-internal";
      };
    };

    networks."10-virbr-internal" = {
      matchConfig.Name = "virbr-internal";
      address = [ "10.0.100.254/24" ];
      networkConfig.ConfigureWithoutCarrier = true;
    };

    # Attach VM tap interfaces to internal bridge
    networks."15-vm-internal" = {
      matchConfig.Name = "vm-internal";
      networkConfig.Bridge = "virbr-internal";
    };

    networks."15-vm-sandbox" = {
      matchConfig.Name = "vm-sandbox";
      networkConfig.Bridge = "virbr-internal";
    };
  };

  # Microvm directories (must exist before virtiofsd starts)
  systemd.tmpfiles.rules = [
    "d /var/lib/microvms/k3s 0755 microvm kvm -"
    "d /var/lib/microvms/k3s/volumes 0755 microvm kvm -"
    "d /var/lib/microvms/k3s/persist 0755 root root -"
    "d /var/lib/microvms/k3s/persist/ssh 0755 root root -"
    "d /var/lib/microvms/vmrouter/persist 0755 root root -"
    "d /var/lib/microvms/vmrouter/persist/ssh 0755 root root -"
    "d /var/lib/microvms/sandbox/persist 0755 root root -"
    "d /var/lib/microvms/sandbox/persist/ssh 0755 root root -"
  ];

}
