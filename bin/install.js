#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const AGENTS_DIR = path.join(os.homedir(), ".claude", "agents");
const LEARNINGS_DIR = path.join(AGENTS_DIR, "learnings");

const PKG_DIR = path.join(__dirname, "..");
const AGENTS_SRC = path.join(PKG_DIR, "agents");
const LEARNINGS_SRC = path.join(PKG_DIR, "learnings");

const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const RESET = "\x1b[0m";

function log(msg) {
  console.log(msg);
}

function success(msg) {
  console.log(`${GREEN}✓${RESET} ${msg}`);
}

function warn(msg) {
  console.log(`${YELLOW}!${RESET} ${msg}`);
}

function header(msg) {
  console.log(`\n${BOLD}${msg}${RESET}`);
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function copyFile(src, dest, overwrite = true) {
  if (!overwrite && fs.existsSync(dest)) {
    warn(`Skipped ${path.basename(dest)} — already exists (preserving your data)`);
    return false;
  }
  fs.copyFileSync(src, dest);
  return true;
}

function isInstalled(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

header("delivery-agents installer");
log("Installing Lisa, Bart, and Prince into ~/.claude/agents/\n");

// 1. Create directories
ensureDir(AGENTS_DIR);
ensureDir(LEARNINGS_DIR);

// 2. Copy agent files
header("Agents");
const agents = fs.readdirSync(AGENTS_SRC).filter((f) => f.endsWith(".md"));
for (const file of agents) {
  const src = path.join(AGENTS_SRC, file);
  const dest = path.join(AGENTS_DIR, file);
  const existed = fs.existsSync(dest);
  copyFile(src, dest, true);
  success(`${file}${existed ? " (updated)" : ""}`);
}

// 3. Copy learnings — never overwrite (preserve accumulated data)
header("Learnings");
const learnings = fs.readdirSync(LEARNINGS_SRC).filter((f) => f.endsWith(".md"));
for (const file of learnings) {
  const src = path.join(LEARNINGS_SRC, file);
  const dest = path.join(LEARNINGS_DIR, file);
  const copied = copyFile(src, dest, false);
  if (copied) success(`${file} (starter)`);
}

// 4. Check agent-browser
header("Dependencies");
if (isInstalled("agent-browser")) {
  success("agent-browser is installed");
} else {
  warn("agent-browser not found — install it with:");
  log(`   ${CYAN}npm i -g agent-browser && agent-browser install${RESET}`);
}

// 5. Print alias instructions
header("Terminal aliases");
log("Add these to your ~/.zshrc or ~/.bashrc:\n");
log(`   ${CYAN}alias bart='claude --agent bart --dangerously-skip-permissions'`);
log(`   alias lisa='claude --agent lisa --dangerously-skip-permissions'`);
log(`   alias prince='claude --agent prince --dangerously-skip-permissions'${RESET}\n`);
log("Then reload your shell:  source ~/.zshrc\n");

header("Done");
log("Run agents from your project directory:");
log(`   ${CYAN}bart${RESET}    — UI/UX prototyping`);
log(`   ${CYAN}lisa${RESET}    — discovery research`);
log(`   ${CYAN}prince${RESET}  — acceptance testing\n`);
