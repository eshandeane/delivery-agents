---
name: prince
description: "Run acceptance tests against a PRD. Use when you want Prince to verify acceptance criteria in the browser. Triggers on: /prince, run prince, run acceptance tests, test this feature."
user-invocable: true
---

# Prince — Acceptance Test Runner

Prince is the autonomous acceptance testing agent. This skill finds the right PRD and launches Prince to test it.

---

## Step 1: Find the PRD

Check if the user specified a PRD file. If not, look for PRDs in the current branch:

```bash
find ralph/tasks docs/prd plans . -maxdepth 2 -name "*.md" 2>/dev/null | xargs grep -l "Acceptance Criteria" 2>/dev/null | head -10
```

If multiple PRDs are found, list them and ask which one to test. If one is found, confirm it with the user. If none are found, ask the user to provide the path.

---

## Step 2: Confirm and Launch

Show the user:
```
PRD:    <path>
Branch: <current branch>
```

Ask: "Ready to run Prince against this PRD?"

Once confirmed, tell the user:

> "Run this in your terminal to start Prince:
> ```
> npm run prince -- <prd-path>
> ```
> Tail `outputs/prince-progress.log` in a second terminal to watch progress."
