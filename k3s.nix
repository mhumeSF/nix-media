{
  pkgs,
  config,
  agenix,
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
  imports = [ agenix.nixosModules.default ];

  environment.systemPackages = with pkgs; [ k3s ];

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

  age.secrets."k8s-sops-key" = {
    file = ../secrets/k8s-sops-key.age;
    path = "/var/lib/rancher/k3s/server/manifests/k8s-sops-key.yaml";
  };

  systemd.tmpfiles.rules = [
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-components.yaml - - - - ${gotk-components}"
    "L+ /var/lib/rancher/k3s/server/manifests/gotk-sync.yaml - - - - ${gotk-sync}"
  ];
}
