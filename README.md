# Delivery Agents

Autonomous AI agents for product and engineering teams. Each one runs via the Claude CLI and integrates with your connected MCPs (Circleback, Slack, Gmail, Jira, etc.).

The pipeline runs: **Homer → Lisa → (you decide) → Marge → Bart → Prince**.

> **Heads up:** This repo is the original public-facing home for these agents. The actively-maintained versions of all five — including **Homer** and **Marge**, which were added after this repo was first published — now live in the private `pm-os` repo. The descriptions here reflect the current behavior; the code in `lisa/`, `bart/`, and `prince/` is the snapshot at the time of last sync.

| Agent | Role | How it's triggered | Loop? |
|---|---|---|---|
| **Homer** | Orchestrator — scans Jira Roadmap + Design tickets, judges readiness, triggers Lisa or Bart | `/homer` in Claude Code, or scheduled via launchd 3×/day (08:00, 12:00, 16:00) | Outer schedule loop + per-ticket eval loop |
| **Lisa** | Discovery research — synthesizes the pain point from Circleback, Slack, and Gmail into a structured discovery brief | `/lisa` → `npm run lisa`, or called by Homer | One-shot per brief |
| **Marge** | PRD writing — turns an approved discovery doc + your solution decision into a PRD | `/marge` → `npm run marge` | One-shot |
| **Bart** | UI/UX prototyping — builds, reviews, and iterates on frontend components in a dedicated git worktree | `/bart` → `npm run bart`, or called by Homer with `--ticket FDE-XXX` | **Internal loop, up to 15 iterations** |
| **Prince** | Acceptance testing — reads a PRD, drives the browser through every criterion, produces a pass/fail report | `/prince` → `npm run prince -- path/to/prd.md` | Auto-fix loop on failure |

---

## Install

```bash
git clone https://github.com/eshandeane/delivery-agents
cd delivery-agents
bash install.sh
```

The installer asks which project to install into, then:
- Copies Claude skills to `<project>/.claude/skills/`
- Adds `npm run lisa`, `npm run bart`, `npm run prince` to `package.json`
- Creates output directories

**Requirements:**
- [Claude Code CLI](https://claude.ai/download) — `claude` must be in your PATH
- `jq` — `brew install jq`

**Non-interactive install:**
```bash
bash install.sh --project /path/to/your/project
```

---

## Agents in detail

### Homer — Orchestrator

The PM delivery agent. Homer is the only agent that runs unattended on a schedule.

**What it does:**
1. Pulls all FDE Jira tickets assigned to you in `Roadmap` and `Design` status.
2. For each `Roadmap` ticket: searches Circleback, Slack, and Gmail for real signal on the pain point. If three criteria pass (clear pain, named user, real signal), Homer triggers Lisa. Otherwise, Homer comments on the ticket with exactly what's missing.
3. For each `Design` ticket: checks for a `design-brief.json` attachment. If found, Homer triggers Bart in worktree mode. Otherwise, Homer comments asking for a brief.
4. Posts every decision back to the Jira ticket as a comment (rendered via direct ADF POST to the Jira REST API — the MCP's plain-text comment tool mangles markdown).

**Invariant:** Homer **never** transitions Jira ticket status. Every status change is yours. Comments are the audit trail.

**Schedule:** `~/Library/LaunchAgents/com.cutanddry.homer.plist` — fires at 08:00, 12:00, 16:00.

---

### Lisa — Discovery Research

Gathers evidence from Circleback, Slack, Gmail, and the web. Synthesizes themes, surfaces cruxes, and writes a structured discovery doc to `outputs/discovery/`. Improves across runs via topic-scoped learnings.

```bash
/lisa          # generate a brief (in Claude Code)
npm run lisa   # run the research
/lisa status   # see the last run's output
```

Lisa is most often invoked by Homer after Homer judges that a Roadmap ticket has enough signal. You can also write a brief manually via `/lisa` and run `npm run lisa` directly.

---

### Marge — PRD Writing

Takes an approved discovery doc plus your solution decision and writes a full PRD. Asks clarifying questions first if anything is ambiguous, then drafts the PRD, runs a self-review skill against it, and updates based on the feedback.

```bash
/marge                              # generate a brief (in Claude Code)
npm run marge -- --feature <slug>   # write the PRD
```

One-shot per run; no iteration loop.

---

### Bart — UI/UX Prototyping

Takes a `design-brief.json` and autonomously builds, reviews, and iterates on frontend components. Works in a dedicated git worktree and uses the browser to verify its own work.

```bash
/bart          # generate a design brief (in Claude Code)
npm run bart   # run the prototyping loop
```

**The loop (`bart.sh:174`):**
- For up to **15 iterations**:
  1. Pick the next incomplete, non-blocked design task from the brief (sorted by priority).
  2. Spawn a fresh `claude --model sonnet` session with the task + phase + accumulated `bart-learnings.md` as context.
  3. Run the phase (build, review, or fix), tail `bart-progress.log` for live output.
  4. Check the output for a `<promise>COMPLETE</promise>` sentinel.
     - **Found** → all tasks done, push the branch, post a "Bart is done" Jira comment, exit.
     - **Not found** → mark the phase done in the brief, pick up the next phase, loop.
- Each iteration is a brand-new Claude session. Cross-iteration memory lives in `bart-learnings.md`. Tasks can self-mark `phase: "blocked"` to drop out of the queue.

**Ticket mode** (when called by Homer with `--ticket FDE-XXX`):
- Creates a worktree at `<repo>--worktrees/bart-<ticket>` on the branch named in the brief.
- On completion: `git push -u origin <branch>` + "Bart is done" comment to the Jira ticket. No PR is raised — you open one when you're ready to ship.

---

### Prince — Acceptance Testing

Reads a PRD, spins up a test environment (Docker DB), drives the browser through every acceptance criterion via Playwright, and produces a pass/fail report with screenshots. Drafts a product announcement if all criteria pass.

```bash
/prince                               # find the PRD (in Claude Code)
npm run prince -- ralph/tasks/prd.md  # run acceptance tests
```

On FAIL, Prince enters an auto-fix loop: it reads the failure, attempts a fix, re-runs the criterion, and re-evaluates. Repeats until pass or it gives up and flags the criterion for human review.

---

## How agents are structured

Each agent has the same layout:

```
<agent>/
├── README.md     # documentation
├── CLAUDE.md     # the agent's full instructions (prompt)
├── <agent>.sh    # shell script — invokes Claude CLI
└── skill/
    └── SKILL.md  # Claude Code skill for generating the input brief
```

The shell script passes `CLAUDE.md` as the system prompt to `claude --print`, which runs the agent autonomously without opening a UI. Progress is streamed to a log file you can tail in a second terminal.

Two agents — Homer and Lisa — also ship a `launchd` plist for scheduled or polling execution on macOS.

---

## Output files

All agents write to your project's `outputs/` directory:

```
outputs/
├── lisa/
│   ├── brief.json                  # current Lisa research brief
│   └── briefs/<slug>-<date>.json   # archive
├── discovery/
│   └── <slug>-<date>.md            # Lisa discovery docs
├── bart/
│   ├── design-brief.json           # current Bart design brief
│   ├── bart-progress.log           # live progress
│   ├── bart-learnings.md           # cross-iteration memory
│   └── screenshots/                # Bart's browser screenshots
├── marge/
│   └── <feature>-prd.md            # Marge's PRD draft
├── acceptance-tests/
│   └── <feature>-<date>/           # Prince test reports + screenshots
│       ├── report.md
│       └── screenshots/
└── homer-runs.log                  # Homer's scheduled run log
```

---

## Connected tools

Agents use whatever MCPs you have connected in Claude Code. The more you connect, the richer the output.

| Tool | Used by | What it provides |
|---|---|---|
| Jira (Atlassian) | Homer | Roadmap + Design ticket queue, comment audit trail |
| Circleback | Homer, Lisa | Meeting transcripts — primary user voice |
| Slack | Homer, Lisa, Prince | Team conversations, decisions, test notifications |
| Gmail | Homer, Lisa | Email threads |
| Confluence | Lisa | Internal docs and wiki |
| Playwright | Bart, Prince | Browser automation for build + verify |

Connect MCPs in Claude Code with `/connect-mcps connect to <tool>`.
