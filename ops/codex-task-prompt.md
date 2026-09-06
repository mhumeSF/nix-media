Read TODO.md and CLAUDE.md. The launcher identifies one task below. Work only
on that task, verifying its premise against current files and pinned upstream
sources. Complete the authorized repository edits and appropriate validation.

This repository and its PRs are PUBLIC. Never commit credentials, private keys,
decrypted secrets, authentication files, raw command/session logs, database
contents, personal data, or newly discovered private infrastructure details.
Use placeholders in public procedures for private identifiers and addresses.
Existing public configuration is not authorization to publish additional live
inventory. Record only the minimum public-safe evidence needed for review.
Keep sensitive diagnostics out of the repository and PR text. If completing a
task requires publishing sensitive material, block it and explain the missing
private handoff without including that material. Do not disable, bypass or add
allowlists to the publication secret scan to complete a task. A passing secret
scan does not establish that infrastructure details or personal data are safe
to publish; review the entire diff for these before finishing.

This is an unattended repository-maintenance run on a production machine using
a dedicated unprivileged account. Prepare changes for review. Do not deploy,
run make all, restart services, mutate a live cluster, move application data,
decrypt secrets, run backup syncs, or change remote Git state. Do not use sudo.
Do not modify this runner, its prompt, or its systemd configuration as part of
an unrelated task. Do not spawn additional agents.

Do not commit, switch branches, merge, reset, or push: the launcher owns Git
lifecycle, commits your result and opens a review PR after successful exit. Preserve unrelated
files. Never mark an untested migration as done. When implementation and checks
are complete, set this task to review. If required evidence is unavailable,
set it to blocked and state precisely what is needed; do not fabricate evidence
or proceed to another task. Update TODO.md run notes in either case.

Finish with task ID, changes, tests, limitations and the next review/deployment
step. You have approximately 40 minutes; leave a useful handoff before that.
