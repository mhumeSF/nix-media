{
  self,
  pkgs,
  ...
}:

let
  unstable = import <nixpkgs-unstable> {};
in {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./common/avahi.nix
    ./common/nixie.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "nixie" "root" ];

  boot.loader.systemd-boot.enable = true;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

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
        };
      };
    };

    wait-online.ignoredInterfaces = [ "wifi"];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;
  users.users.nixie.extraGroups = ["docker"];

  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  time.timeZone = "America/New_York";

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    htop
    ripgrep
    starship
    powertop
    neovim
    git
    tree
  ];

  services.openssh.enable = true;

  system.stateVersion = "23.05";

}
