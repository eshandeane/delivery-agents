---
name: prince
description: "Run acceptance tests against a PRD. Use when you want Prince to verify acceptance criteria in the browser. Triggers on: /prince, run prince, run acceptance tests, test this feature."
user-invocable: true
---

# Prince — Acceptance Test Runner

Prince is the autonomous acceptance testing agent. This skill finds the right PRD, generates a brief, and tells you to run `npm run prince`.

---

## Step 1: Find the PRD

Check if the user specified a PRD file. If not, look for PRDs in the current branch:

```bash
find ralph/tasks docs/prd plans . -maxdepth 2 -name "*.md" 2>/dev/null | xargs grep -l "Acceptance Criteria" 2>/dev/null | head -10
```

If multiple PRDs are found, list them and ask which one to test. If one is found, confirm it with the user. If none are found, ask the user to provide the path.

---

## Step 2: Get context

```bash
git branch --show-current
```

Extract the feature name from the PRD filename or the `# PRD:` heading inside the file.

---

## Step 3: Write the brief

Write `outputs/prince/brief.json`:

```bash
mkdir -p outputs/prince
```

```json
{
  "prdFile": "<relative path to PRD from project root>",
  "feature": "<feature name from PRD title>",
  "branch": "<current branch name>",
  "createdAt": "<today's date as YYYY-MM-DD>"
}
```

---

## Step 4: Confirm and launch

Show the user a summary:

```
Feature: <feature name>
PRD:     <prd path>
Branch:  <branch>
Brief:   outputs/prince/brief.json
```

Then tell the user:

> "Brief saved. Run this in your terminal to start Prince:
> ```
> npm run prince
> ```
> Prince will read `outputs/prince/brief.json`, set up the test environment, and stream progress live."
