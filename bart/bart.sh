#!/bin/bash
# Bart - Autonomous UI/UX Prototyping Agent Loop
# Usage:
#   npm run bart
#   bash bart/bart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
PROGRESS_LOG="$PROJECT_DIR/outputs/bart/bart-progress.log"
MAX_ITERATIONS=15

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---- Resolve brief file ----
BRIEF_FILE=""
BRIEFS=("$PROJECT_DIR"/outputs/bart/*-brief.json)

if [ ${#BRIEFS[@]} -eq 0 ] || [ ! -f "${BRIEFS[0]}" ]; then
  echo ""
  echo "No design briefs found in outputs/bart/"
  echo ""
  echo "Run /bart in Claude Code to generate one first:"
  echo "  /bart build a <description of what to prototype>"
  echo ""
  exit 1
elif [ ${#BRIEFS[@]} -eq 1 ]; then
  BRIEF_FILE="${BRIEFS[0]}"
  echo "Using brief: $(basename "$BRIEF_FILE")"
else
  echo ""
  echo "Multiple briefs found. Select one:"
  echo ""
  select f in "${BRIEFS[@]}"; do
    if [ -n "$f" ]; then
      BRIEF_FILE="$f"
      break
    else
      echo "Invalid selection. Try again."
    fi
  done
  echo ""
fi

PROJECT_NAME=$(jq -r '.project // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$BRIEF_FILE" 2>/dev/null || echo "unknown")
TASK_COUNT=$(jq '.designTasks | length' "$BRIEF_FILE" 2>/dev/null || echo "?")

# Scoped learnings — per project, not global
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-50)
LEARNINGS_FILE="$HOME/.claude/agents/learnings/bart/$PROJECT_SLUG.md"
mkdir -p "$HOME/.claude/agents/learnings/bart"

# ---- Worktree bootstrap ----
# Bart always runs inside .worktrees/ so it cannot trample your main checkout.
# If invoked from main, bootstrap a worktree and re-exec inside it.

GIT_TOPLEVEL=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
GIT_COMMON_DIR=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null || echo "")
case "$GIT_COMMON_DIR" in
  /*) ;;
  *) GIT_COMMON_DIR="$GIT_TOPLEVEL/$GIT_COMMON_DIR" ;;
esac
MAIN_REPO=$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd || echo "")

# ---- Preflight: required skills (checked against main repo) ----
MISSING_SKILLS=()
for SKILL in frontend-design userinterface-wiki; do
  if [ ! -f "$MAIN_REPO/.claude/skills/$SKILL/SKILL.md" ]; then
    MISSING_SKILLS+=("$SKILL")
  fi
done

if [ ${#MISSING_SKILLS[@]} -gt 0 ]; then
  echo ""
  echo "ERROR: Bart requires the following skills to be installed first:"
  for S in "${MISSING_SKILLS[@]}"; do
    echo "  Missing: .claude/skills/$S/SKILL.md"
  done
  echo ""
  echo "Add these skills to .claude/skills/ before running Bart."
  echo ""
  exit 1
fi

if [ "$GIT_TOPLEVEL" = "$MAIN_REPO" ]; then
  # Running from main repo — bootstrap a worktree and re-exec inside it.
  WORKTREE_NAME=$(echo "$BRANCH_NAME" | sed 's|/|-|g')
  WORKTREE_PATH="$MAIN_REPO/.worktrees/$WORKTREE_NAME"

  if [ ! -d "$WORKTREE_PATH" ]; then
    echo "Bootstrapping worktree at .worktrees/$WORKTREE_NAME (branch $BRANCH_NAME)..."
    git fetch origin dev || echo "Warning: could not fetch origin/dev"

    # Guard: git won't allow a worktree on a branch already checked out in the main repo
    MAIN_CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ "$MAIN_CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
      echo ""
      echo "Error: main repo is already on branch '$BRANCH_NAME'."
      echo "Switch to another branch first, then re-run:"
      echo "  git checkout dev && npm run bart"
      echo ""
      exit 1
    fi

    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" \
       || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
      git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
    else
      git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/dev
    fi
  else
    echo "Reusing existing worktree at .worktrees/$WORKTREE_NAME"
  fi

  echo "Syncing Bart state into worktree..."
  mkdir -p "$WORKTREE_PATH/outputs/bart/screenshots"
  cp "$BRIEF_FILE" "$WORKTREE_PATH/outputs/bart/$(basename "$BRIEF_FILE")"
  [ -f "$PROJECT_DIR/outputs/bart/progress.txt" ] && \
    cp "$PROJECT_DIR/outputs/bart/progress.txt" "$WORKTREE_PATH/outputs/bart/progress.txt" || true

  echo "Setting up worktree env (.env + node_modules)..."
  (cd "$WORKTREE_PATH" && npm run worktree:setup)

  echo "Re-executing Bart inside worktree..."
  cd "$WORKTREE_PATH"
  exec "$SCRIPT_DIR/bart.sh"
fi

# ---- We are inside a worktree ----
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo ""
  echo "Error: worktree on branch '$CURRENT_BRANCH' but design-brief.json expects '$BRANCH_NAME'."
  echo "       Run from main repo to bootstrap a fresh worktree, or fix the branch manually."
  echo ""
  exit 1
fi
echo "Running Bart inside worktree: $GIT_TOPLEVEL"
echo "Branch: $CURRENT_BRANCH"

# ---- Set up ----
mkdir -p "$PROJECT_DIR/outputs/bart/screenshots" "$HOME/.claude/agents/learnings"
cd "$PROJECT_DIR"

# Reset progress log so tail sees only this run's output
: > "$PROGRESS_LOG"

TAIL_PID=""
CLAUDE_PID=""

cleanup() {
  [ -n "$CLAUDE_PID" ] && kill "$CLAUDE_PID" 2>/dev/null || true
  [ -n "$TAIL_PID" ] && kill "$TAIL_PID" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Force headless browser mode for autonomous runs
unset AGENT_BROWSER_HEADED

echo ""
echo "================================================================"
echo "  Bart — UI/UX Prototyping Agent"
echo "================================================================"
echo "  Project:  $PROJECT_NAME"
echo "  Branch:   $BRANCH_NAME"
echo "  Tasks:    $TASK_COUNT design tasks"
echo "  Brief:    $BRIEF_FILE"
echo "  Started:  $(date)"
echo "================================================================"
echo ""

# ---- Main loop ----
for i in $(seq 1 $MAX_ITERATIONS); do
  # Determine next task and phase from the brief
  NEXT_ID=$(jq -r '[.designTasks[] | select(.complete == false and .phase != "blocked")] | sort_by(.priority) | first | .id // empty' "$BRIEF_FILE" 2>/dev/null)
  NEXT_PHASE=$(jq -r '[.designTasks[] | select(.complete == false and .phase != "blocked")] | sort_by(.priority) | first | .phase // empty' "$BRIEF_FILE" 2>/dev/null)
  NEXT_TITLE=$(jq -r '[.designTasks[] | select(.complete == false and .phase != "blocked")] | sort_by(.priority) | first | .title // empty' "$BRIEF_FILE" 2>/dev/null)

  # Exit early if nothing left to do
  if [ -z "$NEXT_ID" ]; then
    echo ""
    echo "  All tasks complete or blocked — nothing left to run."
    break
  fi

  echo "---------------------------------------------------------------"
  echo "  Bart Iteration $i — $NEXT_ID [$NEXT_PHASE]: $NEXT_TITLE"
  echo "---------------------------------------------------------------"
  echo ""

  TEMP_OUT=$(mktemp)

  # Load scoped learnings for this project (written by bart-feedback.sh)
  PRIOR_LEARNINGS=""
  if [ -f "$LEARNINGS_FILE" ]; then
    PRIOR_LEARNINGS=$(cat "$LEARNINGS_FILE")
  fi

  # Inject task+phase + prior learnings at the top of each fresh session.
  # The model sees its exact job and accumulated PM feedback before any instructions.
  SESSION_PROMPT=$(printf '## Your Job This Session\n\nExecute exactly this one phase — do not move on to the next task or phase:\n\n- **Task ID**: %s\n- **Task Title**: %s\n- **Phase**: %s\n\nStart immediately. Do not re-read the brief to decide what to do.\n\n---\n\n## Prior Learnings for This Project\n\n%s\n\n---\n\n%s' \
    "$NEXT_ID" "$NEXT_TITLE" "$NEXT_PHASE" \
    "${PRIOR_LEARNINGS:-"No prior learnings — first run on this project."}" \
    "$(cat "$PROMPT_FILE")")

  # Run claude in background, capturing full output to temp file
  echo "$SESSION_PROMPT" | claude --model sonnet --dangerously-skip-permissions --print > "$TEMP_OUT" 2>&1 &
  CLAUDE_PID=$!

  # Tail the progress log in real time — shows [Bart] lines as bart writes them
  tail -n 0 -F "$PROGRESS_LOG" 2>/dev/null &
  TAIL_PID=$!

  # Wait for claude to finish
  wait $CLAUDE_PID || true
  CLAUDE_PID=""

  # Let tail flush final lines
  sleep 0.5
  kill "$TAIL_PID" 2>/dev/null || true
  wait "$TAIL_PID" 2>/dev/null || true
  TAIL_PID=""

  # Check for completion signal
  if grep -q "<promise>COMPLETE</promise>" "$TEMP_OUT"; then
    rm -f "$TEMP_OUT"
    echo ""
    echo "================================================================"
    echo "  Bart completed all design tasks!"
    echo "  Completed at iteration $i of $MAX_ITERATIONS — $(date)"
    echo "  Screenshots: outputs/bart/screenshots/"
    echo "  Worktree:    $GIT_TOPLEVEL"
    echo "================================================================"

    # ---- Post to Linear if issue ID is set ----
    LINEAR_ISSUE_ID=$(jq -r '.linearIssueId // empty' "$BRIEF_FILE" 2>/dev/null)
    ENV_FILE="$HOME/.lisa-env"
    if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

    if [ -n "$LINEAR_ISSUE_ID" ] && [ -n "$LINEAR_API_KEY" ]; then
      echo "  Posting design summary to Linear $LINEAR_ISSUE_ID..."

      # Build task summary
      TASK_SUMMARY=$(jq -r '.designTasks[] | "- **\(.id)** — \(.title) (`\(.page)`)"' "$BRIEF_FILE" 2>/dev/null)

      COMMENT="Bart has completed the prototype for **$PROJECT_NAME**.

## Design Tasks Completed

$TASK_SUMMARY

## Next Step

Review the prototype in the codebase on branch \`$BRANCH_NAME\`. When happy with the design, move this ticket to **Design Review** and decide on your solution before handing to Marge."

      COMMENT_JSON=$(printf '%s' "$COMMENT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")

      # Get the internal issue ID from Linear using the identifier (e.g. FDE-12)
      TEAM_KEY=$(echo "$LINEAR_ISSUE_ID" | sed 's/-[0-9]*//')
      ISSUE_NUM=$(echo "$LINEAR_ISSUE_ID" | sed 's/.*-//')
      ISSUES_RESPONSE=$(curl -s -X POST \
        -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"query\":\"{ issues(filter: { team: { key: { eq: \\\"$TEAM_KEY\\\" } }, number: { eq: $ISSUE_NUM } }) { nodes { id } } }\"}" \
        https://api.linear.app/graphql)
      INTERNAL_ID=$(echo "$ISSUES_RESPONSE" | jq -r '.data.issues.nodes[0].id // empty')

      if [ -n "$INTERNAL_ID" ]; then
        curl -s -X POST \
          -H "Authorization: $LINEAR_API_KEY" \
          -H "Content-Type: application/json" \
          --data "{\"query\":\"mutation { commentCreate(input: { issueId: \\\"$INTERNAL_ID\\\", body: $COMMENT_JSON }) { success } }\"}" \
          https://api.linear.app/graphql > /dev/null
        echo "  Comment posted to $LINEAR_ISSUE_ID"
      else
        echo "  Could not resolve $LINEAR_ISSUE_ID to an internal ID — skipping Linear comment"
      fi
    fi

    exit 0
  fi

  rm -f "$TEMP_OUT"
  echo ""
  echo "  [iteration $i done — picking up next phase]"
  echo ""
  sleep 2
done

echo ""
echo "Bart reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check outputs/bart/design-brief.json for status (look for 'blocked' tasks)."
exit 1
