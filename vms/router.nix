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

    hypervisor = "cloud-hypervisor";

    vsock.cid = 100;

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
        source     = "/var/lib/microvms/${config.networking.hostName}/persist";
        mountPoint = "/persist";
        tag        = "persist";
        proto      = "virtiofs";
      }
    ];

    interfaces = [
      {
        type         = "macvtap";
        id           = "vm-router";
        mac          = "02:00:00:00:00:01";
        macvtap.link = "bridge";
        macvtap.mode = "bridge";
      }
      {
        type = "tap";
        id   = "vm-internal";
        mac  = "02:00:00:00:00:02";
      }
    ];

  };

  fileSystems = {
    "/persist".neededForBoot = true;
  };

  services.openssh.hostKeys = [
    { path = "/persist/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
    { path = "/persist/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
  ];

  networking = {
    hostName         = "router";
    enableIPv6       = false;
    nameservers      = [ "1.1.1.1" "1.0.0.1" ];

    nftables.enable = true;
    nat = {
      enable             = true;
      internalInterfaces = [ "internal" ];
      externalInterface  = "external";
    };
    firewall = {
      enable = true;
      trustedInterfaces = [ "internal" ];
    };
  };

  systemd.network = {
    enable = true;

    # Rename interfaces by MAC address (cloud-hypervisor creates enp0sX names)
    links."10-external" = {
      matchConfig.MACAddress = "02:00:00:00:00:01";
      linkConfig.Name = "external";
    };

    links."10-internal" = {
      matchConfig.MACAddress = "02:00:00:00:00:02";
      linkConfig.Name = "internal";
    };

    # Match renamed interfaces by name
    networks."10-external" = {
      matchConfig.Name = "external";
      networkConfig = {
        DHCP = "yes";
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    networks."20-internal" = {
      matchConfig.Name = "internal";
      address = [ "10.99.0.1/24" ];
      networkConfig = {
        IPv4Forwarding = true;
      };
    };
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "internal";
      bind-interfaces = true;
      dhcp-range = "10.99.0.100,10.99.0.200,24h";
      dhcp-option = [
        "option:router,10.99.0.1"
        "option:dns-server,1.1.1.1,1.0.0.1"
      ];
    };
  };

}
