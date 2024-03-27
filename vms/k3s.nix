{
  pkgs,
  agenix,
  ...
}: {
  imports = [
    ../common/avahi.nix
    ../common/nixie.nix
  ];

  age.secrets."secret1".file = ../secrets/secret1.age;

  microvm = {

    vcpu = 8;
    mem = 16000;

    shares = [{
      source     = "/nix/store";
      mountPoint = "/nix/.ro-store";
      tag        = "ro-store";
      proto      = "virtiofs";
    }];

    interfaces = [{
      type         = "macvtap";
      id           = "vm-k3s";
      mac          = "02:00:00:00:01:01";
      macvtap.link = "bridge";
      macvtap.mode = "bridge";
    }];
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

  # example for now
  environment.etc."rancher/k3s/token-auth-file.csv".text = ''
    7f255a63d2f74a529382f1533d3d6fd132,admin,1,"system:masters"
  '';

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
