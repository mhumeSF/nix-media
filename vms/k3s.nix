{
  pkgs,
  config,
  agenix,
  unstable,
  ...
}: let

  gotk-components = pkgs.writeTextFile {
    name = "gotk-components";
    text = builtins.readFile ../cluster/bootstrap/gotk-components.yaml;
  };

  gotk-sync = pkgs.writeTextFile {
    name = "gotk-sync";
    text = builtins.readFile ../cluster/bootstrap/gotk-sync.yaml;
  };

in {
  imports = [
    ../common/avahi.nix
    ../common/nixie.nix
    ../common/cilium-bootstrap.nix
    agenix.nixosModules.default
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  microvm = {

    # CLOUD-HYPERVISOR

    hypervisor = "cloud-hypervisor";

    kernelParams = [
      "pcie_acs_override=downstream,multifunction"
    ];

    devices = [
      {
        bus = "pci";
        path = "0000:06:00.0";
      }
      {
        bus = "pci";
        path = "0000:06:00.1";
      }
      {
        bus = "pci";
        path = "0000:06:00.2";
      }
      {
        bus = "pci";
        path = "0000:06:00.3";
      }
      {
        bus = "pci";
        path = "0000:06:00.4";
      }
    ];

    vcpu = 8;
    mem = 16000;

    shares = [
      {
        source     = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag        = "ro-store";
        proto      = "virtiofs";
      }
      {
        source     = "/var/lib/microvms/${config.networking.hostName}/persist";
        mountPoint = "/persist";
        tag        = "persist";
        proto      = "virtiofs";
      }
      {
        source     = "/movies";
        mountPoint = "/movies";
        tag        = "movies";
        proto      = "virtiofs";
      }
    ];

    interfaces = [{
      type         = "macvtap";
      id           = "vm-k3s";
      mac          = "02:00:00:00:01:01";
      macvtap.link = "bridge";
      macvtap.mode = "bridge";
    }];

  };

  fileSystems = {
    "/persist".neededForBoot = true;
    "/movies".neededForBoot = true;
  };

  services.openssh.hostKeys = [
    { path = "/persist/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
    { path = "/persist/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
  ];

  networking = {
    hostName         = "k3s";
    enableIPv6       = false;
    nameservers      = [ "1.1.1.1" "1.0.0.1" ];

    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80    # ingress http
        443   # ingress https
        4240  # cilium-health
        4244  # hubble-server
        4245  # hubble-relay
        6443  # kube-apiserver
        9100  # node-exporter
        10250 # kubelet
      ];
      allowedUDPPorts = [
        8472  # cilium vxlan
      ];
      trustedInterfaces = [ "cilium_+" "lxc+" ];
    };
  };

  systemd.network = {
    enable = true;

    networks."20-lan" = {
      matchConfig.name = "bridge";
      networkConfig = {
        DHCP = "yes";
      };
    };
  };

  environment.systemPackages = with pkgs; [ k3s ];

  # etcd for k3s datastore
  services.etcd = {
    enable = true;
    package = unstable.etcd;
    dataDir = "/persist/etcd";
  };

  systemd.services.etcd = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  systemd.services.k3s = {
    wants = [ "etcd.service" ];
    after = [ "etcd.service" ];
  };

  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.extraFlags = toString [
    "--tls-san k3s.local"
    "--write-kubeconfig-mode=0640"
    "--disable-network-policy"
    "--disable servicelb"
    "--disable traefik"
    "--disable local-storage"
    "--disable metrics-server"
    "--disable-cloud-controller"
    "--flannel-backend=none"
    "--disable-kube-proxy"
    "--kube-apiserver-arg=\"token-auth-file=/etc/rancher/k3s/token-auth-file.csv\""
    "--datastore-endpoint=http://localhost:2379"
  ];

  age.secrets."tokenFile" = {
    file = ../secrets/tokenFile.age;
    path = "/etc/rancher/k3s/token-auth-file.csv";
  };

  age.secrets."k8s-sops-key" = {
    file = ../secrets/k8s-sops-key.age;
    path = "/var/lib/rancher/k3s/server/manifests/k8s-sops-key.yaml";
  };

  systemd.tmpfiles.rules = [
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-components.yaml - - - - ${gotk-components}"
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-sync.yaml - - - - ${gotk-sync}"
  ];
}
