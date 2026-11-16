# Change log

## 2026-11-15 — Phase 3 save integrity (separate branch; Xcode tests pending)
- Fail editable backup export if the latest planner save fails; do not silently proceed with an unpersisted state.
- Flush pending planner changes before backup restore moves the existing files into the local recovery folder.
- Only publish drawings to the in-memory cache/gallery after the file write succeeds.
- Added regression cases for save failure, pending-edit recovery and drawing-write errors. No new dependencies, file formats, UI screens or migrations.
- Native simulator build and new XCTest cases require verification before merging.



## Phase 2 completion — navigation/accessibility (native tests pending)
- Made all four drawing activities visible directly in Color & Draw, including Sketch and Patterns; preserved existing drawing storage and season gallery.
- Reused the bounded year selector in My Planner to avoid inconsistent year navigation and undersized arrow targets.
- Added four stable Home accessibility identifiers and native XCUITest smoke tests for navigation and the drawing editor's Done button.
- No new third-party dependencies, saved formats or seasonal artwork changes. Native CI and manual testing are required before declaring Phase 2 fully verified.


## 2026-11-15 — Working copy: first planning and safety improvements (unverified on iOS)
- Added a Today screen with dated/overdue tasks and shared daily notes.
- Added year navigation while keeping the original saved month keys and artwork.
- Added optional task due dates with backwards-compatible decoding of existing tasks.
- Added user-confirmed carry-forward that moves unfinished tasks without duplicating UUIDs.
- Added editable full backup export and confirmed restore for notes, tasks, cover and drawings.
- Documented file ownership, code interactions, save/restore flow, and rules for future agents.
- Added regression tests for new date/task/storage behavior.
- **Not yet verified:** Xcode compilation, XCTest execution, simulator/device behavior, signed app, or remote GitHub source upload.

## 2026-11-15 — Phase 1 project preparation
- Preserved the original Xcode project and seasonal artwork.
- Created project roadmap, architecture notes, test plan, agent instructions and Mac build script.
- Static source inspection only; no compiled app.

## 2026-11-15 — Development setup
- Imported the existing project and preserved source/artwork/data contracts.
- Added VS Code tasks, dependency-free macOS static validation and explicit Xcode prerequisite errors.
- Build helper runs simulator tests by default; import helper preserves remote files.
- Local simulator build blocked by missing full Xcode; no runtime success claimed.
- Fixed the CI-confirmed nonexistent Cocoa error code for unsupported backup versions; rejection and saved formats remain unchanged.
- Verified Xcode 26.6 simulator build and all 12 XCTest tests (zero failures) in CI run 43780104771.

## Phase 2 — Simple home and navigation
- Added My Planner, Color & Draw, My Journal and My Creations with large, labeled home cards.
- Preserved existing planner, cover, drawing, sharing and backup flows.
- Journal shares existing monthly notes; creations browse existing saved drawings across years with previews.
- No new dependencies, artwork changes or saved-format migration. Native verification pending.
