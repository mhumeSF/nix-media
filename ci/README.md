# Repository validation and Renovate

`Repository validation` is the required GitHub check. The workflow uses standard
tools directly: Nix evaluates the locked NixOS configuration; Kustomize builds
every checked-in target, including remote resources; kubeconform checks the
rendered Kubernetes resources against Kubernetes 1.34 schemas. A grep check
rejects obsolete HelmRelease API references. There is no custom validator.

The tools are pinned through flake.lock. Enter `nix develop .#ci` to use the
same Kustomize, kubeconform and yq versions locally. The full commands are in
.github/workflows/validate.yaml.

Limitations: this does not build the complete system, render Helm charts,
decrypt secrets, test migrations or check runtime health. kubeconform skips
custom resources when a schema is unavailable and reports the skipped count.
yq removes SOPS metadata only from the validation stream; encrypted values stay
encrypted. Manifest and schema downloads require network access.

Renovate runs hourly at minute 17 and on main pushes, with manual dispatch
available. Runs are serialized. Stable minor, patch, and digest updates can
merge through GitHub after required checks pass. Major and pre-1.0 version
updates require review. GitHub must have Allow auto-merge enabled and main must
require `Repository validation`. Requiring the branch to be up to date checks
updates together with previously merged changes.

Do not use ignoreTests to bypass validation. Flux deploys cluster changes from
main automatically; passing static checks does not prove runtime compatibility.
