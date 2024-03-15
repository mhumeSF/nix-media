{
  config,
  lib,
  pkgs,
  ...
}: {
  microvm = {
    shares = [{
      source     = "/nix/store";
      mountPoint = "/nix/.ro-store";
      tag        = "ro-store";
      proto      = "virtiofs";
    }];
  };

  systemd.network.enable = true;

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };

  networking = {
    hostName = "router";
    firewall.package = pkgs.nftables;
    nftables.enable = true;
  };

  services.prometheus = {
    enable = true;
  };

  system.stateVersion = "23.11";
}
