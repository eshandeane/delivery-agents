# Lisa — Discovery Research Agent

Lisa is an autonomous research agent for product managers. She gathers evidence from your connected tools, synthesizes the problem, and surfaces the questions that matter — so you spend your time deciding instead of digging.

**Lisa synthesizes the problem. She does not recommend the solution.**

---

## How it works

```
/lisa  →  brief.json  →  npm run lisa  →  outputs/discovery/<doc>.md  →  #clawd
```

1. **`/lisa`** in Claude Code — collects a structured research brief through a short conversation (7 questions, one at a time)
2. **`npm run lisa`** in your terminal — runs Lisa autonomously against your connected tools
3. **Discovery doc** — saved to `outputs/discovery/<slug>-<date>.md`
4. **Slack notification** — posted to `#clawd` when the run starts and when it completes

---

## Quick start

```bash
# Step 1: Generate a brief (in Claude Code)
/lisa

# Step 2: Run Lisa (in your terminal)
npm run lisa

# Step 3: Watch progress in a second terminal
tail -f outputs/lisa-progress.log
```

---

## The brief

Lisa reads from `outputs/lisa/brief.json` before every run. The `/lisa` skill generates this for you — don't edit it by hand.

| Field | Required | Description |
|---|---|---|
| `targetUser` | Yes | Who this research is for (e.g. FDE, distributor exec) |
| `painPoint` | Yes | The specific user problem or feature idea |
| `decision` | Yes | What specific call this informs (e.g. Q2 vs Q3, build vs buy) |
| `hypothesis` | No | What you already believe — Lisa stress-tests this, doesn't confirm it |
| `alreadyRuledOut` | No | What's already decided — Lisa skips re-researching it |
| `scope` | No | `full` (default) or `narrow` |
| `prioritySources` | No | Which sources to focus on: `circleback`, `slack`, `email`, `web` |

Briefs older than 2 days trigger a warning before the run starts.

---

## What Lisa researches

Lisa runs up to 16 phases in a single autonomous invocation:

| Phase | What happens |
|---|---|
| 0 | Load brief, prior learnings, PM feedback, prior runs on this topic |
| 1 | Extract search keywords from the brief + hypothesis |
| 2 | **MCP evidence gathering** — Circleback, Slack, Gmail, Confluence |
| Planning checkpoint | Assess evidence volume, evaluate hypothesis, revise keywords, build phase plan |
| 3 | Web + competitor research |
| 4 | Codebase exploration |
| 5 | JTBD candidate framings (derived from evidence) |
| 6 | Stakeholder alignment |
| 7 | Workaround analysis |
| 8 | Themes & gaps (with confidence counts) |
| 9 | Cruxes — questions that would change the decision |
| 10 | Risk assessment |
| 11 | Metrics mentioned in evidence |
| 12 | Solution space research |
| 13 | Validation options |
| 14 | Write discovery doc |
| 15 | Self-improvement log |
| 16 | Post summary to Slack #clawd |

For a **narrow run**, phases 6, 10, 12, and 13 are skipped.

---

## The output doc

Saved to `outputs/discovery/<slug>-<date>.md`. Structured so the most actionable content comes first:

1. **TL;DR** — top cruxes, confidence, recommended next action. ⚠️ hypothesis challenge callout if evidence contradicts the brief.
2. **Cruxes** — the 3–5 questions that would change your decision
3. **Validation options** — one concrete way to resolve each crux
4. **Themes & gaps** — recurring patterns with confidence signals (N sources)
5. **JTBD framings** — candidate jobs-to-be-done derived from evidence
6. **Stakeholder alignment** — champion, who raised it, urgency driver
7. **Workaround analysis** — what users do today and at what cost
8. **Metrics in evidence** — every KPI mentioned across sources
9. **Technical context** — related code, complexity estimate
10. **Solution space** — external patterns (with URLs), internal prior art, prior decisions
11. **Risk assessment** — technical, adoption, data, rollback
12. **Diff from prior run** — what changed since the last brief on this topic
13. **Suggested next actions** — named, concrete, not generic
14. **Sources referenced** — every MCP queried, every URL fetched
15. **Feedback** — fill this in after using the brief; Lisa reads it next time

---

## Slash commands

| Command | What it does |
|---|---|
| `/lisa` | Start a new research brief (7 questions, one at a time) |
| `/lisa status` | Show the last brief + top cruxes from the last run |

---

## Memory & learning

Learnings are **topic-scoped** — each topic gets its own file, derived from the `painPoint` slug. Lisa only loads learnings relevant to the current research topic, not everything she's ever learned.

```
~/.claude/agents/learnings/lisa/
├── growth-dashboard-adoption.md   # learnings for this topic only
├── onboarding-flow.md             # completely separate
└── ...
```

Each topic file accumulates two types of entries over time:

| Entry type | Written by | When |
|---|---|---|
| Self-assessment | Lisa | End of every run (Phase 15) |
| PM feedback | You (via `/lisa`) | When re-triggering a run on the same topic |

**What each entry contains:**
- Best/weakest source for this topic
- Keywords that worked vs returned noise
- One concrete improvement for next run
- Hypothesis outcome (on track / challenged / unclear)
- PM rating + notes (if provided)

At Phase 0, Lisa loads the topic file and applies it concretely:
- "Wrong focus" → rethinks keyword strategy before Phase 1
- "Too thin" → runs more keyword variants in Phase 2
- "Hypothesis call was wrong" → skeptical of confirming signals at the planning checkpoint
- "What was missing" → adds those topics to Phase 1 keywords explicitly

---

## Files

```
lisa/
├── README.md        # this file
├── CLAUDE.md        # Lisa's full instructions (the agent prompt)
└── lisa.sh          # shell script that runs Lisa via Claude CLI
```

Output files (in the project):
```
outputs/
├── lisa/
│   └── brief.json            # current research brief
├── lisa-progress.log         # live progress (tail -f this while running)
└── discovery/
    └── <slug>-<date>.md      # discovery docs
```
