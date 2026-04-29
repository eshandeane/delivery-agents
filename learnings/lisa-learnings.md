# Lisa Agent Learnings

## 2026-04-08 — Font Size / Left Panel Discovery

### Finding the left panel
- The FDE platform has TWO sidebars: `WorkspaceSidebar` (per-workspace nav) and `InternalSidebar` (internal user nav)
- Both live in `src/components/common/`
- Both are mounted via layout files: `src/app/workspaces/[workspaceId]/layout.tsx` and `src/app/internal/layout.tsx`
- The base primitive is `src/components/ui/sidebar.tsx` (shadcn/ui)

### Typography pattern in FDE codebase
- No design token system or CSS variable for font sizes — all Tailwind hardcoded per-component
- Sidebar nav label: `text-[10px]` — this is the problem class
- Fix is: `text-[10px]` → `text-xs` (12px) on `SidebarMenuButton` className in both sidebar files

### Atlassian / Confluence
- Cloud ID for the FDE/getcodify instance: `541978bf-65c3-4f38-a69c-b09a79f2c4ba`
- Confluence search sometimes returns circuit-breaker errors — not a permissions issue, just system unavailability. Note it and move on.
- The `cutanddry.atlassian.net` URL does NOT work as a cloud ID — use the UUID above.

### Circleback search patterns
- Searching "font size" and "text too small" in transcripts found relevant evidence from meeting "Home Page Vibe Coding" where Kevin Wu flagged text looking small on the platform
- "left panel" returned early planning discussions — useful for understanding sidebar history, not user complaints
- "sidebar" returned architecture/UX planning discussions, not user pain point complaints
- For ambient friction (small text, slow load, etc.) users rarely mention it explicitly in meetings — look for adjacent signals (eye strain complaints, cognitive overload) in the persona instead

### Gmail search
- No results found for UI font size / readability complaints via Gmail — this class of friction is usually verbal, not email
- Don't over-interpret null Gmail results for UX friction; absence is expected

### UX/accessibility standards to cite for font size issues
- 10px: fails all automated accessibility checks (Lighthouse, axe-core, Equalize Digital)
- 12px (`text-xs` in Tailwind): meets practical minimum for UI labels
- 14px (`text-sm` in Tailwind): meets WCAG-aligned recommendation for nav text
- 16px: body text minimum per WCAG
- WCAG does not specify a hard minimum — but industry tooling consensus is 12px floor for UI labels

### When the fix is obvious (complexity: LOW), structure the doc accordingly
- Don't artificially inflate complexity or risk for trivial CSS changes
- Three solution options still required (quick win / balanced / full vision) but the recommendation can be direct and unambiguous
- "Just fix it" is a valid recommendation when the tradeoff analysis is clear


## Run: 2026-04-08 — Action Item Description Overflow Fix

### Discovery Effectiveness
- Best data source: Codebase — confirmed root cause directly from `textarea.tsx` (field-sizing-content) and `dialog.tsx` (no max-h). For UI bugs, code is the primary source of truth.
- Strong secondary: Circleback — provided adoption context (Kyle wanting to replace spreadsheets, Emina's call workflow, Eshan coaching usage) which transformed a "fix this CSS bug" into "this is blocking feature adoption at a critical moment".
- Weakest source: Gmail — no threads found about UI bugs. Users silently abandon broken UIs rather than email about them.
- Confluence unavailable (Hystrix circuit breaker) — always note this and flag to PM.

### Search Terms That Worked
- "action item feedback" in Circleback — found adoption conversations with clear business context
- Glob `**/*action-item*` — immediately found all relevant files
- Grep `prefilledDescription` — revealed the AI amplifier risk (draft action items path)
- Grep `field-sizing-content` — pinpointed the exact CSS class causing auto-grow

### Search Terms That Didn't
- "action item description" in Circleback transcripts — too literal, returned noise
- "textarea expand overflow" in Circleback — zero results (UI bugs aren't discussed in meetings)
- Gmail searches for UI bugs — always returns empty; users don't email about UI glitches

### Research Improvements for Next Run
- For UI/UX bug reports: go straight to codebase first, then use Circleback for adoption/business context, not bug confirmation
- Always grep for `prefilledDescription` or similar prop names to find risk amplifiers beyond the obvious trigger
- Circleback is most valuable for ADOPTION context on features, not for UX bug reports
- When a feature is "being actively promoted" internally (Eshan coaching team), check Circleback for that framing — it elevates the urgency of any UX fix dramatically

### Synthesis Patterns
- Silent abandonment is a strong signal: when no user complaints found in any channel, assume users work around the bug rather than report it
- AI-generated prefill paths are high-risk for layout bugs — always check if AI output populates form fields at dialog open time
- For UX bugs, the JTBD framing is "get the thing logged quickly, move on" — any friction at the submit step fails this directly
