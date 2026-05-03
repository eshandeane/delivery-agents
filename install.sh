#!/bin/bash
# Delivery Agents — Install Script
# Wires Lisa, Bart, and Prince into a project.
#
# Usage:
#   bash install.sh                          # prompts for project path
#   bash install.sh --project /path/to/proj  # non-interactive

set -e

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Colours ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

echo ""
echo "================================================================"
echo "  Delivery Agents — Installer"
echo "================================================================"
echo ""

# ---- Check dependencies ----
echo "Checking dependencies..."

command -v claude >/dev/null 2>&1 || fail "claude CLI not found. Install it from https://claude.ai/download"
ok "claude CLI found ($(claude --version 2>/dev/null | head -1))"

command -v jq >/dev/null 2>&1 || fail "jq not found. Install with: brew install jq"
ok "jq found"

echo ""

# ---- Get project path ----
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$PROJECT_DIR" ]; then
  echo "Which project do you want to install agents into?"
  echo "(Press Enter to use the current directory: $(pwd))"
  echo ""
  read -r -p "  Project path: " INPUT
  PROJECT_DIR="${INPUT:-$(pwd)}"
fi

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || fail "Project directory not found: $PROJECT_DIR"

if [ ! -f "$PROJECT_DIR/package.json" ]; then
  fail "No package.json found in $PROJECT_DIR. Is this a Node.js project?"
fi

echo ""
echo "  Installing into: $PROJECT_DIR"
echo ""

# ---- Install skills ----
echo "Installing Claude skills..."

for AGENT in lisa bart prince; do
  SKILL_SRC="$AGENTS_DIR/$AGENT/skill/SKILL.md"
  SKILL_DEST="$PROJECT_DIR/.claude/skills/$AGENT/SKILL.md"

  if [ -f "$SKILL_SRC" ]; then
    mkdir -p "$(dirname "$SKILL_DEST")"
    cp "$SKILL_SRC" "$SKILL_DEST"
    ok "$AGENT skill → .claude/skills/$AGENT/SKILL.md"
  else
    warn "$AGENT skill not found at $SKILL_SRC — skipping"
  fi
done

echo ""

# ---- Update package.json scripts ----
echo "Adding npm scripts to package.json..."

PACKAGE_JSON="$PROJECT_DIR/package.json"
TMP_FILE="$PACKAGE_JSON.tmp"

jq \
  --arg lisa  "bash $AGENTS_DIR/lisa/lisa.sh" \
  --arg bart  "bash $AGENTS_DIR/bart/bart.sh" \
  --arg prince "bash $AGENTS_DIR/prince/prince.sh" \
  '.scripts.lisa = $lisa | .scripts.bart = $bart | .scripts.prince = $prince' \
  "$PACKAGE_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$PACKAGE_JSON"

ok "npm run lisa"
ok "npm run bart"
ok "npm run prince"

echo ""

# ---- Create output directories ----
echo "Creating output directories..."

mkdir -p "$PROJECT_DIR/outputs/lisa"
mkdir -p "$PROJECT_DIR/outputs/discovery"
mkdir -p "$PROJECT_DIR/outputs/bart/screenshots"
mkdir -p "$PROJECT_DIR/outputs/acceptance-tests"

ok "outputs/lisa/"
ok "outputs/discovery/"
ok "outputs/bart/screenshots/"
ok "outputs/acceptance-tests/"

echo ""

# ---- Slack config ----
echo "Slack config (used by Lisa to post run notifications):"
echo "(Press Enter to skip)"
echo ""
read -r -p "  Your Slack email: " SLACK_EMAIL
read -r -p "  Slack channel for notifications (without #): " SLACK_CHANNEL

CONFIG_FILE="$PROJECT_DIR/outputs/lisa/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" << EOF
{
  "slackEmail": "$SLACK_EMAIL",
  "slackChannel": "$SLACK_CHANNEL"
}
EOF
  ok "outputs/lisa/config.json created"
else
  warn "outputs/lisa/config.json already exists — skipping (edit manually to update Slack config)"
fi

echo ""

# ---- Done ----
echo "================================================================"
echo "  Installation complete."
echo "================================================================"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Start a research run:"
echo "       /lisa  (in Claude Code) → then: npm run lisa"
echo ""
echo "  2. Start a prototyping run:"
echo "       /bart  (in Claude Code) → then: npm run bart"
echo ""
echo "  3. Run acceptance tests:"
echo "       /prince  (in Claude Code) → then: npm run prince -- <prd-file>"
echo ""
echo "  4. Watch progress live:"
echo "       tail -f outputs/lisa-progress.log"
echo ""
echo "  Agents dir: $AGENTS_DIR"
echo "  Project:    $PROJECT_DIR"
echo ""
