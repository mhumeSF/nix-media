# nix-media

NixOS flake defining a single home media server host (`media`, x86_64) and the
microVMs it runs. The `media` host runs three microVMs via
[microvm.nix](https://github.com/astro/microvm.nix) (cloud-hypervisor):

| VM         | vsock CID | Role |
|------------|-----------|------|
| `vmrouter` | 100       | Internal router for the VM network |
| `k3s`      | 3         | Single-node k3s cluster (apps live here) |
| `sandbox`  | —         | Scratch/experimentation VM |

All three are in `microvm.autostart`. VM definitions are in `vms/*.nix`; shared
NixOS modules are in `common/`.

> **Current focus:** <!-- TODO(you): what are we actively working on right now?
> e.g. "migrating Immich Postgres to CloudNativePG", "stabilizing Cilium LB VIPs".
> Keep this current so I don't have to re-derive it. -->

## Layout

- `flake.nix` — single `nixosConfigurations.media`; pins nixpkgs `26.05`, with
  `nixpkgs-unstable` available as `unstable` in `specialArgs`.
- `configuration.nix` — the `media` host (ZFS `tank0`, bridged networking, NAT,
  microvm host config, virtiofs share dirs).
- `vms/{vmrouter,k3s,sandbox}.nix` — per-VM NixOS configs.
- `common/` — modules shared across host/VMs (`nixie.nix` user, `avahi.nix`,
  `cilium-bootstrap.nix`).
- `cluster/` — **everything Flux reconciles** (see below).
- `secrets/` — agenix-encrypted host/VM secrets (`*.age`), recipients in
  `secrets.nix`.
- `disk-config.nix` / `hardware-configuration.nix` — disko + hardware.
- `plex.nix` — **Plex runs natively on the host** (not in the cluster). Config
  on `/tank0/plex`, libraries read straight off `tank0`, HW transcode via the
  Ryzen iGPU (radeonsi VAAPI). Reachable at `media.local:32400`.
- `Makefile` — deploy and Renovate entrypoints.

## Deploying the host / VMs

Builds and switches happen **remotely on the box**, not locally:

```sh
make all   # nixos-rebuild switch --flake .#media --target-host nixie@media.local --build-host nixie@media.local
```

Override `HOST_IP`, `REMOTE_USER` if needed. Don't suggest a local
`nixos-rebuild switch` — this Mac is not the target.

## The k3s cluster (Flux)

Flux watches this repo (`github.com/mhumesf/nix-media`, branch `main`) and
reconciles `./cluster`. **Deploying cluster changes = commit & push to `main`**;
Flux syncs on its own (`GitRepository` poll 10m). To force it:
`flux reconcile kustomization flux-system --with-source`.

- Flux bootstrap manifests (`cluster/bootstrap/`) are baked into the k3s VM's
  `server/manifests/` at build time via `vms/k3s.nix` — that's how Flux gets
  installed; the `GitRepository` then ignores `/cluster/bootstrap`.
- Entry Kustomization points at `./cluster`; `cluster/flux/` wires up the rest
  (`repositories/` = Helm/Git sources, `vars/` = cluster-settings + SOPS vars,
  `config/cluster.yaml` reconciles `./cluster/flux`).
- Apps live under `cluster/apps/<namespace>/<app>/`. Notable ones: `default/`
  (immich), `monitoring/` (kube-prometheus-stack, grafana, loki),
  `networking/` (cilium, metallb, envoy-gateway, blocky, k8s-gateway, omada),
  `infrastructure/cloudnative-pg`, `backup/rclone`, `cert-manager`.

### k3s specifics (`vms/k3s.nix`)

- k3s runs server-only with a lot disabled: **no** flannel, kube-proxy,
  servicelb, traefik, local-storage, metrics-server, network-policy, cloud
  controller. **Cilium** provides CNI + kube-proxy replacement; **MetalLB** does
  LB VIPs; **Envoy Gateway** is ingress.
- Datastore is **external etcd** on `localhost:2379` (not embedded).
- Most k3s state is disposable; only `containerd` and local-path `storage` live
  on block-backed ext4 volumes that persist.

## Storage model (important gotcha)

The k3s VM gets pool data from the host via **virtiofs shares** (see
`microvm.shares` in `vms/k3s.nix`): `/movies`, `/gato-bucket`
(`/tank0/gato-bucket`), `/persist`. A hostPath/PVC in the cluster only survives
if it lands **inside one of these shares** — anything outside is a throwaway
tmpfs dir inside the VM. Always anchor media/app data to a share.

## Secrets — two separate layers

1. **agenix** (`secrets/*.age`): NixOS host/VM-level secrets decrypted at
   activation using each machine's SSH host key. Used for the k3s
   `token-auth-file` and the bootstrap `k8s-sops-key`. Recipients/files declared
   in `secrets/secrets.nix`.
2. **SOPS** (`*.sops.yaml` under `cluster/`, plus `encrypted_regex` over
   `data|stringData|acme`): in-cluster secrets, decrypted **by Flux** using the
   `sops-age` secret. That secret is seeded from the agenix `k8s-sops-key.age`,
   which `vms/k3s.nix` symlinks into a bootstrap manifest. Recipient/age key
   config is in `.sops.yaml`.

So: host things → agenix; things Flux applies into the cluster → SOPS. Encrypt
new cluster secrets with `sops` per `.sops.yaml`; new host secrets with agenix
per `secrets/secrets.nix`.

## Dependency updates

Renovate manages bumps. Run locally with `make renovate` (needs `gh` auth and
Docker; config in `.github/renovate.json5`).

## Known gotchas

- **VIP/LAN unreachable from the Mac** is almost always a dead WireGuard tunnel
  hijacking routes on the Mac — check that before blaming Cilium/MetalLB.
- `br_netfilter` is intentionally disabled on the host
  (`bridge-nf-call-iptables = 0`) so k8s/docker iptables don't mangle bridged VM
  traffic.
