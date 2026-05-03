#!/bin/bash
# Bart - Autonomous UI/UX Prototyping Agent Loop
# Usage:
#   npm run bart
#   bash bart/bart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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

PROJECT_NAME=$(jq -r '.project // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$BRIEF_FILE" 2>/dev/null || echo "unknown")
TASK_COUNT=$(jq '.designTasks | length' "$BRIEF_FILE" 2>/dev/null || echo "?")

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
  echo "---------------------------------------------------------------"
  echo "  Bart Iteration $i of $MAX_ITERATIONS"
  echo "---------------------------------------------------------------"
  echo ""

  TEMP_OUT=$(mktemp)

  # Run claude in background, capturing full output to temp file
  claude --model sonnet --dangerously-skip-permissions --print < "$PROMPT_FILE" > "$TEMP_OUT" 2>&1 &
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
