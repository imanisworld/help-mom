# Creative Moments — product and delivery plan

## Product promise
A local-first creative planner combining date-based planning, notes, reflection, doodling and coloring. Avoid complexity that does not serve planning or creativity. Prefer opt-in, predictable automation over opaque AI actions.

## Current implementation status
A working copy includes initial Today/due-date/year-navigation/carry-forward/editable-backup changes. They are **not** a completed phase: Xcode compilation and 12 XCTest tests pass in CI, while manual UI/device checks and several listed capabilities remain incomplete. See `docs/FEATURE_MATRIX.md` for source-level coverage.

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
