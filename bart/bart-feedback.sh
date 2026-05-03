#!/bin/bash
# Bart Feedback — Post-run PM review
# Usage:
#   npm run bart:feedback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
BRIEF_FILE="$PROJECT_DIR/outputs/bart/design-brief.json"
SCREENSHOTS_DIR="$PROJECT_DIR/outputs/bart/screenshots"

if [ ! -f "$BRIEF_FILE" ]; then
  echo ""
  echo "No design brief found. Run npm run bart first."
  echo ""
  exit 1
fi

PROJECT_NAME=$(jq -r '.project // "Unknown"' "$BRIEF_FILE")
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-50)
LEARNINGS_FILE="$HOME/.claude/agents/learnings/bart/$PROJECT_SLUG.md"
mkdir -p "$HOME/.claude/agents/learnings/bart"

echo ""
echo "================================================================"
echo "  Bart Feedback — $PROJECT_NAME"
echo "================================================================"
echo ""

# ---- Show task summary ----
TASK_COUNT=$(jq '.designTasks | length' "$BRIEF_FILE")
echo "  Tasks ($TASK_COUNT):"
echo ""

for i in $(seq 0 $((TASK_COUNT - 1))); do
  ID=$(jq -r ".designTasks[$i].id" "$BRIEF_FILE")
  TITLE=$(jq -r ".designTasks[$i].title" "$BRIEF_FILE")
  PHASE=$(jq -r ".designTasks[$i].phase" "$BRIEF_FILE")
  COMPLETE=$(jq -r ".designTasks[$i].complete" "$BRIEF_FILE")
  SCORES=$(jq -r '.designTasks['"$i"'].scores | to_entries | map("\(.key): \(.value)") | join(", ")' "$BRIEF_FILE" 2>/dev/null || echo "")

  if [ "$COMPLETE" = "true" ]; then
    STATUS="done"
  elif [ "$PHASE" = "blocked" ]; then
    STATUS="BLOCKED"
  else
    STATUS="in progress ($PHASE)"
  fi

  echo "  $ID — $TITLE"
  echo "    Status: $STATUS"
  [ -n "$SCORES" ] && echo "    Scores: $SCORES"
  echo ""
done

# ---- Show screenshots ----
SCREENSHOT_COUNT=$(ls "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$SCREENSHOT_COUNT" -gt 0 ]; then
  echo "  Screenshots ($SCREENSHOT_COUNT):"
  ls "$SCREENSHOTS_DIR"/*.png 2>/dev/null | while read -r f; do
    echo "    $(basename "$f")"
  done
  echo ""
fi

# ---- Collect feedback per completed/blocked task ----
echo "----------------------------------------------------------------"
echo "  Quick feedback — press enter to skip any question"
echo "----------------------------------------------------------------"
echo ""

FEEDBACK_ENTRIES=""

for i in $(seq 0 $((TASK_COUNT - 1))); do
  ID=$(jq -r ".designTasks[$i].id" "$BRIEF_FILE")
  TITLE=$(jq -r ".designTasks[$i].title" "$BRIEF_FILE")
  PHASE=$(jq -r ".designTasks[$i].phase" "$BRIEF_FILE")
  COMPLETE=$(jq -r ".designTasks[$i].complete" "$BRIEF_FILE")

  # Only ask feedback for tasks that ran (complete or blocked)
  if [ "$COMPLETE" != "true" ] && [ "$PHASE" != "blocked" ]; then
    continue
  fi

  echo "  $ID — $TITLE"
  echo ""

  read -r -p "  Did it build the right thing? (y/n or note) > " Q1
  read -r -p "  Any scores that felt off? (e.g. 'interaction was really a 2') > " Q2
  read -r -p "  What was missing or wrong? > " Q3
  echo ""

  ENTRY="### $ID — $TITLE ($(date +%Y-%m-%d))
- Built the right thing: ${Q1:-"(no answer)"}
- Scores felt off: ${Q2:-"(no answer)"}
- What was missing: ${Q3:-"(no answer)"}"

  FEEDBACK_ENTRIES="$FEEDBACK_ENTRIES
$ENTRY
"
done

# ---- Overall run note ----
read -r -p "  Overall note about this run? > " OVERALL
echo ""

# ---- Write to learnings file ----
DATE=$(date +%Y-%m-%d)

cat >> "$LEARNINGS_FILE" << EOF

## PM Feedback — $DATE — $PROJECT_NAME
$FEEDBACK_ENTRIES
**Overall:** ${OVERALL:-"(none)"}

EOF

echo "----------------------------------------------------------------"
echo "  Feedback saved to:"
echo "  $LEARNINGS_FILE"
echo "================================================================"
echo ""
