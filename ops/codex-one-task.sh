#!/usr/bin/env bash
set -euo pipefail
umask 077

# Linux runner; use only with a dedicated clone owned by the worker account.
repo=${CODEX_TASK_REPO:-/var/lib/codex-worker/repo}
state=${CODEX_TASK_STATE:-/var/lib/codex-worker/runs}
mkdir -p "$state/plans"
queue="$state/TODO.md"
if [[ ! -f "$queue" ]]; then
  echo "Private task queue missing: $queue"
  exit 1
fi
exec 9>"$state/runner.lock"
flock -n 9 || exit 0
export GIT_TERMINAL_PROMPT=0
cd "$repo"
test -d .git

publish_for_review() {
  local branch task url
  branch=$(git branch --show-current)
  if [[ ! "$branch" =~ ^codex/(M[0-9]+)-[0-9]{8}T[0-9]{6}Z$ ]]; then
    echo "Paused: $branch is not a worker task branch; publish it manually."
    return 0
  fi
  task=${BASH_REMATCH[1]}
  # This repository is public. Scan only unpublished work, redact findings,
  # and stop before any push if potential credentials are detected.
  gitleaks git --redact --log-opts="origin/main..HEAD" "$repo"
  url=$(gh pr list --repo mhumeSF/nix-media --head "$branch" --state all \
    --json url --jq '.[0].url // empty')
  if [[ -n "$url" ]]; then
    echo "Awaiting review: $url (closed or squash-merged PRs need manual acknowledgement)."
    return 0
  fi
  if git diff --name-only origin/main...HEAD | grep -Ei '(^|/)(docs|plans|reports|run-notes)(/|$)|(^|/)(TODO|PLAN|NOTES)(\.|$)|\.(md|log|jsonl)$'; then
    echo "Publication blocked: planning/documentation/log files must remain private."
    return 1
  fi
  # The wrapper publishes only its own task branch, never main or a force-push.
  # Retry on the next timer invocation if pushing or PR creation fails.
  git push -u origin "HEAD:refs/heads/$branch"
  {
    printf 'Prepared one maintenance task: %s.\n\n' "$task"
    printf 'Implementation changes only; planning and run notes remain private.\n'
    printf 'No automatic merge or deployment is performed by this worker.\n\n'
    printf 'Merge with a merge commit to let the next scheduled run advance.\n'
  } > "$state/pr-body.md"
  gh pr create --repo mhumeSF/nix-media --base main --head "$branch" \
    --title "Maintenance code update ($task)" --body-file "$state/pr-body.md"
}

if [[ -n $(git status --porcelain) ]]; then
  echo "Paused: uncommitted work exists in $repo. Inspect and preserve it."
  exit 0
fi
git fetch origin main
if [[ $(git rev-list --count origin/main..HEAD) != 0 ]]; then
  publish_for_review
  exit 0
fi
previous_branch=$(git branch --show-current)
if [[ "$previous_branch" =~ ^codex/(M[0-9]+)-[0-9]{8}T[0-9]{6}Z$ ]]; then
  accepted_task=${BASH_REMATCH[1]}
  sed -i "s/| $accepted_task |\([^|]*\)| review |/| $accepted_task |\1| done |/" "$queue"
fi
git switch --detach origin/main
task=$(awk -F '|' '$4 ~ /^ ready $/ {gsub(/ /, "", $2); print $2; exit}' "$queue")
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
printf '\nSelected task: %s\nCurrent branch: %s\nPrivate queue: %s\nPrivate plans directory: %s/plans\n' "$task" "$branch" "$queue" "$state" >> "$run/prompt.txt"
echo "Starting $task on $branch; logs: $run"

# Git metadata can be protected by Codex's sandbox, so the wrapper commits.
# Network access permits fetching dependency/docs inputs. The wrapper uses
# the worker's GitHub login to publish the completed branch after Codex exits.
timeout --signal=TERM --kill-after=30s 45m \
  codex exec --sandbox workspace-write --add-dir "$state" \
    -c approval_policy='"never"' \
    -c sandbox_workspace_write.network_access=true \
    --json --output-last-message "$run/summary.md" - \
    < "$run/prompt.txt" > "$run/events.jsonl" 2> "$run/stderr.log"

git diff --check
if [[ -n $(git status --porcelain) ]]; then
  git add --all
  git -c user.name=white-bear -c user.email=white-bear@localhost \
    -c commit.gpgsign=false commit -m "maintenance: $task unattended work for review"
  publish_for_review
else
  echo "Private task finished without public code changes. Inspect $run/summary.md for the outcome."
fi
