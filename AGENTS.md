# Public repository

This repository and its pull requests are public. Treat all committed files,
PR descriptions and comments as publicly accessible.

- Never publish credentials, private keys, decrypted secrets, authentication
  files, raw host/session logs, database contents or personal data.
- Do not add newly discovered private infrastructure inventories, identifiers
  or addresses. Use placeholders in public operational examples. Existing
  public configuration does not authorize publishing further live details.
- Keep diagnostics outside the repository. Report public-safe conclusions and
  validation results rather than raw output that may contain private data.
- Review the complete diff before publication. Run the configured secret scan;
  do not bypass it or add exclusions simply to make a task pass. Scanners do
  not replace reviewing infrastructure and personal information.

Read CLAUDE.md for architecture and deployment conventions and TODO.md for
task scope. Scheduled workers follow ops/codex-task-prompt.md and leave merging
and deployment to review.
