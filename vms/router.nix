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

    vcpu = 2;
    mem = 2000;

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
      id           = "vm-router";
      mac          = "02:00:00:00:00:01";
      macvtap.link = "bridge";
      macvtap.mode = "bridge";
    }];
  };

  fileSystems = {
    "/etc/ssh".neededForBoot = true;
  };

  time.timeZone = "America/New_York";

  networking = {
    hostName         = "router";
    firewall.package = pkgs.nftables;
    enableIPv6       = false;
    nameservers      = [ "1.1.1.1" "1.0.0.1" ];
    nftables.enable  = true;
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

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    htop
    neovim
    tree
    avahi
  ];

  services.openssh.enable = true;

  system.stateVersion = "23.11";
}
