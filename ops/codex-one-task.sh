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

block_publication() {
  local reason=$1 archive
  archive="$state/blocked/$task-$(git rev-parse HEAD)"
  mkdir -p "$archive"
  # Keep the original local branch and an independent private recovery bundle.
  # Never push blocked content or silently mark it completed.
  git bundle create "$archive/work.bundle" "refs/heads/$branch"
  printf 'Task: %s\nBranch: %s\nReason: %s\n' "$task" "$branch" "$reason" > "$archive/status.txt"
  sed -i "s/| $task |\\([^|]*\\)| [^|]* |/| $task |\\1| blocked |/" "$queue"
  printf '\n- %s: %s publication blocked: %s Private recovery: %s.\n' \
    "$(date -u +%FT%TZ)" "$task" "$reason" "$archive" >> "$queue"
  git switch --detach origin/main
  echo "Task $task preserved privately and blocked. Next tick can select another ready task."
}

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
  if ! gitleaks git --redact --log-opts="origin/main..HEAD" "$repo"; then
    block_publication "Secret scan failed; inspect privately before retrying."
    return 0
  fi
  url=$(gh pr list --repo mhumeSF/nix-media --head "$branch" --state all \
    --json url --jq '.[0].url // empty')
  if [[ -n "$url" ]]; then
    echo "Awaiting review: $url"
    return 0
  fi
  if git diff --name-only origin/main...HEAD | grep -Ei '(^|/)(docs|plans|reports|run-notes)(/|$)|(^|/)(TODO|PLAN|NOTES)(\.|$)|\.(md|log|jsonl)$'; then
    block_publication "Planning/documentation/log files must remain private."
    return 0
  fi
  # The wrapper publishes only its own task branch, never main or a force-push.
  # Retry on the next timer invocation if pushing or PR creation fails.
  git push -u origin "HEAD:refs/heads/$branch"
  {
    printf 'Prepared one maintenance task: %s.\n\n' "$task"
    printf 'Implementation changes only; planning and run notes remain private.\n'
    printf 'No automatic merge or deployment is performed by this worker.\n\n'
    printf 'The next scheduled run advances after GitHub confirms this revision was merged.\n'
  } > "$state/pr-body.md"
  gh pr create --repo mhumeSF/nix-media --base main --head "$branch" \
    --title "Maintenance code update ($task)" --body-file "$state/pr-body.md"
}

if [[ -n $(git status --porcelain) ]]; then
  echo "Paused: uncommitted work exists in $repo. Inspect and preserve it."
  exit 0
fi
git fetch origin main
previous_branch=$(git branch --show-current)
if [[ $(git rev-list --count origin/main..HEAD) != 0 ]]; then
  accepted=false
  if [[ "$previous_branch" =~ ^codex/(M[0-9]+)-[0-9]{8}T[0-9]{6}Z$ ]]; then
    # Squash/rebase merges do not preserve ancestry. Only acknowledge the
    # exact reviewed revision, with its merge present on the fetched main.
    pr=$(gh pr list --repo mhumeSF/nix-media --head "$previous_branch" --state all \
      --json state,headRefOid,baseRefName,mergeCommit,url \
      --jq '.[] | [.state, .headRefOid, .baseRefName, (.mergeCommit.oid // "-"), .url] | @tsv')
    if [[ -n "$pr" ]]; then
      IFS=$'\t' read -r pr_state pr_head pr_base pr_merge pr_url <<< "$pr"
      if [[ "$pr_state" == MERGED && "$pr_head" == "$(git rev-parse HEAD)" && "$pr_base" == main ]] \
        && git merge-base --is-ancestor "$pr_merge" origin/main; then
        accepted=true
        echo "Accepted merged task: $pr_url"
      elif [[ "$pr_state" != OPEN ]]; then
        echo "Paused: $pr_url is $pr_state but does not confirm this local revision was accepted. Preserve and reconcile the branch."
        exit 1
      fi
    fi
  fi
  if [[ "$accepted" != true ]]; then
    publish_for_review
    exit 0
  fi
fi
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
  git -c user.name=white-bear -c user.email=white-bear@media \
    -c commit.gpgsign=false commit -m "maintenance: $task unattended work for review"
  publish_for_review
else
  echo "Private task finished without public code changes. Inspect $run/summary.md for the outcome."
fi
