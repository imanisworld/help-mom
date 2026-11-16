# Feature matrix — source inspection only

**In source** means implementation exists in the working project; it does **not** establish a passing Xcode build or correct runtime behavior.

| Feature | In source? | iOS build/device verified? | Next action |
|---|---|---|---|
| Today view; due and overdue task list | Yes, newly added | No | Build and test |
| Year navigation beyond May 2028 | Yes, newly added | No | Check date navigation and future month storage |
| Existing original 18 months and 12 scenes | Yes | No | Verify preserved data/artwork |
| Monthly focus and day notes | Yes | No | Test shared Today/month binding |
| Add/edit/check/delete task and optional due date | Yes, extended | No | Test legacy decode and cross-month queries |
| Explicit unfinished-task carry-forward | Yes, newly added | No | Test move once, no duplicate, stable IDs |
| Local JSON and drawing auto-save | Yes | No | Test save/restart/corruption |
| Editable backup/export and confirmed restore | Yes, newly added | No | Test round trip, invalid file, recovery |
| PencilKit drawing, pen/marker/eraser, zoom | Yes | No | Simulator and real iPad Pencil test |
| Cover title/photo | Yes | No | Test picker and persistent image |
| Monthly PDF and drawing PNG sharing | Yes | No | Inspect files on-device |
| Recurring tasks, reminders, weekly reset | No | No | Later phase |
| Creative prompts, gallery, stickers, fill-tool | No | No | Later phase |
| iCloud sync | No | No | Optional future phase |
| TestFlight/App Store app | No | No | Sign and test after build gate |

## Phase 2 navigation update

| Feature | Implementation | Verification |
|---|---|---|
| Four-section home | Large labeled cards with Dynamic Type support; native back navigation | Syntax passed; native CI pending |
| My Planner | Existing Today, months, cover and backup routes preserved | Manual navigation pending |
| Color & Draw | Twelve seasonal pictures by year; opens existing month/section; current-month free draw | Manual drawing/return pending |
| My Journal | Month browser and shared planner notes/reflections | New shared-binding persistence test added; CI pending |
| My Creations | Existing drawing discovery, thumbnails, reopen and existing editor sharing | New legacy discovery and restore-refresh tests added; CI pending |

This update does not add global search, general planner undo, tap-to-fill or new journal/drawing storage formats. The earlier source inventory above is historical; baseline native build and 12 tests passed before this update.
