{
  pkgs,
  config,
  agenix,
  ...
}: {
  imports = [
    ../common/avahi.nix
    ../common/nixie.nix
    agenix.nixosModules.default
  ];


  microvm = {

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
        source     = "/var/lib/microvms/${config.networking.hostName}/storage/etc/ssh";
        mountPoint = "/etc/ssh";
        tag        = "ssh";
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
    "/etc/ssh".neededForBoot = true;
  };

  time.timeZone = "America/New_York";

  networking = {
    hostName         = "k3s";
    firewall.package = pkgs.nftables;
    enableIPv6       = false;
    nameservers      = [ "1.1.1.1" "1.0.0.1" ];
    firewall.allowedTCPPorts = [ 6443 ];
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
    file = ../secrets/tokenFile.age;
    path = "/etc/rancher/k3s/token-auth-file.csv";
  };

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    htop
    neovim
    tree
    k3s
  ];

  services.openssh.enable = true;

  system.stateVersion = "23.11";
}
