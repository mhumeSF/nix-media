# Maintenance worker

The worker reads its private queue from `$CODEX_TASK_STATE/TODO.md` (default:
`/var/lib/codex-worker/runs/TODO.md`). Plans and run notes stay in that private
state directory, outside Git. Seed the queue privately before starting the
service. The Codex sandbox permits writes to this directory and the checkout.

Planning-only tasks produce no public commit or PR and do not block later
tasks. Code tasks open a PR, then wait for a merge commit before advancing.
Secret scanning and a documentation/log path check run before publication.
No automatic merge, deployment or live migration is performed by the worker.

The timer runs every six hours and survives reboot. Inspect the service journal
and private state directory for results. GitHub and Codex authentication belong
to the dedicated worker account. Never copy private diagnostics into an issue.
