# Prince Learnings

Accumulated efficiency rules from past runs. Apply all of these on every run.

## Playwright Efficiency

**Never call `browser_snapshot` twice in a row without an action between them.**
A snapshot is only useful immediately before an interaction. If you just took a snapshot and haven't clicked/typed/navigated, do not take another — the DOM hasn't changed.

**Never call `browser_snapshot` AND `browser_take_screenshot` on the same page state.**
- Use `browser_snapshot` when you need to find elements to interact with (selectors, text, structure).
- Use `browser_take_screenshot` only when saving a visual record for the report (one per user story).
- Do NOT do snapshot → screenshot → click. Do snapshot → click → (screenshot only if this is the final state for the report).

**Batch state checks.** After a click or navigation, take ONE snapshot to assess the result. Do not re-snapshot to "confirm" what you already see.

**Use `browser_evaluate` sparingly.** Only use it when the DOM snapshot cannot answer your question (e.g., checking computed styles, reading JS state). Do not use it to re-check things already visible in the snapshot.

## Setup Efficiency

**Check if the server is already running before tearing down Docker.**
Before Phase 2, run:
```bash
curl -sf http://localhost:3000/api/health > /dev/null 2>&1 && echo "RUNNING" || echo "NOT_RUNNING"
```
If `RUNNING`, skip Docker teardown, migration, and seeding entirely. Go straight to Phase 3. Log this as "Skip setup: server already running."

**Never kill and restart Docker if health check passes.** The teardown + restart + migration + seed sequence adds ~15 Bash calls and 2–3 minutes. Skip it whenever possible.

## Context Management

**Keep responses concise during testing.** Do not write long explanatory paragraphs between tool calls. The log file handles user communication — your text output should be one line per action at most.

**Do not re-read files you already read.** If you read the PRD in Phase 1, do not re-read it in Phase 3. Extract everything you need upfront.

**Limit fix attempts to 2 per criterion.** If a runtime error is not fixed after 2 attempts, record it as BLOCKED and move on. Do not loop indefinitely — unbounded fix loops are the main cause of context exhaustion.

## Reporting

**Take exactly one screenshot per user story** — at the end of the story after all criteria are verified, showing the final passing state. Do not take screenshots for individual criteria unless a criterion explicitly requires visual proof of failure.

## Run: 2026-04-23 — Triage Saved Views

### What Worked Well
- Using `browser_run_code` with `{ force: true }` on opacity-0 buttons (Radix menus, CSS hover-revealed) reliably triggers the dropdown
- Inspecting DOM with `browser_evaluate` to read `innerHTML` of a tablist gives full structure including hidden elements — critical for understanding CSS-based hover patterns
- Using `browser_evaluate` to check tablist state (dot/save/discard) is faster than snapshot for targeted checks

### Edge Cases Discovered
- **Radix dropdowns need `{ force: true }` click**: Elements with `opacity-0` can be clicked with JS `.click()` but Radix menus don't open — bust use Playwright's `locator.click({ force: true })` to properly trigger Radix state machine
- **CSS group-hover patterns**: The ​ button uses `group/tab` + `opacity-0 group-hover/tab:opacity-100`. Must hover the parent group div, not the button itself, to trigger CSS hover reveal
- **False unsaved changes on reload bug pattern**: When a view saves state but page load doesn't initialize URL params from saved state, the comparison creates false "unsaved changes". Watch for this in URL-state-synced features
- **Inline edit vs popover discrepancy**: Implementation used inline tab editing for create/rename instead of popover for create. Always verify if implementation matches PRD's specified interaction pattern

### Testing Improvements for Next Run
- For CSS hover-based elements (`opacity-0 group-hover`), always use `page.locator().hover()` on the parent group before clicking the target button with `{ force: true }`
- When testing duplicate name validation, try creating a view with an existing name and check for error text in the DOM
- To test "Escape closes without creating" for inline edit, monitor network requests to verify if a POST was made

### Environment Notes
- The `group/tab` Tailwind pattern wraps each non-Main tab in a `div.relative.group/tab` — use this selector to find the parent container
- Seed data creates 5 workspaces; triage table shows all 5 by default
- Migrations include `20260423085358_add_triage_view` which creates the TriageView table
- The Main view is auto-created on first GET if none exists (confirmed working in test env)