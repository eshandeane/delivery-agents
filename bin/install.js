#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const AGENTS_DIR = path.join(os.homedir(), ".claude", "agents");
const LEARNINGS_DIR = path.join(AGENTS_DIR, "learnings");
const SKILLS_DIR = path.join(os.homedir(), ".claude", "skills");
const PERSONAS_DIR = path.join(os.homedir(), ".claude", "personas");

const PKG_DIR = path.join(__dirname, "..");

const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

const success = (msg) => console.log(`${GREEN}✓${RESET} ${msg}`);
const warn = (msg) => console.log(`${YELLOW}!${RESET} ${msg}`);
const header = (msg) => console.log(`\n${BOLD}${msg}${RESET}`);
const dim = (msg) => console.log(`${DIM}${msg}${RESET}`);

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function copyFile(src, dest, overwrite = true) {
  if (!overwrite && fs.existsSync(dest)) {
    warn(`Skipped ${path.basename(dest)} — already exists (preserving your data)`);
    return false;
  }
  fs.copyFileSync(src, dest);
  return true;
}

function copyDir(src, dest) {
  ensureDir(dest);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(srcPath, destPath);
    else fs.copyFileSync(srcPath, destPath);
  }
}

function isInstalled(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

const AGENTS = {
  bart: {
    file: "bart.md",
    skills: ["agent-browser", "userinterface-wiki"],
    plugins: ["frontend-design", "prototype-feedback"],
  },
  lisa: {
    file: "lisa-discovery.md",
    skills: [],
    plugins: [],
  },
  prince: {
    file: "acceptance-tester.md",
    skills: ["agent-browser"],
    plugins: [],
  },
};

const arg = process.argv[2];
const targets = arg && AGENTS[arg] ? [arg] : Object.keys(AGENTS);

if (arg && !AGENTS[arg] && arg !== "all") {
  console.log(`Unknown agent: ${arg}`);
  console.log(`Usage: npx delivery-agents [bart|lisa|prince]`);
  process.exit(1);
}

console.log(`\n${BOLD}delivery-agents installer${RESET}`);
if (targets.length === 1) {
  console.log(`Installing ${targets[0]}...`);
} else {
  console.log(`Installing Lisa, Bart, and Prince...`);
}

ensureDir(AGENTS_DIR);
ensureDir(LEARNINGS_DIR);
ensureDir(SKILLS_DIR);
ensureDir(PERSONAS_DIR);

// Install agents
header("Agents");
const skillsNeeded = new Set();
const pluginsNeeded = new Set();

for (const name of targets) {
  const agent = AGENTS[name];
  const src = path.join(PKG_DIR, "agents", agent.file);
  const dest = path.join(AGENTS_DIR, agent.file);
  const existed = fs.existsSync(dest);
  copyFile(src, dest, true);
  success(`${agent.file}${existed ? " (updated)" : ""}`);
  agent.skills.forEach((s) => skillsNeeded.add(s));
  agent.plugins.forEach((p) => pluginsNeeded.add(p));
}

// Install learnings starters
header("Learnings");
for (const name of targets) {
  const file = `${name}-learnings.md`;
  const src = path.join(PKG_DIR, "learnings", file);
  const dest = path.join(LEARNINGS_DIR, file);
  if (fs.existsSync(src)) {
    const copied = copyFile(src, dest, false);
    if (copied) success(`${file} (starter)`);
  }
}

// Install skills
if (skillsNeeded.size > 0) {
  header("Skills");
  for (const skill of skillsNeeded) {
    const src = path.join(PKG_DIR, "skills", skill);
    const dest = path.join(SKILLS_DIR, skill);
    if (fs.existsSync(src)) {
      copyDir(src, dest);
      success(`${skill} → ~/.claude/skills/${skill}/`);
    }
  }
}

// Install persona templates
header("Personas");
const personaFiles = fs.readdirSync(path.join(PKG_DIR, "personas"));
for (const file of personaFiles) {
  const src = path.join(PKG_DIR, "personas", file);
  const dest = path.join(PERSONAS_DIR, file);
  const copied = copyFile(src, dest, false);
  if (copied) success(`${file} → ~/.claude/personas/ (fill this in!)`);
}

// Plugin dependencies
if (pluginsNeeded.size > 0) {
  header("Plugin dependencies");
  for (const plugin of pluginsNeeded) {
    warn(`${plugin} — install with: ${CYAN}claude plugin install ${plugin}${RESET}`);
  }
}

// Check agent-browser CLI
header("Dependencies");
if (isInstalled("agent-browser")) {
  success("agent-browser is installed");
} else {
  warn(`agent-browser not found — install with:\n   ${CYAN}npm i -g agent-browser && agent-browser install${RESET}`);
}

// Aliases
header("Terminal aliases");
console.log("Add these to your ~/.zshrc or ~/.bashrc:\n");
for (const name of targets) {
  console.log(`   ${CYAN}alias ${name}='claude --agent ${name} --dangerously-skip-permissions'${RESET}`);
}
console.log(`\nThen reload: ${CYAN}source ~/.zshrc${RESET}\n`);

// Persona reminder
if (targets.includes("lisa")) {
  header("Next step");
  console.log(`Fill in your persona files at ${CYAN}~/.claude/personas/${RESET}`);
  dim("  user-persona.md    — who is your primary user?");
  dim("  product-context.md — what does your product do?\n");
  console.log(`Lisa will find them automatically by matching the user name you type at startup.\n`);
}

header("Done");
console.log("Run agents from your project directory:");
for (const name of targets) {
  const descriptions = { lisa: "discovery research", bart: "UI/UX prototyping", prince: "acceptance testing" };
  console.log(`   ${CYAN}${name}${RESET}  — ${descriptions[name]}`);
}
console.log("");
