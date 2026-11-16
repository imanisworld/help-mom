# Architectural decision log

- **D-001 (2026-11-15): Preserve original SwiftUI/PencilKit code and 12 seasonal images.** No rebuild.
- **D-002 (2026-11-15): Local-first.** No login, backend or network requirement; notifications later require opt-in.
- **D-003 (2026-11-15): Protect data before feature growth.** Editable export/restore and legacy compatibility precede schema-changing automation.
- **D-004 (2026-11-15): Keep architecture small.** SwiftUI views → one `PlannerStore` → v1 JSON + drawing files; no speculative service layers or third-party packages.
- **D-005 (2026-11-15): Build gate.** Parsing/source presence is not proof of a functioning iOS app.
- **D-006 (2026-11-15): Git workflow.** Use `chore/creative-moments-phase1-audit` as development branch. Repo branch creation was later successful; working app files still need to be imported. Keep `main` untouched until reviewed.
- **D-007 (2026-11-15): Explain cross-feature behavior in one source of truth.** Maintain `docs/ARCHITECTURE.md` interaction/data contracts and targeted tests in the same PR as each interface change, rather than verbose per-line comments or redundant docs.

- **D-008 (2026-11-15): Do not rewrite state management simply to chase API novelty.** `ObservableObject` / `@EnvironmentObject` are supported SwiftUI APIs; consider migrating to `@Observable` only after a passing baseline and a concrete simplification or performance benefit.

- **D-009 (2026-11-15): Independent everyday use is the next delivery gate.** Use the four-section home concept in `PROJECT_PLAN.md`, preserve existing content/data, and deliver an installed app. Developer setup is separate from Mom's experience. Observe uncoached use before expanding the feature backlog.

## Pending product decisions
- iPad-first creative experience vs equal phone/tablet parity.
- Optional iCloud synchronization after editable backup/restore is proven.
- Pricing model (not yet implemented).
