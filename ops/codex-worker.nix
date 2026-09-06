# Host maintenance worker; publish one task for review every six hours.
{ pkgs, unstable, ... }:
let
  runner = pkgs.writeShellApplication {
    name = "codex-one-task";
    runtimeInputs = with pkgs; [
      bash coreutils util-linux git gh gitleaks gawk nix kustomize kubectl
      kubernetes-helm python3 ripgrep openssh cacert unstable.codex
    ];
    text = builtins.readFile ./codex-one-task.sh;
  };
in {
  environment.systemPackages = [ pkgs.gh ];
  users.groups.codex-worker = {};
  users.users.codex-worker = {
    isSystemUser = true;
    group = "codex-worker";
    home = "/var/lib/codex-worker";
    createHome = true;
    homeMode = "0700";
    shell = pkgs.bashInteractive;
  };
  systemd.services.codex-maintenance = {
    description = "Prepare one nix-media maintenance task for review";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      HOME = "/var/lib/codex-worker";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_CONFIG = "max-jobs = 1\ncores = 2";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "codex-worker";
      Group = "codex-worker";
      ExecStart = "${runner}/bin/codex-one-task";
      TimeoutStartSec = "50min";
      KillMode = "control-group";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/var/lib/codex-worker" ];
      InaccessiblePaths = [ "/tank0" "/var/lib/microvms" "-/movies" "-/run/agenix" ];
      Nice = 10;
      CPUQuota = "200%";
      MemoryMax = "4G";
    };
  };
  systemd.timers.codex-maintenance = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,06,12,18:00:00";
      RandomizedDelaySec = "10min";
      Persistent = false;
      Unit = "codex-maintenance.service";
    };
  };
}
