#!/bin/bash
# Marge - PRD Writing Agent
# Usage:
#   1. Run /marge in Claude Code to generate a brief
#   2. npm run marge -- --feature <feature-slug>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md"
PROGRESS_FILE="$PROJECT_DIR/outputs/marge-progress.log"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---- Parse --feature flag ----
FEATURE_SLUG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_SLUG="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# ---- Resolve brief file ----
if [ -n "$FEATURE_SLUG" ]; then
  BRIEF_FILE="$PROJECT_DIR/outputs/marge/${FEATURE_SLUG}-brief.json"
else
  # Fall back to listing available briefs
  BRIEFS=("$PROJECT_DIR"/outputs/marge/*-brief.json)
  if [ ${#BRIEFS[@]} -eq 0 ] || [ ! -f "${BRIEFS[0]}" ]; then
    echo ""
    echo "No briefs found in outputs/marge/"
    echo ""
    echo "Run /marge in Claude Code to generate one first:"
    echo "  /marge"
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
fi

# ---- Check for brief ----
if [ ! -f "$BRIEF_FILE" ]; then
  echo ""
  echo "No brief found at $BRIEF_FILE"
  echo ""
  echo "Run /marge in Claude Code to generate one first:"
  echo "  /marge"
  echo ""
  exit 1
fi

FEATURE=$(jq -r '.feature // "Unknown"' "$BRIEF_FILE" 2>/dev/null || echo "Unknown")
LINEAR_ISSUE=$(jq -r '.linearIssueId // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
JIRA_ISSUE=$(jq -r '.jiraIssueId // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
JIRA_URL=$(jq -r '.jiraIssueUrl // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
LISA_DOC=$(jq -r '.lisaDiscoveryDoc // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
BART_BRIEF=$(jq -r '.bartDesignBrief // ""' "$BRIEF_FILE" 2>/dev/null || echo "")
CREATED_AT=$(jq -r '.createdAt // ""' "$BRIEF_FILE" 2>/dev/null || echo "")

# ---- Check brief age ----
if [ -n "$CREATED_AT" ]; then
  BRIEF_EPOCH=$(date -j -f "%Y-%m-%d" "$CREATED_AT" "+%s" 2>/dev/null || date -d "$CREATED_AT" "+%s" 2>/dev/null || echo "0")
  NOW_EPOCH=$(date "+%s")
  AGE_DAYS=$(( (NOW_EPOCH - BRIEF_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -ge 2 ]; then
    echo ""
    echo "  Brief is $AGE_DAYS days old (created $CREATED_AT)."
    echo "  Run /marge to generate a fresh brief, or continue with the existing one."
    echo ""
    read -r -p "  Continue anyway? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "  Aborted. Run /marge in Claude Code to generate a new brief."
      exit 0
    fi
  fi
fi

# ---- Validate inputs exist ----
if [ -n "$LISA_DOC" ] && [ ! -f "$PROJECT_DIR/$LISA_DOC" ]; then
  echo ""
  echo "  WARNING: Lisa discovery doc not found at $LISA_DOC"
  echo "  Marge will proceed without it — but the PRD will be weaker."
  echo ""
fi

if [ -n "$BART_BRIEF" ] && [ ! -f "$PROJECT_DIR/$BART_BRIEF" ]; then
  echo ""
  echo "  ERROR: Bart design brief not found at $BART_BRIEF"
  echo "  Marge requires Bart's design brief. Run Bart first."
  echo ""
  exit 1
fi

# ---- Set up ----
mkdir -p "$PROJECT_DIR/outputs/marge" "$PROJECT_DIR/outputs/prds" "$HOME/.claude/agents/learnings"
cd "$PROJECT_DIR"

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
echo "  Marge — PRD Writing Agent"
echo "================================================================"
echo "  Feature:      $FEATURE"
echo "  Linear issue: ${LINEAR_ISSUE:-"(none)"}"
echo "  Jira issue:   ${JIRA_ISSUE:-"(none)"}${JIRA_URL:+" — $JIRA_URL"}"
echo "  Lisa doc:     ${LISA_DOC:-"(none)"}"
echo "  Bart brief:   ${BART_BRIEF:-"(none)"}"
echo "  Brief:        $BRIEF_FILE"
echo "  Started:      $(date)"
echo "================================================================"
echo ""
echo "Streaming progress below (Claude runs autonomously — no UI opens)."
echo "----------------------------------------------------------------"

tail -n 0 -F "$PROGRESS_FILE" 2>/dev/null &
TAIL_PID=$!

# ---- Assemble context ----
BRIEF_CONTENT=$(cat "$BRIEF_FILE")
LISA_CONTENT=""
if [ -n "$LISA_DOC" ] && [ -f "$PROJECT_DIR/$LISA_DOC" ]; then
  LISA_CONTENT=$(cat "$PROJECT_DIR/$LISA_DOC")
fi
BART_CONTENT=""
if [ -n "$BART_BRIEF" ] && [ -f "$PROJECT_DIR/$BART_BRIEF" ]; then
  BART_CONTENT=$(cat "$PROJECT_DIR/$BART_BRIEF")
fi

# ---- Run Claude ----
{
  cat "$PROMPT_FILE"
  echo ""
  echo "## Run Brief"
  echo ""
  echo "$BRIEF_CONTENT"
  echo ""
  if [ -n "$LISA_CONTENT" ]; then
    echo "## Lisa Discovery Output"
    echo ""
    echo "$LISA_CONTENT"
    echo ""
  fi
  if [ -n "$BART_CONTENT" ]; then
    echo "## Bart Design Brief"
    echo ""
    echo "$BART_CONTENT"
    echo ""
  fi
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
echo "  Marge run complete — $(date)"
echo "  PRD: outputs/prds/"
echo "  Ralph input: ralph/prd.json"
echo "  Progress log: $PROGRESS_FILE"
echo "================================================================"
