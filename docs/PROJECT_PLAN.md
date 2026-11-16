# Creative Moments — product and delivery plan

## Product promise
A local-first creative planner combining date-based planning, notes, reflection, doodling and coloring. Avoid complexity that does not serve planning or creativity. Prefer opt-in, predictable automation over opaque AI actions.

## Current implementation status
A working copy includes initial Today/due-date/year-navigation/carry-forward/editable-backup changes. They are **not** a completed phase: Xcode compilation and 12 XCTest tests pass in CI, while manual UI/device checks and several listed capabilities remain incomplete. See `docs/FEATURE_MATRIX.md` for source-level coverage.

## Next milestone — Mom can use the app independently

Deliver an installable iPhone/iPad app that opens from its icon and supports planning, drawing, reflection and finding saved work without coding knowledge or developer assistance. Ease of use is a requirement for this milestone, not final release polish. This milestone takes priority over the feature expansion backlog below; preserve its data-safety gates.

### Proposed home (not implemented yet)

**Creative Moments** — Your space to plan, create, and reflect.

| Button | Supporting text | Intended destination |
|---|---|---|
| My Planner | View and edit plans | Existing calendar, day notes and checklists |
| Color & Draw | Make something | Seasonal picture selection and existing drawing editor |
| My Journal | Write or reflect | Direct access to editable notes/reflections |
| My Creations | See saved work | Browse, reopen and share saved drawings |

Reuse existing planner records and drawings. Separate journal navigation and a creations browser are planned work, not existing completed features. Begin with clearly labeled sections; search is optional if finding work is already easy. Coloring initially means the existing freehand drawing tools; tap-to-fill is not implied.

### Everyday experience requirements

- Large labeled buttons, readable text that respects text-size settings, few menus and an obvious way home.
- Edit planner content directly inside the app. Save automatically, preserve work across closing/reopening, and explain save failures in plain language.
- Select an existing illustration and draw using a finger or Apple Pencil.
- Find and reopen previous work through clear sections; share or print through a labeled Share action.
- Make common mistakes recoverable: retain drawing undo/redo, verify editing undo, and provide confirmation plus a recovery path for destructive actions. General planner undo is not currently verified or complete.
- No Xcode, GitHub, Terminal, source ZIPs, code editing or file-path instructions in the everyday user journey. Developer tooling remains our responsibility.

### Delivery and acceptance

1. Simplify the home and routes using existing functionality; map any new navigation to existing data before changing schemas.
2. Verify edit, automatic save, reopen, find, undo/recovery and share on device. Keep CI compilation and regression tests passing.
3. Prepare signing/distribution and deliver a TestFlight installation to Mom; App Store delivery follows release review. Account/signing readiness has not been established yet.
4. Observe Mom performing the tasks in `TEST_PLAN.md` without coaching. Fix confusion before adding recurring tasks, reminders or other major features.

**Done means:** she can install the provided build, tap its icon, create/edit something, close and reopen it, find her work, recover a simple mistake and share it without developer instructions. A source archive or passing CI alone does not satisfy this milestone.

## Delivery order and gates

### P0 — Import & verify baseline (immediate)
- Import the original Xcode project **and all 12 seasonal images** into `imanisworld/help-mom` on a feature branch.
- Retain Xcode project IDs and artwork; no recreation/rebrand.
- Build and test in Xcode using `Tools/build_and_test.sh` on macOS; record Xcode version and selected simulator.
- Inspect runtime flows on simulator and real iPad (Pencil) when available.
- Fix only confirmed baseline defects and failing tests.
- **Gate:** build succeeds, all included XCTest tests pass, no known app-start crash or data-loss regression.

### P1 — Protect existing data before expanding models
- Document schema v1 and all saved files (planner JSON, separate PKDrawing files, cover JPG).
- Add a versioned, validated, reversible migration protocol with tests and backups of pre-migration data.
- Provide user-initiated, editable backup/export and verified restore for complete planner, drawings and cover.
- Include clear restore confirmation and conflict handling; ensure no silent overwrites.
- **Gate:** round-trip editable restore passes, corrupt source import fails safely, prior data preserved.

### P2 — Planning foundation
- Unlimited calendar navigation with current-day focus; preserve existing 18 months and themes.
- Today/weekly/monthly views appropriate for small iPhones and larger iPads.
- Structured task dates, due times (optional), priorities, completion history, stable recurrence rule/occurrence IDs.
- Carry-forward: offer review/confirmation, preserve attribution and prevent duplicates.
- **Gate:** recurring and carried tasks remain correct over time-zone/DST changes and restarts.

### P3 — Automations (entirely optional)
- Daily Today dashboard; overdue-task review rather than forced rescheduling.
- Repeat tasks generated idempotently.
- Local reminders with granular permission/settings, quiet hours and no repeated alerts.
- User-triggered or opt-in weekly resets and monthly reflections, calculated from real saved records.
- Rotating seasonal creative prompts; optional scheduled creative sessions.
- **Gate:** restart, delayed notification, missed days, DST and clock changes tested; no duplicates or unexpected modifications.

### P4 — Creative studio
- Improve drawing responsiveness and editing UX on iPad and iPhone.
- Expand original scenes, reusable templates, journaling and an editable/searchable creation gallery.
- Build tap-to-fill only after evaluating actual raster/vector complexity and accessibility.
- Optional vision-board workflow; keep it separate from core planning.
- **Gate:** art is preserved and export/edit/relaunch work on both platforms.

### P5 — Release readiness
- Optional iCloud sync only after backup/restore and conflict-resolution work is established.
- Accessible and adaptive layouts; privacy/security audit; backup recovery help.
- Verify PDF layout, shared image assets, permissions, support/privacy pages, genuine app screenshots.
- TestFlight and App Store readiness; signing, pricing, entitlement and compliance decisions by publisher.
- **Gate:** release checklist complete and device testing evidence attached.

## Invariants
- Zero silent data loss or destructive automation.
- No AI, account system, third-party analytics, or backend service without explicit value/privacy/cost decision.
- No forced subscription design. User chooses business model after real prototype validation.
- Claude Code and Codex use the same issue backlog and phase gates; avoid competing concurrent edits.
- One reviewed PR per coherent change; no push directly to `main` for new code.
