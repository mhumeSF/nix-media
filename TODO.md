# Maintenance queue

This file is the durable handoff between fresh Codex sessions. Findings began
with the 2026-09-05 static review; verify them before changing configuration.
Runtime state may differ from Git. Work on exactly one `ready` task per run,
in table order. `review` means implemented on a branch, not deployed or proven
healthy in production. The reviewer changes it to `done` when accepting it.
Use `blocked` with a concrete reason when required evidence is unavailable.

| ID | Priority | Status | Task |
| --- | --- | --- | --- |
| M01 | P1 | ready | Add repository validation before automated dependency merges |
| M02 | P0 | ready | Document and verify the persistent storage and recovery plan |
| M03 | P1 | ready | Align Flux HelmRelease health checks with served APIs |
| M04 | P1 | blocked | Exclude the host reservation from the Cilium address pool |
| M05 | P0 | blocked | Migrate local-path PVC data onto persistent storage |
| M06 | P0 | blocked | Persist etcd and required k3s identity state |
| M07 | P0 | ready | Store rclone credentials in a Kubernetes Secret |
| M08 | P0 | blocked | Rotate and encrypt Immich database credentials |
| M09 | P1 | ready | Design retained backups and a restore drill |
| M10 | P1 | blocked | Migrate Omada data and ingress |
| M11 | P2 | ready | Correct architecture documentation and identify unused resources |
| M12 | P2 | ready | Audit monitoring persistence and useful failure alerts |

## Acceptance criteria and blockers

- **M01:** Add PR checks for local Kustomize composition, Kubernetes API/schema
  compatibility where feasible, and Nix evaluation with locked inputs. Include
  nested Flux targets rather than only the root. Document remote-resource and
  Helm-rendering gaps. Restrict Renovate automerge until required checks and
  branch protection are actually configured; repository settings need owner action.
- **M02:** Produce a mount/data inventory covering Postgres, etcd, k3s identity,
  certificates, Omada, Plex and photos. Confirm the pinned provisioner's default
  path against the VM disk mount. Write preflight, backup, migration, rollback,
  and reboot-verification steps. Separate static evidence from live checks.
  This task prepares a plan; it does not move data or restart anything.
- **M03:** Verify the bundled CRDs and all active health checks. Update obsolete
  HelmRelease API references, validate every affected target, and explain how
  readiness/dependencies change. Check inactive manifests too.
- **M04:** Blocked until the owner confirms that 10.0.201.202 is still the host's
  reservation and supplies current LB allocations. Split the Cilium pool without
  disrupting an allocated service; document reconciliation verification.
- **M05:** Blocked on M02, live PVC/PV path inventory and a verified database
  backup. Change the provisioner path, migrate existing data explicitly, and
  verify record counts and persistence after restart. Editing the path alone
  does not migrate existing volumes. Deployment requires a maintenance window.
- **M06:** Blocked on M02 and a tested datastore/identity backup. Persist etcd
  plus required k3s state, keep service mount ordering correct, and verify that
  PVC bindings and CA identity survive a restart. Do not initialize over live data.
- **M07:** Replace the rclone ConfigMap containing substituted B2 credentials
  with a Secret and update the volume source. Preserve SOPS-based substitution.
  Validate manifests without decrypting or printing credentials.
- **M08:** Blocked on a database backup and owner-coordinated rotation. Use
  encrypted Secret data and secretKeyRef consistently. Changing POSTGRES_PASSWORD
  does not rotate the password in an existing database. Include rollback steps.
- **M09:** Document coverage, retention and restore commands for archive photos,
  managed uploads, Postgres, Plex, Omada, and cluster identity. Assess B2 version
  retention and rclone deletion safeguards. Prepare reviewable configuration
  where no live credentials are needed; do not run sync or delete remote data.
- **M10:** Blocked on an Omada backup and confirmed device connectivity needs.
  Move /omada/data to persistent storage and migrate the old Cilium Ingress to
  the active Envoy Gateway setup. Verify management and adoption traffic.
- **M11:** Document Cilium BGP + Envoy as active, MetalLB as inactive, plain
  Postgres as Immich's database, and the block-backed storage exception. Identify
  unused operators/sources. Do not remove live resources based only on file names.
- **M12:** Assess Grafana/Prometheus/Loki retention, backup failure alerts,
  disk capacity and ZFS health coverage. Propose a small useful alert set and
  identify which notifications require an owner-provided destination.

## Run notes

Append one entry per attempted task: UTC date, task ID, branch, changes,
validation commands/results, remaining limitations, and next action. Never
record credentials. A failed or timed-out run is not a completed task.
