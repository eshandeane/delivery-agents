#!/bin/bash
# Prince - Acceptance Testing Agent
# Usage:
#   npm run prince -- "<prd-file>"
#   bash /path/to/prince/prince.sh "<prd-file>"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
PROGRESS_FILE="$PROJECT_DIR/outputs/prince-progress.log"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

INPUT="$*"

if [ -z "$INPUT" ]; then
  echo ""
  echo "Prince needs a PRD file to test against."
  echo ""
  echo "Examples:"
  echo "  npm run prince -- prd-context-management.md"
  echo "  npm run prince -- ralph/tasks/prd-my-feature.md"
  echo "  npm run prince -- --skip-setup prd-my-feature.md"
  echo ""
  read -r -p "> " INPUT
  if [ -z "$INPUT" ]; then
    echo "No input provided. Exiting."
    exit 1
  fi
fi

mkdir -p "$PROJECT_DIR/outputs"
cd "$PROJECT_DIR"

: > "$PROGRESS_FILE"

echo ""
echo "================================================================"
echo "  Prince — Acceptance Testing Agent"
echo "================================================================"
echo "  Input:    $INPUT"
echo "  Started:  $(date)"
echo "  Project:  $PROJECT_DIR"
echo "  Progress: $PROGRESS_FILE"
echo "================================================================"
echo ""
echo "Streaming progress below (Claude runs autonomously — no UI opens)."
echo "----------------------------------------------------------------"

tail -n 0 -F "$PROGRESS_FILE" 2>/dev/null &
TAIL_PID=$!

cleanup() {
  if [ -n "$TAIL_PID" ]; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

PROMPT=$(cat "$PROMPT_FILE")
{
  echo "$PROMPT"
  echo ""
  echo "## User Input for This Run"
  echo ""
  echo "$INPUT"
} | claude --model sonnet --dangerously-skip-permissions --print 2>&1

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
