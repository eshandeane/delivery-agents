# Delivery Agents

Autonomous AI agents for product and engineering teams. Each agent runs via the Claude CLI and integrates with your connected tools (Circleback, Slack, Gmail, Jira, etc.).

| Agent | What it does | Invoke |
|---|---|---|
| **Lisa** | Discovery research — gathers evidence, surfaces cruxes, writes a structured brief | `/lisa` → `npm run lisa` |
| **Bart** | UI/UX prototyping — builds and iterates on frontend components autonomously | `/bart` → `npm run bart` |
| **Prince** | Acceptance testing — reads a PRD and tests every criterion in the browser | `/prince` → `npm run prince` |

---

## Install

```bash
git clone https://github.com/eshandeane/delivery-agents
cd delivery-agents
bash install.sh
```

The installer will ask which project to install into, then:
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

## Agents

### Lisa — Discovery Research

Gathers evidence from Circleback, Slack, Gmail, and the web. Synthesizes themes, surfaces cruxes, and writes a structured discovery brief. Improves across runs via topic-scoped learnings.

```bash
/lisa          # generate a brief (in Claude Code)
npm run lisa   # run the research
/lisa status   # see the last run's output
```

→ [Full documentation](lisa/README.md)

---

### Bart — UI/UX Prototyping

Takes a design brief and autonomously builds, reviews, and iterates on frontend components. Works in a dedicated git branch and uses the browser to verify its own work.

```bash
/bart          # generate a design brief (in Claude Code)
npm run bart   # run the prototyping loop
```

---

### Prince — Acceptance Testing

Reads a PRD, spins up a test environment, drives the browser through every acceptance criterion, and produces a pass/fail report with screenshots. Drafts a product announcement if all criteria pass.

```bash
/prince                               # find the PRD (in Claude Code)
npm run prince -- ralph/tasks/prd.md  # run acceptance tests
```

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

---

## Output files

All agents write to your project's `outputs/` directory:

```
outputs/
├── lisa/
│   └── brief.json               # current Lisa research brief
├── lisa-progress.log            # live progress (tail -f this)
├── discovery/
│   └── <slug>-<date>.md         # Lisa discovery docs
├── bart/
│   ├── design-brief.json        # current Bart design brief
│   ├── bart-progress.log        # live progress
│   └── screenshots/             # Bart's browser screenshots
└── acceptance-tests/
    └── <feature>-<date>/        # Prince test reports + screenshots
        ├── report.md
        └── screenshots/
```

---

## Connected tools

Agents use whatever MCPs you have connected in Claude Code. The more you connect, the richer the output.

| Tool | Used by | What it provides |
|---|---|---|
| Circleback | Lisa | Meeting transcripts — primary user voice |
| Slack | Lisa | Team conversations, decisions, context |
| Gmail | Lisa | Email threads |
| Confluence | Lisa | Internal docs and wiki |
| Slack | Prince | Test result notifications |

Connect MCPs in Claude Code with `/connect-mcps connect to <tool>`.
