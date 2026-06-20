# Delivery Agents

Autonomous AI agents for product and engineering teams. Each one runs via the Claude CLI and integrates with your connected MCPs (Circleback, Slack, Gmail, Jira, etc.).

The pipeline runs: **Homer → Lisa → (you decide) → Marge → Bart → Prince**.

> **Heads up:** This repo is the original public-facing home for these agents. The actively-maintained versions of all five — including **Homer** and **Marge**, which were added after this repo was first published — now live in the private `pm-os` repo. The descriptions here reflect the current behavior; the code in `lisa/`, `bart/`, and `prince/` is the snapshot at the time of last sync.

| Agent | Role | How it's triggered | Loop? |
|---|---|---|---|
| **Homer** | Orchestrator — scans Jira Roadmap + Design tickets, judges readiness, triggers Lisa or Bart | `/homer` in Claude Code, or scheduled via launchd 3×/day (08:00, 12:00, 16:00) | Outer schedule loop + per-ticket eval loop |
| **Lisa** | Discovery research — synthesizes the pain point from Circleback, Slack, and Gmail into a structured discovery brief | `/lisa` → `npm run lisa`, or called by Homer | One-shot per brief |
| **Marge** | PRD writing — turns an approved discovery doc + your solution decision into a PRD, then pressure-tests it via a 7-perspective review panel | `/marge` → `npm run marge` | Up to 2 review/revise cycles |
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

Takes an approved discovery doc plus your solution decision and writes a full PRD, then pressure-tests it through a 7-perspective review panel.

```bash
/marge                              # generate a brief (in Claude Code)
npm run marge -- --feature <slug>   # write the PRD
```

**The flow:**
1. Invokes the `/prd` skill to draft the PRD, feeding it the solution decision plus any Lisa / Bart context.
2. Invokes the `/prd-review-panel` skill on the draft. The panel runs 7 reviewers in parallel — engineering, design, exec, legal, UXR, skeptic, customer voice — and returns a consolidated list of must-fix issues and suggestions.
3. Resolves every must-fix issue inline, then re-runs the panel. **Maximum 2 revision cycles.** Anything still unresolved after cycle 2 is logged in an `## Open Questions` section and the PRD ships anyway.
4. Suggestions (non-blocking) are appended at the bottom of the PRD under `## Panel Suggestions (Deferred)`.

The review panel is what makes Marge worth running over a stock PRD generator — Eshan's 7 sub-agents catch class-of-issue gaps that any single reviewer would miss.

---

### Bart — UI/UX Prototyping

Takes a `design-brief.json` and autonomously builds, reviews, and iterates on frontend components. Works in a dedicated git worktree and uses the browser to verify its own work.

```bash
/bart          # generate a design brief (in Claude Code)
npm run bart   # run the prototyping loop
```

**The loop (`bart.sh:174`):**

For up to **15 iterations**, Bart picks the next incomplete, non-blocked design task from the brief and runs one phase against it in a fresh Claude session.

**Each task moves through these phases:**
1. **`build`** — Before writing code, Bart invokes the `/frontend-design` and `/userinterface-wiki` skills for design-quality guidance and UI rules. Then it builds, verifies in the browser via `/agent-browser`, and moves the task to `review`.
2. **`review`** — Bart scores the UI across 5 dimensions, **each requiring a concrete browser action before the score is assigned**:
   - **Visual clarity** — take a screenshot, evaluate layout / hierarchy / scannability.
   - **Interaction** — drive the actual interaction in the browser.
   - **Consistency** — compare against the FDE Design System checklist.
   - **Accessibility** — keyboard nav, ARIA, contrast.
   - **Responsive** — resize the viewport.

   Scores are 1–5 per dimension. All scores ≥4 AND every checklist item passes → `phase: done`. Any score ≤3 → `phase: iterate` with specific fixes listed.
3. **`iterate`** — Read the `## Fixes Needed` from the last review entry, re-invoke `/userinterface-wiki` for the dimensions that scored low, apply the fixes, then back to `review`. If the same dimension scores ≤3 across 2+ consecutive reviews, Bart marks it as a recurring blocker rather than retrying the same fix.
4. **`done`** or **`blocked`** — Done when scores pass; blocked after 10+ review/iterate cycles on the same task without passing.

Cross-iteration memory lives in `bart-learnings.md`. The outer loop exits early when the brief signals `<promise>COMPLETE</promise>`.

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
