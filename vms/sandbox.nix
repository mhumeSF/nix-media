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

    vsock.cid = 101;

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

    interfaces = [{
      type = "tap";
      id   = "vm-sandbox";
      mac  = "02:00:00:00:00:03";
    }];

  };

  fileSystems = {
    "/persist".neededForBoot = true;
  };

  services.openssh.hostKeys = [
    { path = "/persist/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
    { path = "/persist/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
  ];

  networking = {
    hostName    = "sandbox";
    enableIPv6  = false;
  };

  systemd.network = {
    enable = true;

    # Match interface by MAC directly (cloud-hypervisor creates enp0sX names)
    networks."20-lan" = {
      matchConfig.MACAddress = "02:00:00:00:00:03";
      networkConfig = {
        DHCP = "yes";
      };
    };
  };

}
