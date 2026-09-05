#!/usr/bin/env bash
set -euo pipefail
umask 077

# Linux runner; use only with a dedicated clone owned by the worker account.
repo=${CODEX_TASK_REPO:-/var/lib/codex-worker/repo}
state=${CODEX_TASK_STATE:-/var/lib/codex-worker/runs}
mkdir -p "$state"
exec 9>"$state/runner.lock"
flock -n 9 || exit 0
export GIT_TERMINAL_PROMPT=0
cd "$repo"
test -d .git
if [[ -n $(git status --porcelain) ]]; then
  echo "Paused: uncommitted work exists in $repo. Inspect and preserve it."
  exit 0
fi
git fetch origin main
if [[ $(git rev-list --count origin/main..HEAD) != 0 ]]; then
  echo "Paused: $(git branch --show-current) has commits awaiting review."
  exit 0
fi
git switch --detach origin/main
task=$(awk -F '|' '$4 ~ /^ ready $/ {gsub(/ /, "", $2); print $2; exit}' TODO.md)
if [[ -z "$task" ]]; then
  echo "No ready tasks."
  exit 0
fi
[[ "$task" =~ ^M[0-9]+$ ]]
stamp=$(date -u +%Y%m%dT%H%M%SZ)
branch="codex/$task-$stamp"
run="$state/$stamp-$task"
mkdir -p "$run"
git switch -c "$branch"
cat ops/codex-task-prompt.md > "$run/prompt.txt"
printf '\nSelected task: %s\nCurrent branch: %s\n' "$task" "$branch" >> "$run/prompt.txt"
echo "Starting $task on $branch; logs: $run"

# Git metadata can be protected by Codex's sandbox, so the wrapper commits.
# Network access permits fetching dependency/docs inputs. GitHub login is
# optional for owner-initiated publication; this runner never pushes.
timeout --signal=TERM --kill-after=30s 45m \
  codex exec --sandbox workspace-write \
    -c approval_policy='"never"' \
    -c sandbox_workspace_write.network_access=true \
    --json --output-last-message "$run/summary.md" - \
    < "$run/prompt.txt" > "$run/events.jsonl" 2> "$run/stderr.log"

git diff --check
if [[ -n $(git status --porcelain) ]]; then
  git add --all
  git -c user.name=white-bear -c user.email=white-bear@localhost \
    -c commit.gpgsign=false commit -m "maintenance: $task unattended work for review"
  echo "Committed locally on $branch. Review before publishing or merging."
else
  echo "No changes. Inspect $run/summary.md for the outcome."
fi
