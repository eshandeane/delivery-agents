---
name: marge
description: "Generate a PRD brief for the Marge agent. Use after Bart's design is approved and you've decided on a solution. Triggers on: /marge, run marge, write the prd, marge brief."
user-invocable: true
---

# Marge Brief Generator

Marge is the autonomous PRD writing agent. She reads Lisa's discovery output and Bart's approved design, writes a pressure-tested PRD, and produces `ralph/prd.json`. This skill creates the brief she needs, then tells you how to launch her.

---

## Step 1: Check Prerequisites

Before asking anything, verify the required inputs exist:

```bash
ls outputs/discovery/ 2>/dev/null | tail -5
ls outputs/bart/design-brief.json 2>/dev/null && echo "Bart brief found" || echo "No Bart brief"
```

If Bart's design brief is missing, stop and tell the user:
> "Bart's design brief not found at `outputs/bart/design-brief.json`. Run Bart first before running Marge."

If no Lisa discovery doc exists, warn but don't block:
> "No Lisa discovery docs found in `outputs/discovery/`. Marge can still write the PRD but it will be weaker without research context. Continue? (y/N)"

---

## Step 2: Collect the Brief — One Question at a Time

Ask each question one at a time. Wait for the answer before asking the next.

1. "What's the feature name?" _(short, descriptive — will be used in the PRD title and file name)_

2. Show the most recent Lisa discovery doc found and ask: "Is this the right Lisa discovery doc, or a different one?"
   - Show the path: `outputs/discovery/<filename>`
   - If they confirm, use it. If not, ask for the correct path.
   - If no doc exists, note it and move on.

3. "What solution did you decide on?" _(This is the PM's decision — what are we building? 2-4 sentences.)_

4. "Do you have a Linear issue ID for this?" _(e.g. FDE-142 — optional, skip if not using Linear)_

---

## Step 3: Generate the Brief

```bash
mkdir -p outputs/marge
```

Write `outputs/marge/brief.json`:

```json
{
  "feature": "<feature name>",
  "linearIssueId": "<issue ID or null>",
  "branchName": "ralph/<feature-name-kebab-case>",
  "solutionDecision": "<PM's solution decision>",
  "lisaDiscoveryDoc": "<relative path to Lisa doc or null>",
  "bartDesignBrief": "outputs/bart/design-brief.json",
  "createdAt": "<YYYY-MM-DD>"
}
```

---

## Step 4: Show Summary and Confirm

Print a readable summary:

```
Feature:        <feature name>
Solution:       <solution decision — first sentence>
Lisa doc:       <path or "none">
Bart brief:     outputs/bart/design-brief.json
Linear issue:   <ID or "none">
Branch (Ralph): ralph/<feature-slug>
```

Ask: "Does this look right? I'll save the brief once you confirm, then you can run `npm run marge`."

---

## Step 5: Save and Launch

Once confirmed, save `outputs/marge/brief.json`.

Tell the user:

> "Brief saved. Run this to start Marge:
>
> ```
> npm run marge
> ```
>
> Marge will read Lisa's research, read Bart's design brief, write the PRD, run a 7-perspective pressure test, iterate on any must-fix issues, and output `ralph/prd.json`. Tail `outputs/marge-progress.log` to watch progress.
>
> When she's done, review `outputs/prds/<feature-slug>-prd.md` before handing off to Ralph."
