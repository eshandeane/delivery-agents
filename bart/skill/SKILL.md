---
name: bart
description: "Generate a design brief for the Bart prototyping agent. Use when you want Bart to prototype a set of UI components. Triggers on: /bart, run bart, prototype this, bart brief."
user-invocable: true
---

# Bart Brief Generator

Bart is the autonomous UI/UX prototyping agent. This skill creates the `outputs/bart/design-brief.json` it needs to run, then launches Bart via `/loop`.

---

## Step 1: Understand the Request

Read the user's description of what to prototype. If it's vague, ask up to 3 clarifying questions:

- **What page(s) is this on?** (URL path or page name)
- **What are the key components?** (cards, tables, charts, modals?)
- **Any constraints?** (must reuse existing components, specific layout, mobile priority?)

If the description is clear enough, skip straight to Step 2.

---

## Step 2: Generate the Design Brief

Create `outputs/bart/design-brief.json` based on the user's description.

Break the request into discrete design tasks — one task per distinct component or section. A good task is scoped to something that can be built and reviewed independently (e.g., a single card, a table, a modal). Avoid tasks that are too broad ("redesign the whole page").

**Branch naming:** use `bart/<kebab-case-feature-name>` based on the feature being prototyped.

**Template:**

```json
{
  "project": "<Feature Name>",
  "branchName": "bart/<feature-name>",
  "description": "<1-2 sentence description of what's being designed and why>",
  "designTasks": [
    {
      "id": "DT-001",
      "title": "<Short component name>",
      "description": "<What this component does and what a user should understand from it>",
      "page": "<URL path, e.g. /workspaces/[workspaceId]/growth>",
      "specs": {
        "layout": "<How it should be laid out — grid, card, table, sidebar, etc.>",
        "components": ["<shadcn/ui or existing components to use>"],
        "interactions": [
          "<Hover states, click behaviors, expandable sections, etc.>"
        ],
        "constraints": [
          "<Any hard requirements — reuse X component, mobile-first, etc.>"
        ]
      },
      "priority": 1,
      "phase": "build",
      "complete": false,
      "scores": {},
      "notes": ""
    }
  ]
}
```

Number tasks by priority (1 = highest). Bart will work through them in order.

---

## Step 3: Create Supporting Files

Create `outputs/bart/progress.txt` with an empty Design Patterns section:

```
## Design Patterns
(none yet — patterns will be added as Bart discovers them)

---
```

Create the screenshots directory:

```bash
mkdir -p outputs/bart/screenshots
```

---

## Step 4: Show the Brief and Confirm

Print the design brief in a readable summary (not raw JSON) so the user can review it:

```
Project: <name>
Branch: <branch>
Description: <description>

Design Tasks:
  DT-001 [P1] — <title>
    Page: <page>
    Build: <1-line summary of what to build>
    Key interactions: <comma-separated>

  DT-002 [P2] — ...
```

Ask: "Does this look right? I'll launch Bart once you confirm."

---

## Step 5: Launch Bart

Once confirmed, tell the user:

> "Brief saved. To run Bart, use: `/loop` with the bart agent. Bart will work through each task — build, review, iterate — until all components hit the quality bar or are marked blocked after 10 iterations. Tail `outputs/bart/bart-progress.log` to watch progress."

Then invoke the bart agent:

```
Agent(subagent_type="bart", prompt="Run the design brief at outputs/bart/design-brief.json. Start from the highest priority incomplete task.")
```
