# Claude Code instructions — Creative Moments

Start with `docs/ARCHITECTURE.md`, then read `docs/PROJECT_PLAN.md` and `docs/TEST_PLAN.md` before editing. `AGENTS.md` points other agents here.

**Current status:** A local working copy contains Today, year navigation, due dates, explicit carry-forward and editable backup/restore. These changes have **not** been compiled/tested with Xcode. First establish a verified Mac build and regression tests; do not assume runtime correctness.

- Keep the existing SwiftUI/PencilKit project, 12 scenes, app icon and saved formats. No rewrite.
- Prefer native APIs and the smallest clear implementation. Do not introduce generic service/repository layers, dependencies, AI, accounts, networking or complex frameworks without demonstrated need and approval.
- `PlannerStore` owns saved state; views call its methods and use its bindings. Put business rules in the store, not duplicated across screens. See the interaction map in `docs/ARCHITECTURE.md`.
- Add concise comments only for non-obvious invariants (data migration, time-zone/date semantics, recovery, cross-feature side effects); use descriptive names instead of commenting every line.
- **Documentation is part of the change:** Update `docs/ARCHITECTURE.md` when interactions or ownership change, `docs/DECISIONS.md` for lasting design choices, `docs/FEATURE_MATRIX.md` for behavior, `docs/TEST_PLAN.md` for verified results, and `docs/CHANGELOG.md` for user-visible changes. Avoid redundant documents.
- On macOS run `Tools/build_and_test.sh` with an actual simulator `DESTINATION`; report exact errors and results. Never claim Xcode success from Linux syntax checks.
- Protect old planner files; confirm destructive actions; preserve old Codable and backup formats; test migration/restore before extending schemas.
- Work on a branch with small reviewable commits; do not push straight to `main` or merge without review.
