# delivery-agents

Three Claude Code agents for the full PM-to-shipped-feature cycle.

```
Lisa (Discovery) → Bart (Prototyping) → Prince (Acceptance Testing)
```

## Install

```bash
npx delivery-agents
```

That's it. The installer copies the agents into `~/.claude/agents/`, sets up starter learnings files, and prints the shell aliases to add.

## The Agents

| Agent | Model | Role |
|-------|-------|------|
| **Lisa** | sonnet | Autonomous researcn — asks 3 questions, loads your user persona, then runs full research: JTBD framing, fetch meetings, email, Slack for signals, codebase exploration, web and competitor research, Outputs a structured research doc for PM to review.
| **Bart** | sonnet | UI/UX prototyping — builds, reviews, and iterates on frontend prototypes until every dimension scores 4+/5 |
| **Prince** | sonnet | Acceptance testing — spins up an isolated test environment, tests every UI-testable criterion from the PRD, and outputs a structured pass/fail report |

## Usage

Run agents from your project directory:

```bash
bart    # reads outputs/bart/design-brief.json and starts prototyping
lisa    # reads the discovery brief and starts research
prince  # finds the PRD, spins up test env, runs acceptance tests
```

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- [agent-browser](https://www.npmjs.com/package/agent-browser) for browser automation (`npm i -g agent-browser && agent-browser install`)
- Docker — Prince uses a Docker postgres for isolated test environments
- Node.js 18+

## Project setup for Prince

Prince expects your project to have:

- `docker-compose.test.yml` — test postgres config
- `prisma/seed.e2e.ts` — E2E seed script
- Test DB at `postgresql://test:test@localhost:5433/fde_test`
- PRD files in `ralph/tasks/`, `docs/prd/`, or the project root

Bart expects:

- Design brief at `outputs/bart/design-brief.json`
- `/frontend-design`, `/userinterface-wiki`, and `/prototype-feedback` skills in `.claude/skills/`
- Tasks that exceed 10 review/iterate cycles without hitting 4+/5 on all dimensions are automatically marked `blocked` and flagged in the final summary for human review

## Learnings

Each agent accumulates learnings across runs in `~/.claude/agents/learnings/`. Starter files are created on install and never overwritten — your data is preserved across reinstalls and updates.

## Manual install

If you prefer not to use npx:

```bash
git clone https://github.com/eshandeane/delivery-agents
cd delivery-agents
node bin/install.js
```
