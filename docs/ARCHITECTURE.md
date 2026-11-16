# Creative Moments — architecture and interaction guide

This is the **current source implementation**, not a certified working iOS build. Keep this document aligned with code whenever a data model, ownership boundary, or cross-feature behavior changes.

## Ownership: where to make a change

| Area | File | Owns | Does not own |
|---|---|---|---|
| App lifecycle | `CreativeMomentsApp.swift` | Root `PlannerStore`, app-level errors, background flush | Planner data rules |
| Models | `Models.swift` | Dates, task/record types, stable keys, Codable compatibility | Storage or UI |
| Planner state/storage | `Store.swift` | All updates, queries, JSON/drawing persistence, editable backups | Screen layout |
| Screens | `Views.swift` | Navigation, bindings, confirmations, file share/import UI | Direct writes to persisted files |
| Drawing editor | `Drawing.swift` | PencilKit editing and gestures | Planner task semantics |
| PDF | `PDFExport.swift` | Read-only month snapshots | Editable backup/restore |
| Tests | `CreativeMomentsTests/PlannerTests.swift` | Model and persistence regressions | Simulator/device certification |

**Keep it simple:** No repository/service layer or new third-party dependency is required for the current local-only app. `PlannerStore` is the single state and persistence owner. Split a file only when a measurable maintenance problem justifies it.

## Interaction map

```text
CreativeMomentsApp  ── owns one PlannerStore ─────────────────────────────┐
                                                                         │
HomeView ── PlannerView ── TodayView / MonthView ── store methods + Binding ────────────┤
  │                                │                                      │
  │                                ├─ PlannerDocument ── planner.json    │
  │                                ├─ PKDrawing files ── YYYY-MM-N.drawing│
  │                                └─ cover.jpg                           │
  ├─ BackupView ── export/restore on PlannerStore ── staged files          │
  └─ MonthView ── DoodleEditor / PlannerPDF ── read/write via store ──────┘
```

### Planning flow

1. `TodayView` calls `store.openTasks(dueOnOrBefore:)`, which scans saved month records and returns incomplete dated tasks with their owning month. Undated tasks remain in their month checklist.
2. `TodayView` adds a task using `store.addTask(_:in:dueDate:)`; `MonthView` adds an undated task. Both use the same `PlannerTask` and save path.
3. `MonthView` edits a task by **stable UUID**. `TaskDueDateView` updates the optional `dueDateKey`. Tasks remain stored in their owning month even if the due date points elsewhere.
4. `MonthView` confirms carry-forward before `store.carryForwardUnfinished(into:)` **moves** incomplete tasks from the previous month. It preserves task UUIDs, leaves completed tasks behind, and moves outdated due dates to the destination month's first day. Repeating the operation has no additional effect.
5. Year arrows in `PlannerView` construct `PlannerMonth` dynamically. `PlannerMonth.all` still lists the original 18 months for backwards compatibility/tests; it is **not** a limit on navigation.

### Saving, drawing, backup, and restore

- `store.update` changes a `MonthRecord` and schedules a **350ms debounced atomic** JSON save. The app flushes when entering a non-active scene phase; note editing also flushes on exit.
- `DoodleEditor` uses PencilKit and passes its result to `store.saveDrawing`, which saves a separate `.drawing` file immediately. `PlannerPDF` reads the store and generates a printable snapshot; PDFs cannot restore editable state.
- `BackupView` asks `store.exportEditableBackup()` for a complete JSON archive containing planner, cover JPEG and every saved drawing. The user chooses where to share/store the exported file.
- Restore uses the iOS document picker, explicit destructive confirmation, and `store.restoreEditableBackup(from:)`. The store verifies format, cover and drawings, stages replacement files, then moves the old directory to a sibling recovery folder before switching. Do not bypass this flow with direct file replacement.
- On unreadable saved state, `PlannerStore` disables further writes instead of replacing files with empty defaults. Keep that safeguard intact.
- **Save integrity (Phase 3):** `flush()` returns success/failure. Editable backup export aborts if current notes/tasks cannot be written, and restore flushes current edits **before** moving their directory into recovery. Failed `.drawing` writes do not update the drawing cache or increment the gallery revision. Callers that only request normal autosave can ignore the return value; backup/restore must check it.

## Data contract (version 1)

- `planner.json` encodes `PlannerDocument` with `schemaVersion == 1`; unknown versions must fail closed.
- `months` keys: `YYYY-MM`; day-note keys inside each month: unpadded day numbers (`"1"`–`"31"`).
- A task has a persistent UUID, title, completion flag and optional `dueDateKey` (`YYYY-MM-DD`). Older saved tasks **do not include** `dueDateKey`; decoding must accept them.
- Drawings: `<YYYY-MM>-<section raw value>.drawing`; sections are `0...3` in `DoodleSection` order. Cover photo: `cover.jpg`.
- Editable backup archive: `formatVersion == 1` and `planner` + optional `coverJPEG` + dictionary of drawing filename to bytes. Keep old backup compatibility when revising the format.

## Change checklist for anyone (human, Claude Code, Codex)

1. Find the owner in the table above; follow the interaction map before changing a cross-feature behavior.
2. Favor the simplest native SwiftUI/PencilKit API. Avoid speculative abstraction, duplicate state, third-party packages and hidden automatic mutations.
3. If a model, identifier, file format or store method changes, update this file **in the same change**, plus `docs/DECISIONS.md` if it is a durable design choice.
4. Add focused tests for legacy decoding, persisted-data changes, carry-forward, export/restore and failure/rollback paths. Never describe syntax parsing as an Xcode build.
5. Update `docs/FEATURE_MATRIX.md` and `docs/CHANGELOG.md` for changed behavior. Only record commands and tests actually run in `docs/TEST_PLAN.md`.
6. Use small reviewed PRs; never work simultaneously on incompatible schema changes.

## Four-section navigation

- `HomeView` owns one navigation stack and offers My Planner, Color & Draw, My Journal and My Creations. Standard navigation returns to Home; the drawing editor is a full-screen presentation with Done returning to its originating section.
- `PlannerView` preserves the previous home’s Today/month navigation, cover personalization and backup access.
- `ColorDrawView` offers all four existing PencilKit sections for the current month (season, sketch, patterns, free) and lets the user choose older/newer seasonal pictures with `YearNavigation`. Selecting a picture resumes that month/section, not a new duplicate drawing.
- `JournalView` selects a month; `JournalMonthView` uses `PlannerStore.binding` for the existing `notes`, `joy` and `carryForward` fields and flushes on exit. Planner and journal edit the same records.
- `PlannerStore.savedDrawings()` enumerates canonical v1 drawing filenames, including those without planner JSON records, newest month first. `SavedDrawing` is an in-memory reference, not a new stored type. `CreationsView` refreshes on store revision after save/restore. Thumbnails load through the store in view tasks, outside body evaluation; opening an item uses the existing editor and sharing flow.
- No schema, drawing coordinates, artwork or backup format changes. Undo beyond the existing drawing editor remains a later usability task.
