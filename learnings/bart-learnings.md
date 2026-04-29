
## Run: 2026-04-22 — DT-001 Workspace Growth tab shell + sub-tab navigation

### Iteration Count & Root Cause
- Iterations needed: 1
- Main re-work cause: Missing hover states on inactive tab triggers

### Design Quality Improvements for Next Run
- Always add `hover:text-foreground` to custom TabsTrigger when overriding shadcn defaults with bg-transparent TabsList — shadcn has no implicit hover bg in this configuration
- Keep TabsContent OUTSIDE the sticky wrapper — anly wrap TabsList in the sticky div; putting TabsContent inside makes it sticky too
- Use `router.replace(url, { scroll: false })` for URL-driven tab state to avoid scroll jumps and back-stack pollution

### Component Patterns Discovered
- Workspace sidebar nav items: `{ title: "Growth", href: \`/workspaces/${workspaceId}/growth\`, icon: TrendingUp }` inserted at the right array position in workspace-sidebar.tsx
- URL-driven tab state: read with `useSearchParams().get("subtab")`, write with `router.replace` + `{ scroll: false }`
- TypeScript for protected routes: worktree shares node_modules with main repo; tsc must pass before commit (stop hook enforces this)

### Scoring Calibration
- Interaction quality 3 means missing hover/focus states — always verify hover: classes on interactive elements, especially when custom styling overrides shadcn defaults
- If Playwright browser is locked (another session holds it), do code review instead and note it; don't block the build
