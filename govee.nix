{ pkgs, ... }: let
  python = pkgs.python3.withPackages (ps: [ ps.bleak ps.govee-ble ps.prometheus-client ]);
in {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  users.groups.govee-exporter = {};
  users.users.govee-exporter = {
    isSystemUser = true;
    group = "govee-exporter";
  };
  system.activationScripts.govee-metrics = {
    deps = [ "users" ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0755 -o govee-exporter -g govee-exporter \
        /var/lib/microvms/k3s/persist/govee-metrics
    '';
  };
  # The radio is on the physical host, outside the k3s microVM.
  systemd.services.govee-exporter = {
    description = "Govee H5075 Bluetooth Prometheus exporter";
    wantedBy = [ "multi-user.target" ];
    wants = [ "bluetooth.service" ];
    after = [ "bluetooth.service" ];
    serviceConfig = {
      ExecStart = "${python}/bin/python ${./services/govee-exporter.py}";
      User = "govee-exporter";
      Group = "govee-exporter";
      ReadWritePaths = [ "/var/lib/microvms/k3s/persist/govee-metrics" ];
      Restart = "always";
      RestartSec = 10;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    };
  };

}
