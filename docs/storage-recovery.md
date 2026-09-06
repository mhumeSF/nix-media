# Storage and recovery plan

This document is the M02 planning artifact. It records what the repository
declares and the live evidence that must be collected before M05 or M06 changes
storage. It is not evidence that a backup or restore has succeeded.

## Static inventory

| Data | Application path | Backing declared by this repository | Static durability assessment |
| --- | --- | --- | --- |
| Immich Postgres | pod `/var/lib/postgresql/data`; PVC `default/immich-postgres-pvc` | dynamic `local-path` PV | **At risk.** The pinned v0.0.31 manifest provisions below `/opt/local-path-provisioner`; that path is on the VM root, not the block volume mounted at `/var/lib/rancher/k3s/storage`. |
| etcd | VM `/var/lib/etcd` (evaluated NixOS default) | no share or `microvm.volume` | **At risk.** It is on the disposable VM root. This is the k3s datastore, so Kubernetes objects, including PVC bindings and Secrets, depend on it. |
| k3s identity and server state | VM `/var/lib/rancher/k3s/server`, especially `server/tls`, `server/token`, and credential/config files | no share or `microvm.volume`; only declarative bootstrap manifests are recreated | **At risk.** Cluster CA and generated identity are not persistent. The agenix-managed API token file is reproducible, but is not a substitute for the generated k3s CA/server state. |
| VM SSH identity / agenix identity | VM `/persist/ssh`; agenix secrets decrypted at activation | host `/var/lib/microvms/k3s/persist` via virtiofs | Persistent on the host root filesystem, but no retained backup is declared. The SSH key is required to decrypt VM agenix secrets. |
| Kubernetes/cert-manager certificates | Kubernetes Secrets in etcd; Flux bootstrap SOPS key is sourced from agenix | etcd plus the encrypted sources in Git/agenix | Issued certificate Secrets are lost with etcd. Declarative issuers and encrypted inputs can reconcile only after the k3s identity and SOPS bootstrap key are restored. |
| Omada database/config | pod `/opt/tplink/EAPController/data`; hostPath `/omada/data` | no matching VM share or block volume | **At risk.** `/omada` is on the disposable VM root. Logs at `/omada/logs` have the same placement, though logs are not recovery-critical. |
| Plex configuration | host `/tank0/plex` | imported host ZFS pool `tank0` | Persistent and described as snapshotted, but snapshot policy and restore evidence are not declared here. |
| Immich managed uploads | pod chart `library` mount; static PV `/gato-bucket/immich` | host `/tank0/gato-bucket/immich` via `/gato-bucket` virtiofs | Persistent on `tank0`; PV reclaim policy is `Retain`. |
| Photo inbox and archive | pod `/external/inbox`, `/external/archive` (read-only) | host `/tank0/gato-bucket/photos/{inbox,archive}` via `/gato-bucket` | Persistent on `tank0`. Only the archive has a checked-in rclone job; retention and restore testing belong to M09. |
| Media libraries | VM `/movies`; Plex reads host pool paths directly | host `/movies` virtiofs share for k3s; host storage topology is not declared | Runtime mount source and backup coverage require live confirmation. |
| Container cache | VM `/var/lib/rancher/k3s/agent/containerd` | host image `.../volumes/containerd.img`, block-backed ext4 | Persistent but disposable/rebuildable; not backup-critical. |
| Intended local PVC disk | VM `/var/lib/rancher/k3s/storage` | host image `.../volumes/storage.img`, block-backed ext4, 128 GiB | Persistent, but the active provisioner does not use it. |

The upstream source used by the active Kustomization is
`rancher/local-path-provisioner` tag `v0.0.31`, file
`deploy/local-path-storage.yaml`. Its `local-path-config` sets
`DEFAULT_PATH_FOR_NON_LISTED_NODES` to `/opt/local-path-provisioner`. The
repository also declares a Flux `GitRepository` at v0.0.37, but the application
does not consume it; it consumes the v0.0.31 raw URL. Do not use the v0.0.37
object as evidence for the deployed configuration.

## Live preflight (required before a maintenance window)

Run these read-only checks on `media.local` and save their output with the
change record. They deliberately separate observed state from the declarations
above.

```sh
# Host: confirm pools, datasets, mounts, space, and the VM backing files.
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS / /tank0 /movies
zpool status tank0
zfs list -o name,mountpoint,used,avail,refer -r tank0
ls -l /var/lib/microvms/k3s/volumes

# VM: confirm every relevant path crosses the expected filesystem boundary.
findmnt -T /persist
findmnt -T /gato-bucket/immich
findmnt -T /gato-bucket/photos/archive
findmnt -T /var/lib/rancher/k3s/storage
findmnt -T /opt/local-path-provisioner
findmnt -T /var/lib/etcd
findmnt -T /var/lib/rancher/k3s/server/tls
findmnt -T /omada/data
df -hT /var/lib/rancher/k3s/storage /gato-bucket /persist

# Cluster: map claims to actual node paths; do not infer them from claim names.
kubectl get nodes -o wide
kubectl get pvc -A -o wide
kubectl get pv -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,CLAIM_NS:.spec.claimRef.namespace,CLAIM:.spec.claimRef.name,NODEPATH:.spec.local.path,HOSTPATH:.spec.hostPath.path,RECLAIM:.spec.persistentVolumeReclaimPolicy
kubectl -n local-path-storage get configmap local-path-config -o yaml
kubectl get pods -A -o wide
kubectl get secret -A
```

Also record application-level baselines: Postgres database size and selected
table row counts, Immich asset totals and library scan status, Omada controller
version/site/device counts, Plex library item counts, and checksums/counts for a
small named photo sample. Do not print Secret data.

Stop if any expected mount resolves to the VM root, if `tank0` is degraded, if
free space cannot hold both old and new copies plus backups, or if a PV path
does not match its observed claim. Resolve that discrepancy before proceeding.

## Backup and restore prerequisites

Before changing storage, create dated artifacts on storage outside the source
filesystem and record checksums, ownership, modes, tool versions, and restore
commands. At minimum:

1. Take a logical Postgres backup with `pg_dump`/`pg_dumpall --globals-only`,
   validate it with `pg_restore --list`, and restore it into an isolated test
   database. Record the baseline queries against the restored copy.
2. Take an etcd v3 snapshot with `etcdctl snapshot save`, then run
   `etcdctl snapshot status`. Prove a restore into an isolated temporary data
   directory with the pinned etcd version; never point a restore test at
   `/var/lib/etcd`.
3. Back up `/var/lib/rancher/k3s/server` and `/persist/ssh` while preserving
   ownership, modes, ACLs, xattrs, hard links, and symlinks. Treat these as
   secrets. Verify archive readability and compare a manifest after extraction
   into an isolated directory.
4. Use the controller's supported export/backup for Omada, and verify that the
   archive can be opened by the same controller version. A filesystem copy is
   supplemental, not a substitute for the application export.
5. Snapshot or otherwise back up the relevant `tank0` datasets for Plex,
   managed uploads, and photos. Record the exact snapshot names and prove that
   a named sample can be read from the snapshot/backup.

M05 must not start without the verified database backup and live PV inventory.
M06 must not start without a tested etcd restore and verified identity archive.
M09 defines long-term retention; ad-hoc migration copies are not that policy.

## Migration sequence

Use a scheduled maintenance window. Prepare reviewed Nix/manifests first, but
do not reconcile them until backups and live preflight pass.

1. Quiesce writes at the application layer. Scale down Immich and its Postgres
   deployment after the logical dump; stop Omada after its export. Record the
   exact original replica counts. Verify no relevant pod remains writing.
2. For M05, configure local-path-provisioner explicitly for node `k3s` with
   `/var/lib/rancher/k3s/storage` and keep `WaitForFirstConsumer`. Do not merely
   edit the provisioner: existing PVs retain their recorded paths.
3. Copy each existing local-path volume separately to a new directory on the
   storage volume using a metadata-preserving tool. Compare byte counts, file
   counts, ownership/modes, and a checksum manifest while writers remain down.
4. Rebind through reviewed PV/PVC manifests that preserve claim identity and
   use `Retain`; Kubernetes PV source paths are immutable, so plan controlled
   PV object replacement rather than an in-place path patch. Never delete an
   old data directory during this window. Verify the bound PV's path before
   restoring replicas.
5. Move Omada only after its application backup is verified, using the same
   stopped-copy-verify pattern and a path on an explicitly persistent mount.
6. For M06, add dedicated persistent backing and mount ordering for
   `/var/lib/etcd` and the required `/var/lib/rancher/k3s/server` identity
   state. With k3s and etcd stopped, seed empty destinations from the verified
   sources, preserve metadata, and ensure mounts are present before etcd/k3s.
   Never start etcd or k3s against an empty destination over live data.
7. Start etcd, then k3s, then Postgres, Immich, and Omada. Check service logs,
   endpoints, PVC bindings, application baselines, and the photo sample.

Exact stop/start and copy commands must be written from the live unit names and
PV paths captured during preflight. This plan intentionally does not guess
those runtime values.

## Rollback

Keep old directories and backing images read-only and unchanged until review
accepts the migration. If verification fails, quiesce writers again, stop k3s
and etcd when their state is involved, restore the previous Nix configuration
and PV manifests, remount the original backing paths, and start services in the
original order. Confirm the same baselines before reopening writes.

If the new copy has accepted writes, do not blindly switch to the stale old
copy. Preserve both sides, take a fresh backup, and choose an application-aware
reconciliation or restore point. For etcd, restore the verified snapshot as a
coherent datastore; never merge two etcd data directories. For Postgres, use
the verified logical/physical recovery method rather than copying files from a
running server.

## Reboot verification and acceptance evidence

After migration checks pass, perform one owner-approved host reboot (not as
part of M02). Before reboot record cluster UID/CA fingerprints without exposing
private keys, node/PV/PVC identities, application baselines, mounts, and ZFS
health. After reboot verify:

- `tank0`, virtiofs shares, storage volumes, etcd, and k3s mounted/started in
  dependency order with no empty replacement directories;
- the cluster CA fingerprint, namespace/object inventory, PV names, claim UIDs,
  and bindings are unchanged;
- Postgres readiness and recorded row counts, Immich asset totals and sample
  reads, Omada site/device state, Plex library counts/playback, and certificate
  readiness match the baseline;
- new local-path claims resolve below `/var/lib/rancher/k3s/storage`; and
- no workload data path resolves to the VM root filesystem.

Only then may M05/M06 be marked done and old copies be scheduled for a separate,
reviewed cleanup. A successful configuration evaluation alone is not recovery
evidence.
