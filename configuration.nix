{
  self,
  pkgs,
  ...
}: let

  gotk-components = pkgs.writeTextFile {
    name = "gotk-components";
    text = builtins.readFile ./cluster/bootstrap/gotk-components.yaml;
  };

  gotk-sync = pkgs.writeTextFile {
    name = "gotk-sync";
    text = builtins.readFile ./cluster/bootstrap/gotk-sync.yaml;
  };

  unstable = import <nixpkgs-unstable> {};
in {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./common/nixie.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "nixie" "root" ];

  boot.loader.systemd-boot.enable = true;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
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
      allowedTCPPorts = [
        6443  # kube-apiserver
        7472  # metal-lb
        7473  # metal-lb
        9100  # node-exporter
        10250 # kubelet
      ];
    };
  };

  systemd.network = {
    enable = true;

    links = {
      "10-lan" = {
        matchConfig.Path = "pci-0000:05:00.0";
        linkConfig.Name  = "lan";
      };
      "10-wifi" = {
        matchConfig.Path = "pci-0000:06:00.0";
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
          IPForward = "yes";
          MulticastDNS = true; # Using systemd for mDNS instead of avahi
        };
      };
    };

    wait-online.ignoredInterfaces = [ "wifi"];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;
  users.users.nixie.extraGroups = ["docker"];

  # ------------------------------------------------------------------/

  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.extraFlags = toString [
    "--write-kubeconfig-mode=0640"
    "--disable servicelb"
    "--disable traefik"
    "--disable local-storage"
    "--disable metrics-server"
    "--disable-cloud-controller"
    "--disable-network-policy"
    "--kube-apiserver-arg=\"token-auth-file=/etc/rancher/k3s/token-auth-file.csv\""
  ];

  age.secrets."tokenFile" = {
    file = secrets/tokenFile.age;
    path = "/etc/rancher/k3s/token-auth-file.csv";
  };

  age.secrets."k8s-sops-key" = {
    file = secrets/k8s-sops-key.age;
    path = "/var/lib/rancher/k3s/server/manifests/k8s-sops-key.yaml";
  };

  systemd.tmpfiles.rules = [
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-components.yaml - - - - ${gotk-components}"
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-sync.yaml - - - - ${gotk-sync}"
  ];

  # systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
}
