# Periodic Codex maintenance

Use a NixOS systemd timer, one fresh `codex exec` session per run, one task per
session, and one branch awaiting review at a time. Start every six hours. Faster
execution is useful once checks and review throughput justify it; parallel
storage/network changes on this single production host are a poor starting point.
TODO.md carries state between sessions. This is not a continuation of the Mac
conversation; the server session sees repository instructions and its own tools.

The runner makes local commits only. Flux watches main, so a main-branch merge
is a deployment decision. Review each branch before publishing or merging it.
The worker needs Codex authentication. GitHub CLI authentication is optional for
publishing branches manually; it does not need kubeconfig, an SSH deployment
key, sudo privileges, or Nix trusted-user privileges. A separate
VM provides stronger isolation if you later add less trusted tasks/tools.

## Nix work on the same host

Evaluation and builds can run on media itself. The worker defaults to one Nix
build job and two build cores, with a 45-minute session timeout. Its service is
limited to 4 GB RAM and two CPUs, but builds delegated to nix-daemon are outside
that service's cgroup limits. Watch free disk space and host load during the
first builds; lower concurrency is not a hard memory bound on compiler jobs.
Some builds may exceed the run deadline, and daemon-side work can outlive the
client. Start with evaluation and targeted builds, not a full-system build on
every timer tick.

Updating flake.lock and building a proposed system does not activate it. Keep
`nixos-rebuild switch` under owner control initially. A switch can restart VMs,
drop networking, or stop the worker if its own unit changes. NixOS generation
rollback does not undo application/database migrations. Later, automate only
explicitly eligible updates after successful build, backup and health checks;
keep storage, networking and identity migrations as separate maintenance work.

## Install on media.local

1. Commit these files locally and get them onto the repository's main branch
   through your normal review process. Preserve the unrelated flake.lock edit.
   To commit just this setup: `git add TODO.md ops` followed by
   `git commit -m "Add maintenance queue and periodic Codex runner"`.
2. The worker module is imported in configuration.nix. Deploy the host from
   the Mac using `make all`. Review the existing lock
   changes before deploying. This creates the account and units; the timer is
   not automatically started. Host Codex is already declared in configuration.nix.
3. SSH into the host as nixie and initialize the dedicated clone:

   ```sh
   sudo -u codex-worker -H git clone https://github.com/mhumeSF/nix-media.git /var/lib/codex-worker/repo
   sudo -u codex-worker -H git -C /var/lib/codex-worker/repo config user.name white-bear
   sudo -u codex-worker -H git -C /var/lib/codex-worker/repo config user.email white-bear@localhost
   sudo -u codex-worker -H git -C /var/lib/codex-worker/repo config commit.gpgsign false
   sudo -u codex-worker -H codex login --device-auth
   sudo -u codex-worker -H codex login status
   ```

   Follow the device URL/code on your own browser; enable device-code login in
   your account settings if required. Alternatively, provision an API key for
   the worker and use `codex login --with-api-key` via stdin. Do not put keys in
   Git or Nix expressions (Nix store contents are readable). Login is specific
   to this account; the Mac's session does not authenticate the server.
   If the repository is private, provision read-only repository access first.

4. Run a supervised first task and inspect the outcome:

   ```sh
   sudo systemctl start codex-maintenance.service
   sudo journalctl -u codex-maintenance.service -n 100 --no-pager
   sudo -u codex-worker -H git -C /var/lib/codex-worker/repo log -1 --stat
   sudo ls /var/lib/codex-worker/runs
   ```

   Each run records prompt, JSONL events, stderr and final summary in a private
   run directory. Inspect stderr if authentication or sandbox setup fails.
   The timeout limits elapsed time, not token spending; use your account/API
   usage controls as appropriate. Retain useful logs and periodically archive
   older run directories to avoid unbounded disk usage.

5. After the smoke test, enable scheduling declaratively by adding
   `wantedBy = [ "timers.target" ];` to the timer definition, then redeploy.
   For a temporary trial until reboot, simply run:

   ```sh
   sudo systemctl start codex-maintenance.timer
   systemctl list-timers codex-maintenance.timer
   ```

## Review and resume

### GitHub authentication and commit identity

Commits are authored and committed as `white-bear <white-bear@localhost>`.
This is a local Git identity, not a newly created GitHub account. Commits are
unsigned so unattended runs do not depend on the Mac's 1Password signer.
GitHub associates commits with accounts through verified email addresses;
this localhost address intentionally claims no existing GitHub account.

To publish using your GitHub account, authenticate **as the worker** on media:

```sh
sudo -u codex-worker -H gh auth login --hostname github.com --git-protocol https --web
sudo -u codex-worker -H gh auth setup-git
sudo -u codex-worker -H gh auth status
```

Then, after reviewing a completed local task, publish its branch:

```sh
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo push -u origin HEAD
```

The push uses your authenticated GitHub account while retaining white-bear as
the commit author. The scheduled runner still does not push or merge. If you
prefer not to store GitHub write credentials on the worker, use the bundle flow
below and publish from the Mac. GitHub login and Codex login are separate.

The next invocation fetches main and pauses if the checkout is dirty or HEAD
contains commits not on origin/main. Timeouts preserve partial edits for review.
No branch is automatically pushed, rebased, reset or deleted.

To bring a completed branch to your Mac without giving the worker write access,
first grant nixie a readable copy of a bundle on the server:

```sh
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo bundle create /var/lib/codex-worker/result.bundle HEAD
sudo install -o nixie -g users -m 0600 /var/lib/codex-worker/result.bundle /home/nixie/codex-result.bundle
```

On the Mac, choose a fresh review branch name:

```sh
scp nixie@media.local:codex-result.bundle /tmp/codex-result.bundle
git fetch /tmp/codex-result.bundle HEAD:refs/heads/review/codex-task
git diff main...review/codex-task
```

Review the patch and TODO run notes, run the relevant checks, and publish the
review branch using your normal GitHub credentials. Change the task status from
review to done when accepting it, and merge through your normal process. Live
migration tasks remain blocked until their explicit prerequisites are met.

After a merge commit retaining the worker commit, the next scheduled run can
advance automatically. After a squash/rebase merge (or an intentionally rejected
branch), pause the timer, preserve any partial work, and acknowledge the reviewed
result explicitly on the server:

```sh
sudo systemctl stop codex-maintenance.timer
# Wait for any running service to finish before touching the checkout.
systemctl is-active codex-maintenance.service
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo status --short
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo fetch origin main
# Only with a clean checkout and after resolving the previous task:
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo switch --detach origin/main
sudo systemctl start codex-maintenance.timer
```

The old branch remains available. If rejecting a task, update main's TODO entry
or instructions so the next run does not repeat the same unsuccessful approach.
Stopping the timer does not terminate an active run; use
`sudo systemctl stop codex-maintenance.service` only when you intend to interrupt
it, then inspect any partial edits before resuming.

## References and validation

- [Official non-interactive Codex documentation](https://developers.openai.com/codex/noninteractive/)
- [Official Codex authentication documentation](https://developers.openai.com/codex/auth/)

CLI options were checked against the local `codex exec --help`. Verify the
server's installed version supports the same options before enabling the timer.
The module is imported by the host configuration, but the timer is deliberately
not enabled at boot until authentication and the first run have been verified.
