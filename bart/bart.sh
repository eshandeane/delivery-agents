#!/bin/bash
# Bart - Autonomous UI/UX Prototyping Agent Loop
# Usage:
#   npm run bart
#   bash bart/bart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
BRIEF_FILE="$PROJECT_DIR/outputs/bart/design-brief.json"
PROGRESS_LOG="$PROJECT_DIR/outputs/bart/bart-progress.log"
MAX_ITERATIONS=15

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---- Check for design brief ----
if [ ! -f "$BRIEF_FILE" ]; then
  echo ""
  echo "No design brief found at outputs/bart/design-brief.json"
  echo ""
  echo "Run /bart in Claude Code to generate one first:"
  echo "  /bart build a <description of what to prototype>"
  echo ""
  exit 1
fi

# ---- Preflight: required skills ----
MISSING_SKILLS=()
for SKILL in frontend-design userinterface-wiki; do
  if [ ! -f "$PROJECT_DIR/.claude/skills/$SKILL/SKILL.md" ]; then
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

PROJECT_NAME=$(jq -r '.project // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$BRIEF_FILE" 2>/dev/null || echo "unknown")
TASK_COUNT=$(jq '.designTasks | length' "$BRIEF_FILE" 2>/dev/null || echo "?")

# Scoped learnings — per project, not global
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-50)
LEARNINGS_FILE="$HOME/.claude/agents/learnings/bart/$PROJECT_SLUG.md"
mkdir -p "$HOME/.claude/agents/learnings/bart"

# ---- Branch check ----
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo "  Branch mismatch: on '$CURRENT_BRANCH', expected '$BRANCH_NAME'"
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "  Checking out: $BRANCH_NAME"
    git -C "$PROJECT_DIR" checkout "$BRANCH_NAME"
  else
    echo "  Creating branch: $BRANCH_NAME"
    git -C "$PROJECT_DIR" checkout -b "$BRANCH_NAME"
  fi
  echo ""
fi

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
    echo "================================================================"
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
