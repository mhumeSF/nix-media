Read TODO.md and CLAUDE.md. The launcher identifies one task below. Work only
on that task, verifying its premise against current files and pinned upstream
sources. Complete the authorized repository edits and appropriate validation.

This is an unattended repository-maintenance run on a production machine using
a dedicated unprivileged account. Prepare changes for review. Do not deploy,
run make all, restart services, mutate a live cluster, move application data,
decrypt secrets, run backup syncs, or change remote Git state. Do not use sudo.
Do not modify this runner, its prompt, or its systemd configuration as part of
an unrelated task. Do not spawn additional agents.

Do not commit, switch branches, merge, reset, or push: the launcher owns Git
lifecycle and commits your result after successful exit. Preserve unrelated
files. Never mark an untested migration as done. When implementation and checks
are complete, set this task to review. If required evidence is unavailable,
set it to blocked and state precisely what is needed; do not fabricate evidence
or proceed to another task. Update TODO.md run notes in either case.

Finish with task ID, changes, tests, limitations and the next review/deployment
step. You have approximately 40 minutes; leave a useful handoff before that.
