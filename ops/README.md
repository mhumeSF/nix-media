# Periodic Codex maintenance

The systemd timer launches a fresh Codex session every six hours. Each session
handles one ready task from TODO.md, validates its work and updates run notes.
The wrapper commits as `white-bear <white-bear@localhost>`, pushes the task
branch and opens a GitHub PR. It never merges or deploys. It pauses until that
branch is merged; only one task is awaiting review at a time.

The timer is enabled across reboots. GitHub authentication and Codex login must
both be configured as codex-worker. No sudo privileges or live cluster
credentials are needed for repository work.

## Initial setup

Deploy the imported ops/codex-worker.nix module with the normal reviewed host
configuration. Initialize /var/lib/codex-worker/repo as a clone of
https://github.com/mhumeSF/nix-media.git, owned by codex-worker. Then on media:

```sh
sudo -u codex-worker -H sh -c 'cd "$HOME" && gh auth login --git-protocol https --web && gh auth setup-git'
sudo -u codex-worker -H sh -c 'cd "$HOME" && codex login --device-auth'
sudo systemctl start codex-maintenance.service
sudo journalctl -u codex-maintenance.service -n 50 --no-pager
```

Changing directory matters: sudo -H alone can leave the worker in an
inaccessible /home/nixie working directory. Authentication is specific to the
worker account; the Mac's credentials do not authenticate the server.
The unsigned white-bear identity is a local Git identity, not a separate GitHub
account. Branch publication uses the account authenticated through gh.

## Review and recovery

Task PRs include their ID and title; TODO.md run notes carry validation and
limitations. Merge using a merge commit so the next run recognizes the work as
accepted. Change review to done when accepting a task. No model session starts
while an earlier task branch remains unmerged.

If pushing or creating a PR fails, the local commit remains intact. The next
invocation retries publication before pausing. Existing PRs are not duplicated.
A closed/rejected or squash-merged PR requires explicit acknowledgement after
review; it does not cause the worker to discard work automatically.

After a squash/rebase merge or rejection, pause the timer, wait for any running
service to finish, and preserve partial work. Only with a clean checkout and
the previous task resolved, acknowledge it on the server:

```sh
sudo systemctl stop codex-maintenance.timer
systemctl is-active codex-maintenance.service
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo status --short
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo fetch origin main
sudo -u codex-worker -H git -C /var/lib/codex-worker/repo switch --detach origin/main
sudo systemctl start codex-maintenance.timer
```

The old branch remains available. Update main's TODO entry when rejecting a
task to avoid repeating it. Dirty worktrees and timeouts require inspection;
the runner never resets, deletes or force-pushes branches. Stopping the timer
does not stop an active task. Logs, stderr and final summaries are kept in
/var/lib/codex-worker/runs; periodically archive older logs.

## Host resources and deployment boundary

Sessions have a 45-minute timeout. The service has a 4 GB memory limit and two
CPUs, and requests one Nix build job with two cores. Nix-daemon builds run
outside that service's cgroup and may outlive its client; these are not hard
host-wide memory or spending limits. Watch free disk and load. Start with
evaluation and targeted builds rather than rebuilding the full host each run.

The worker prepares repository changes. It does not switch NixOS, restart VMs,
mutate Kubernetes, decrypt secrets or migrate data. Flux deploys cluster changes
from main after review. NixOS rollback does not undo database migrations.

## References

- [Official non-interactive Codex documentation](https://developers.openai.com/codex/noninteractive/)
- [Official Codex authentication documentation](https://developers.openai.com/codex/auth/)

## Public repository

AGENTS.md and the task prompt prohibit publishing secrets, raw logs, personal
data and newly discovered private infrastructure details. Public procedures
use placeholders. The wrapper runs Gitleaks against task commits with findings
redacted before any push. A finding stops publication and leaves the local work
for inspection; do not bypass the scanner. Gitleaks detects credential patterns,
not every kind of sensitive information, so a public-safe diff review is still
required. Run logs and authentication files stay outside the checkout.
