#!/bin/bash
# Lisa - Discovery Research Agent
# Usage:
#   1. Run /lisa in Claude Code to generate a brief
#   2. npm run lisa

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
BRIEF_FILE="$PROJECT_DIR/outputs/lisa/brief.json"
PROGRESS_FILE="$PROJECT_DIR/outputs/lisa-progress.log"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---- Check for brief ----
if [ ! -f "$BRIEF_FILE" ]; then
  echo ""
  echo "No brief found at outputs/lisa/brief.json"
  echo ""
  echo "Run /lisa in Claude Code to generate one first:"
  echo "  /lisa should we build X for Y? decide for Q2 roadmap."
  echo ""
  exit 1
fi

TARGET_USER=$(jq -r '.targetUser // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
GOAL=$(jq -r '.discoveryGoal // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
DECISION=$(jq -r '.decision // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
SCOPE=$(jq -r '.scope // "full"' "$BRIEF_FILE" 2>/dev/null || echo "full")
CREATED_AT=$(jq -r '.createdAt // ""' "$BRIEF_FILE" 2>/dev/null || echo "")

# ---- Check brief age ----
if [ -n "$CREATED_AT" ]; then
  BRIEF_EPOCH=$(date -j -f "%Y-%m-%d" "$CREATED_AT" "+%s" 2>/dev/null || date -d "$CREATED_AT" "+%s" 2>/dev/null || echo "0")
  NOW_EPOCH=$(date "+%s")
  AGE_DAYS=$(( (NOW_EPOCH - BRIEF_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -ge 2 ]; then
    echo ""
    echo "  ⚠️  Brief is $AGE_DAYS days old (created $CREATED_AT)."
    echo "     Run /lisa to generate a fresh brief, or continue with the existing one."
    echo ""
    read -r -p "  Continue anyway? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "  Aborted. Run /lisa in Claude Code to generate a new brief."
      exit 0
    fi
  fi
fi

# ---- Set up ----
mkdir -p "$PROJECT_DIR/outputs/discovery" "$HOME/.claude/agents/learnings"
cd "$PROJECT_DIR"

# Reset the progress log so tail -f sees only this run's lines.
: > "$PROGRESS_FILE"

TAIL_PID=""

cleanup() {
  if [ -n "$TAIL_PID" ]; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo ""
echo "================================================================"
echo "  Lisa — Discovery Research Agent"
echo "================================================================"
echo "  Target user: $TARGET_USER"
echo "  Goal:        $GOAL"
echo "  Decision:    $DECISION"
echo "  Scope:       $SCOPE"
echo "  Brief:       $BRIEF_FILE"
echo "  Started:     $(date)"
echo "================================================================"
echo ""
echo "Streaming progress below (Claude runs autonomously — no UI opens)."
echo "----------------------------------------------------------------"

# Stream progress log in real time
tail -n 0 -F "$PROGRESS_FILE" 2>/dev/null &
TAIL_PID=$!

# ---- Load config ----
CONFIG_FILE="$PROJECT_DIR/outputs/lisa/config.json"
SLACK_EMAIL=$(jq -r '.slackEmail // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
SLACK_CHANNEL=$(jq -r '.slackChannel // ""' "$CONFIG_FILE" 2>/dev/null || echo "")

# ---- Run Claude ----
PROMPT=$(cat "$PROMPT_FILE")
BRIEF=$(cat "$BRIEF_FILE")
{
  echo "$PROMPT"
  echo ""
  echo "## User Input for This Run"
  echo ""
  echo "Research brief (structured — no parsing needed):"
  echo ""
  echo "$BRIEF"
  echo ""
  echo "## Slack Config"
  echo "slackEmail: $SLACK_EMAIL"
  echo "slackChannel: $SLACK_CHANNEL"
} | claude --model sonnet --dangerously-skip-permissions --print 2>&1

sleep 0.3
kill "$TAIL_PID" 2>/dev/null || true
wait "$TAIL_PID" 2>/dev/null || true
TAIL_PID=""
echo ""
tail -n 5 "$PROGRESS_FILE" 2>/dev/null

echo ""
echo "----------------------------------------------------------------"
echo "  Lisa run complete — $(date)"
echo "  Discovery docs: outputs/discovery/"
echo "  Progress log:   $PROGRESS_FILE"
echo "================================================================"
