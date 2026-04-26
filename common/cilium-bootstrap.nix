{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ kubernetes-helm ];

  # Bootstrap Cilium CNI after boot without holding up the boot transaction.
  # A timer retries until the API is up and Cilium is installed.
  systemd.services.cilium-bootstrap = {
    description = "Bootstrap Cilium CNI for k3s";
    path = with pkgs; [ kubernetes-helm kubectl jq coreutils ];
    environment = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -euo pipefail

      # Skip this run until the API is reachable. The timer will retry.
      if ! kubectl get nodes &>/dev/null; then
        echo "k3s API not ready yet, skipping bootstrap run"
        exit 0
      fi

      # Bootstrap only until Flux takes over the Helm release.
      if helm status cilium -n kube-system &>/dev/null; then
        echo "Cilium already installed, leaving upgrades to Flux"
        exit 0
      fi

      echo "Installing Cilium CNI for initial cluster access..."
      helm repo add cilium https://helm.cilium.io/
      helm repo update cilium

      helm upgrade --install cilium cilium/cilium \
        --version 1.19.2 \
        --namespace kube-system \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=localhost \
        --set k8sServicePort=6443 \
        --set ipam.mode=kubernetes \
        --set ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" \
        --set externalIPs.enabled=true \
        --set bgpControlPlane.enabled=true \
        --set gatewayAPI.enabled=false \
        --set hubble.enabled=true \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set operator.replicas=1 \
        --set prometheus.enabled=false

      echo "Cilium bootstrap complete"
    '';
  };

  systemd.timers.cilium-bootstrap = {
    description = "Retry Cilium bootstrap for k3s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "2m";
      Unit = "cilium-bootstrap.service";
    };
  };
}
