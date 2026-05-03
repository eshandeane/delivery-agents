---
name: lisa
description: "Generate a research brief for the Lisa discovery agent. Use when you want Lisa to run a full discovery research run. Triggers on: /lisa, run lisa, research this, discovery brief."
user-invocable: true
---

# Lisa Brief Generator

Lisa is the autonomous discovery research agent. This skill creates the `outputs/lisa/brief.json` it needs to run, then tells you how to launch it.

---

## On Every Run: Load Agent Memory

Before anything else, silently read `~/.claude/agents/learnings/lisa/meta.md` if it exists. Use it to:

- Recommend sources intelligently rather than asking open-ended (e.g. if meta says circleback is strong for DTM topics, lead with that)
- Shape how you ask questions (e.g. if narrow briefs with strong hypotheses consistently score better, push for specificity)
- Surface relevant cross-topic patterns when they apply

Do not show this file to the user.

---

## Status Check

If the user's message is "status", "lisa status", or just wants to see the last run:

```bash
cat outputs/lisa/brief.json 2>/dev/null
ls -t outputs/discovery/*.md 2>/dev/null | head -1
```

Print a readable summary:

```
Last brief:   [painPoint] ([createdAt])
Last run doc: [path to most recent discovery doc]
```

Read the most recent discovery doc and extract:

- The TL;DR cruxes (top 3)
- Overall confidence
- Recommended next action

Print them cleanly.

**Then check if findings have been written back to per-topic memory.** Derive the slug from the last brief's `painPoint` and check whether `~/.claude/agents/learnings/lisa/<slug>.md` contains a `## Findings` section dated today or after the discovery doc's date. If not, extract the key findings from the discovery doc and append them now:

```markdown
## Findings: [date]

- **Cruxes:** [top 3 findings]
- **Hypothesis result:** [validated / invalidated / inconclusive]
- **Ruled out (new):** [anything the research settled that should carry forward]
- **Confidence:** [high / medium / low]
```

Do this silently without asking. Then end with: "Run `/lisa` to start a new research run."

---

## Step 1: Search Prior Work for Topic Overlap

Scan for prior runs on the same or related topic:

```bash
ls outputs/lisa/briefs/ 2>/dev/null        # archived briefs
ls outputs/discovery/ 2>/dev/null          # discovery docs
ls ~/.claude/agents/learnings/lisa/ 2>/dev/null  # per-topic learnings
```

If the user's opening message already names a topic, fuzzy-match against archived brief filenames, discovery doc filenames, and learnings slugs. If you find a match:

1. Read the matching per-topic learnings file (findings + feedback) and the most recent matching discovery doc
2. Show a compact summary:
   ```
   Found prior work on "[topic]":
   - [doc filename] ([date])
   - Key findings: [2-3 cruxes]
   - Hypothesis was: [validated / invalidated / inconclusive]
   - What's ruled out: [alreadyRuledOut from findings]
   ```
3. Ask: "Build on this, extend it in a new direction, or start fresh?"
   - **Build on**: carry hypothesis, alreadyRuledOut, and sources forward. Only ask about what's genuinely changed.
   - **Extend**: same topic, new angle or decision. Carry alreadyRuledOut silently, ask fresh about decision, hypothesis, and scope.
   - **Start fresh**: clean slate — but carry alreadyRuledOut forward silently. No point re-investigating settled ground.

If no prior work found, skip to Step 2.

If prior brief exists on a _different_ topic, note it one line ("Last brief was on [topic]") then proceed to Step 2.

---

## Step 2: Collect the Brief One Question at a Time

Ask each question one at a time. Wait for the answer. Never ask two questions in one message. Skip any already answered from prior work or the user's opening message.

1. "Who is the target user?" _(e.g. FDE, customer admin, distributor exec)_
2. "What's the pain point or feature?" _(be as concrete as possible)_
3. "What decision does this inform?" _(e.g. Q2 vs Q3, build vs buy, MVP scope)_
4. "What do you already believe is true? I'll stress-test this, not just confirm it." _(optional — null if skipped)_
5. "Anything already ruled out or investigated that Lisa should skip?" _(optional — null if nothing)_
6. "Full discovery or a narrow question?" _(full = open-ended; narrow = specific question. Default: full)_
7. Recommend sources based on meta.md — don't ask open-ended. Say: "Based on past runs, I'd route this to [sources] — change anything?" If no prior signal, default to all connected and say so.

---

## Step 3: Generate the Brief

Create `outputs/lisa/brief.json`:

```json
{
  "targetUser": "<role/persona>",
  "painPoint": "<the specific user problem or feature idea>",
  "decision": "<the specific call this informs>",
  "hypothesis": "<I believe... — or null>",
  "alreadyRuledOut": "<what's settled — or null>",
  "scope": "<full|narrow>",
  "prioritySources": ["circleback", "slack", "web"],
  "createdAt": "<YYYY-MM-DD>"
}
```

```bash
mkdir -p outputs/lisa outputs/lisa/briefs
```

---

## Step 4: Show the Brief and Confirm

Print a readable summary:

```
Target user:       <targetUser>
Pain point:        <painPoint>
Decision:          <decision>
Hypothesis:        <hypothesis or "none">
Already ruled out: <alreadyRuledOut or "nothing">
Scope:             <full|narrow>
Sources:           <prioritySources>
```

Ask: "Does this look right? I'll save the brief once you confirm, then you can run `npm run lisa` to kick off the research."

---

## Step 5: Save, Archive, Update Memory, and Launch

Once confirmed:

1. **Archive the brief** before overwriting:

   ```bash
   SLUG=$(echo "<painPoint>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-50)
   cp outputs/lisa/brief.json outputs/lisa/briefs/$SLUG-<YYYY-MM-DD>.json 2>/dev/null || true
   ```

2. **Save** `outputs/lisa/brief.json`.

3. **Append to per-topic learnings:**

   ```bash
   mkdir -p ~/.claude/agents/learnings/lisa
   ```

   ```markdown
   ## Brief: [date]

   - **Decision:** [decision]
   - **Scope:** [full|narrow]
   - **Hypothesis:** [hypothesis or none]
   - **Sources:** [prioritySources]
   - **Mode:** [build-on | extend | fresh]
   ```

4. **Append to meta.md:**

   ```markdown
   ## [date] — [targetUser] / [slug]

   - Scope: [full|narrow]
   - Sources routed: [prioritySources] — [recommended by meta vs user-changed]
   - Hypothesis quality: [strong / weak / none]
   - Mode: [build-on | extend | fresh]
   - Note: [one sentence — e.g. "extend run; carried ruling-out from prior growth-dashboard brief"]
   ```

5. Tell the user:
   > "Brief saved. Archived to `outputs/lisa/briefs/[slug]-[date].json`.
   >
   > Run this to start Lisa:
   >
   > ```
   > npm run lisa
   > ```
   >
   > Tail `outputs/lisa-progress.log` to watch progress."

---

## Step 6: Post-Run Feedback (when the PM returns after a run)

If the user comes back and mentions the run finished, or shares feedback on the output:

Ask: "Was the research useful?" Accept: useful / wrong focus / too thin / partially / skip.

If the rating is anything other than "useful", ask one follow-up: "What specifically was off — the hypothesis, the sources, or the scope?"

Save both to the per-topic learnings file:

```markdown
## PM Feedback: [date]

- **Rating:** [useful | wrong focus | too thin | partially]
- **What was off:** [hypothesis | sources | scope | n/a]
- **Notes:** [anything the PM added]
```

Then update meta.md with a one-line pattern observation so future briefs on similar topics route better.
