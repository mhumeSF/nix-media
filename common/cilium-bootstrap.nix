{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ kubernetes-helm ];

  # Bootstrap Cilium CNI after k3s starts (solves chicken-and-egg problem)
  systemd.services.cilium-bootstrap = {
    description = "Bootstrap Cilium CNI for k3s";
    wantedBy = [ "multi-user.target" ];
    wants = [ "k3s.service" ];
    after = [ "k3s.service" ];
    path = with pkgs; [ kubernetes-helm kubectl jq coreutils ];
    environment = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      # Wait for k3s API to be ready
      echo "Waiting for k3s API server..."
      until kubectl get nodes &>/dev/null; do
        sleep 5
      done

      # Check if Cilium is already installed
      if helm status cilium -n kube-system &>/dev/null; then
        echo "Cilium already installed, skipping bootstrap"
        exit 0
      fi

      echo "Installing Cilium CNI..."
      helm repo add cilium https://helm.cilium.io/
      helm repo update cilium

      helm upgrade --install cilium cilium/cilium \
        --version 1.16.6 \
        --namespace kube-system \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=localhost \
        --set k8sServicePort=6443 \
        --set ipam.mode=kubernetes \
        --set l2announcements.enabled=true \
        --set externalIPs.enabled=true \
        --set ingressController.enabled=true \
        --set ingressController.default=true \
        --set ingressController.loadbalancerMode=shared \
        --set ingressController.enforceHttps=true \
        --set hubble.enabled=true \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set operator.replicas=1 \
        --set prometheus.enabled=false

      echo "Cilium bootstrap complete"
    '';
  };
}
