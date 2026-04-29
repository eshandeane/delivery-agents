# delivery-agents

Three Claude Code agents that handle the full PM-to-shipped-feature cycle. Drop the agent files into `~/.claude/agents/` and invoke them from the terminal.

## The Squad

| Agent | File | Model | Role |
|-------|------|-------|------|
| **Lisa** | `lisa-discovery.md` | opus | Autonomous discovery — researches the problem space, synthesizes user research, competitive intel, and analytics into a structured brief |
| **Bart** | `bart.md` | sonnet | UI/UX prototyping — builds, reviews, and iterates on frontend prototypes until every dimension scores 4+/5 |
| **Prince** | `acceptance-tester.md` | sonnet | Acceptance testing — spins up an isolated test environment, tests every UI-testable criterion from the PRD, records failures, and writes a structured report |

## How They Work Together

```
Lisa (Discovery) → Bart (Prototyping) → Prince (Acceptance Testing)
```

1. **Lisa** reads a design brief or problem statement and produces a structured research output — user pain points, competitive landscape, recommended approach.
2. **Bart** reads Lisa's output (or a design brief directly) and builds a working frontend prototype. Iterates until quality is excellent, not just good enough.
3. **Prince** reads the PRD acceptance criteria, spins up a Docker test DB, drives the browser with `agent-browser`, and outputs a pass/fail report per criterion.

## Setup

### 1. Install the agents

```bash
cp bart.md lisa-discovery.md acceptance-tester.md ~/.claude/agents/
cp learnings/*.md ~/.claude/agents/learnings/
```

### 2. Add terminal aliases

Add to your `~/.zshrc`:

```bash
alias bart='claude --agent bart --dangerously-skip-permissions'
alias lisa='claude --agent lisa --dangerously-skip-permissions'
alias prince='claude --agent prince --dangerously-skip-permissions'
```

Then reload:

```bash
source ~/.zshrc
```

### 3. Install agent-browser

All three agents use `agent-browser` for browser automation (no Playwright required):

```bash
npm i -g agent-browser && agent-browser install
```

## Usage

Each agent is invoked from the terminal in your project directory:

```bash
bart    # starts Bart — reads outputs/bart/design-brief.json and begins prototyping
lisa    # starts Lisa — reads the discovery brief and begins research
prince  # starts Prince — finds the PRD, spins up test env, runs acceptance tests
```

## Learnings

Each agent accumulates learnings across runs in `~/.claude/agents/learnings/`:

- `bart-learnings.md` — design patterns, scoring calibration, component insights
- `lisa-learnings.md` — research patterns, source quality, synthesis approaches
- `prince-learnings.md` — testing edge cases, environment notes, selector patterns

These are read at the start of every run so each agent gets better over time.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- [agent-browser](https://www.npmjs.com/package/agent-browser) (`npm i -g agent-browser`)
- Docker (Prince uses a Docker postgres for isolated test environments)
- `gh` CLI (for Prince's runtime fix commits)
