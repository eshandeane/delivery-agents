---
name: lisa
description: "Generate a research brief for the Lisa discovery agent. Use when you want Lisa to run a full discovery research run. Triggers on: /lisa, run lisa, research this, discovery brief."
user-invocable: true
---

# Lisa Brief Generator

Lisa is the autonomous discovery research agent. This skill creates the `outputs/lisa/brief.json` it needs to run, then tells you how to launch it.

---

## Status Check

If the user's message is "status", "lisa status", or just wants to see the last run — show this instead of collecting a new brief:

```bash
# Last brief
cat outputs/lisa/brief.json 2>/dev/null

# Last discovery doc
ls -t outputs/discovery/*.md 2>/dev/null | head -1
```

Print a readable summary:
```
Last brief:   [painPoint] ([createdAt])
Last run doc: [path to most recent discovery doc]
```

Then read the most recent discovery doc and extract:
- The TL;DR cruxes (top 3)
- Overall confidence
- Recommended next action

Print them cleanly. Do not regenerate or re-run anything. End with: "Run `/lisa` to start a new research run."

---

## Step 1: Check for Prior Brief and Ask for Feedback

Before collecting a new brief, check whether a prior brief and discovery doc exist on the same or similar topic.

```bash
ls outputs/lisa/brief.json 2>/dev/null && cat outputs/lisa/brief.json
ls outputs/discovery/ 2>/dev/null | tail -5
```

If a prior brief exists:
- Show a one-line summary: "Last brief: [discoveryGoal] — [createdAt]"
- Ask: "Was that brief useful?" and wait for the answer
- Accept any response: useful / wrong focus / too thin / partially / skip

Save the feedback to the topic-scoped learnings file. Derive the slug from the prior brief's `painPoint`:

```bash
TOPIC_SLUG=$(echo "<painPoint>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-50)
LEARNINGS_FILE="~/.claude/agents/learnings/lisa/$TOPIC_SLUG.md"
```

Append to that file:

```markdown
## PM Feedback: [date]
- **Rating:** [useful | wrong focus | too thin | partially]
- **Notes:** [anything the PM added]
```

If no prior brief exists, skip this step entirely and go straight to Step 2.

---

## Step 2: Collect the Brief One Question at a Time

Ask each question one at a time. Wait for the answer before asking the next. Never ask two questions in the same message.

Work through these in order:

1. "Who is the target user?" *(e.g. FDE, customer admin, distributor exec)*
2. "What's the pain point or feature?" *(the specific user problem or feature idea to research — be as concrete as possible)*
3. "What decision does this inform?" *(e.g. Q2 vs Q3, build vs buy, MVP scope)*
4. "What do you already believe is true? I'll stress-test this, not just confirm it." *(optional — if they say "not sure" or skip, set hypothesis to null)*
5. "Anything already ruled out or investigated that Lisa should skip?" *(optional — if nothing, set to null)*
6. "Full discovery or a narrow question?" *(full = open-ended, unknown solution space; narrow = specific question, one source probably enough. Default: full)*
7. "Any sources to prioritize? e.g. circleback, slack, web" *(optional — if not specified, default to all connected)*

If the user's opening message already answers some of these, skip those questions and start from the first unanswered one.

---

## Step 3: Generate the Brief

Create `outputs/lisa/brief.json`:

```json
{
  "targetUser": "<role/persona>",
  "painPoint": "<the specific user problem or feature idea>",
  "decision": "<the specific call this informs>",
  "hypothesis": "<I believe... — or null if not provided>",
  "alreadyRuledOut": "<what's already settled — or null if not provided>",
  "scope": "<full|narrow>",
  "prioritySources": ["circleback", "slack", "web"],
  "createdAt": "<YYYY-MM-DD>"
}
```

Also create the output directory:

```bash
mkdir -p outputs/lisa
```

---

## Step 4: Show the Brief and Confirm

Print a readable summary:

```
Target user:     <targetUser>
Goal:            <discoveryGoal>
Decision:        <decision>
Hypothesis:      <hypothesis or "none provided">
Already ruled out: <alreadyRuledOut or "nothing specified">
Scope:           <full|narrow>
Sources:         <prioritySources>
```

Ask: "Does this look right? I'll save the brief once you confirm, then you can run `npm run lisa` to kick off the research."

---

## Step 5: Save and Launch

Once confirmed, save the brief file and tell the user:

> "Brief saved to `outputs/lisa/brief.json`. Run this in your terminal to start Lisa:
> ```
> npm run lisa
> ```
> Tail `outputs/lisa-progress.log` in a second terminal to watch progress as it runs."
