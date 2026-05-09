#!/bin/bash
# Prince - Acceptance Testing Agent
# Usage:
#   1. Run /prince in Claude Code to generate a brief
#   2. npm run prince

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
BRIEF_FILE="$PROJECT_DIR/outputs/prince/brief.json"
PROGRESS_FILE="$PROJECT_DIR/outputs/prince-progress.log"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---- Check for brief ----
if [ ! -f "$BRIEF_FILE" ]; then
  echo ""
  echo "No brief found at outputs/prince/brief.json"
  echo ""
  echo "Run /prince in Claude Code to generate one first:"
  echo "  /prince  (in Claude Code, with the PRD in context)"
  echo ""
  exit 1
fi

PRD_FILE=$(jq -r '.prdFile // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
FEATURE=$(jq -r '.feature // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
BRANCH=$(jq -r '.branch // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
CREATED_AT=$(jq -r '.createdAt // ""' "$BRIEF_FILE" 2>/dev/null || echo "")

if [ -z "$PRD_FILE" ]; then
  echo ""
  echo "Brief is missing 'prdFile'. Re-run /prince in Claude Code."
  echo ""
  exit 1
fi

if [ ! -f "$PROJECT_DIR/$PRD_FILE" ]; then
  echo ""
  echo "PRD file not found: $PRD_FILE"
  echo "Check the path in outputs/prince/brief.json or re-run /prince."
  echo ""
  exit 1
fi

# ---- Check brief age ----
if [ -n "$CREATED_AT" ]; then
  BRIEF_EPOCH=$(date -j -f "%Y-%m-%d" "$CREATED_AT" "+%s" 2>/dev/null || date -d "$CREATED_AT" "+%s" 2>/dev/null || echo "0")
  NOW_EPOCH=$(date "+%s")
  AGE_DAYS=$(( (NOW_EPOCH - BRIEF_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -ge 2 ]; then
    echo ""
    echo "  Brief is $AGE_DAYS days old (created $CREATED_AT)."
    echo "  Run /prince to generate a fresh brief, or continue with the existing one."
    echo ""
    read -r -p "  Continue anyway? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "  Aborted. Run /prince in Claude Code to generate a new brief."
      exit 0
    fi
  fi
fi

# ---- Set up ----
mkdir -p "$PROJECT_DIR/outputs/acceptance-tests" "$HOME/.claude/agents/learnings"
cd "$PROJECT_DIR"

# Reset progress log so tail -f sees only this run's lines.
: > "$PROGRESS_FILE"

TAIL_PID=""
CLAUDE_PID=""

cleanup() {
  [ -n "$CLAUDE_PID" ] && kill "$CLAUDE_PID" 2>/dev/null || true
  [ -n "$TAIL_PID" ] && kill "$TAIL_PID" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo ""
echo "================================================================"
echo "  Prince — Acceptance Testing Agent"
echo "================================================================"
echo "  Feature:  $FEATURE"
echo "  PRD:      $PRD_FILE"
echo "  Branch:   ${BRANCH:-"(current)"}"
echo "  Brief:    $BRIEF_FILE"
echo "  Started:  $(date)"
echo "================================================================"
echo ""
echo "Streaming progress below (Claude runs autonomously — no UI opens)."
echo "----------------------------------------------------------------"

# Stream progress log in real time
tail -n 0 -F "$PROGRESS_FILE" 2>/dev/null &
TAIL_PID=$!

# ---- Run Claude ----
PROMPT=$(cat "$PROMPT_FILE")
BRIEF=$(cat "$BRIEF_FILE")
PRD_CONTENT=$(cat "$PROJECT_DIR/$PRD_FILE")
{
  echo "$PROMPT"
  echo ""
  echo "## Run Brief"
  echo ""
  echo "$BRIEF"
  echo ""
  echo "## PRD Content"
  echo ""
  echo "$PRD_CONTENT"
} | claude --model sonnet --dangerously-skip-permissions --print > >(tee /dev/stderr) 2>&1 &
CLAUDE_PID=$!

wait $CLAUDE_PID || true
CLAUDE_PID=""

sleep 0.3
kill "$TAIL_PID" 2>/dev/null || true
wait "$TAIL_PID" 2>/dev/null || true
TAIL_PID=""
echo ""
tail -n 5 "$PROGRESS_FILE" 2>/dev/null

echo ""
echo "----------------------------------------------------------------"
echo "  Prince run complete — $(date)"
echo "  Reports: outputs/acceptance-tests/"
echo "  Progress log: $PROGRESS_FILE"
echo "================================================================"
