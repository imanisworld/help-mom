# help-mom

# Creative Moments — iPhone & iPad app project

An offline native SwiftUI planner by T. Crumble / Bridging the Gap.

**Development status:** Simulator build and all 12 XCTest tests passed in [CI run 43780104771](https://github.com/imanisworld/help-mom/actions/runs/43780104771) using Xcode 26.6 and iPad (A16), iOS 26.2. This is not a signed App Store binary. Local simulator development requires full Xcode; manual UI and real-device/Pencil validation remain outstanding. See [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md).

## What is implemented

- Year navigation for future months, retaining the original 18 months from December 2026 through May 2028 and Monday-start calendars (including February 29, 2028).
- Monthly focus and editable day plans; tasks that can be added, edited, checked, deleted and optionally given due dates; a Today list of due/overdue items; explicit unfinished-task carry-forward; notes and creative reflections.
- Four doodle sections per month, with a matching seasonal scene in the first. Twelve original generated scenes recur by month.
- PencilKit finger/Apple Pencil drawing, pen, translucent marker, vector eraser, undo/redo, clear confirmation, pinch zoom, two-finger pan.
- Fixed 1000×1000 drawing coordinates, preserving alignment across screen sizes and rotation.
- Device-local automatic saving; JSON schema marker, atomic writes, visible save failures, protection against overwriting corrupted files; editable full backup export and user-confirmed restore.
- Native photo-picker cover personalization and title editing. Photos remain on device.
- Per-month PDF export: calendar, checklist/notes (additional pages as needed), then the four-section doodle page. Individual drawing PNG sharing.
- iPhone and iPad layouts, named accessibility controls, built-in privacy/help screen, app icon, launch screen configuration, privacy manifest.

## Development handoff

For code ownership, cross-feature data flows, persistence contracts and change rules, read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`CLAUDE.md`](CLAUDE.md). The current **working copy** also contains a Today screen, year navigation, dated tasks, confirmed carry-forward and editable backup/restore; their bundled XCTest regressions now pass in CI; manual UI/device checks remain outstanding.

## Open and run on a Mac

For VS Code tasks, prerequisites and command-line setup, see [`docs/IMPORT_TO_GITHUB.md`](docs/IMPORT_TO_GITHUB.md). No third-party dependencies are required.

1. Unzip this package. Open `CreativeMoments.xcodeproj` in a current Xcode release supporting App Store submissions.
2. Select the **CreativeMoments** app target. Under **Signing & Capabilities**, select your Apple Developer team. Replace `com.example.CreativeMoments` with a unique bundle identifier you control. Keep automatic signing enabled.
3. Select an installed iPhone or iPad simulator and press **Run**. Deployment target is iOS/iPadOS 17.0; use the SDK required by Apple at submission time.
4. Run **Product → Test**. Review and fix any compiler, test, or runtime issues before continuing. Test the drawing experience on a real iPad with Apple Pencil, as simulator testing cannot substitute for it.
5. Follow `Submission/RELEASE_CHECKLIST.md` before archiving.

## Before upload — release blockers

- Complete manual simulator and real-device smoke tests; CI compilation and bundled XCTest are verified.
- Set your signing team and production bundle identifier.
- Publish the privacy policy and support/contact pages using your real business contact information. Set both HTTPS URLs in `ReleaseConfiguration` at the bottom of `Views.swift`.
- Capture genuine screenshots from the running app on required device sizes. No simulated screenshots are included.
- Complete the actual privacy and age-rating questionnaires in App Store Connect, verifying them against the shipping binary.
- Select a sale price and distribution territories. This project includes no subscriptions, paywalls, StoreKit products, ads, or analytics. A paid-upfront app is a simple initial model; App Store pricing is configured separately.
- Review generated-art rights, brand-name availability, and all marketing text. No trademark clearance or copyright registration has been performed.

## Archive / TestFlight / submit

With a production signing team selected, choose a generic iOS device destination, then **Product → Archive**. In Organizer choose **Distribute App → App Store Connect** and follow Apple's validation/upload flow. Create the app record using the same bundle ID; complete metadata, screenshots, privacy, age rating, pricing, and review information; select the uploaded build. Distribute to TestFlight for device testing before submitting to App Review. Apple decides approval.

## Important product limits

- Future years can be browsed; no recurring events, reminders, system-calendar sync, widgets, accounts, or cloud sync.
- Coloring is freehand, not tap-to-fill. Two-finger panning and pinch zoom should be tested on actual devices.
- PDF/PNG exports are snapshots, not editable backup files. Use the separate editable backup/restore feature before replacing devices or removing the app. Device backup behavior depends on Apple's backup settings.
- Cover photos use a center-cropped preview; no in-app crop editor is included. Monthly PDF exports do not include the cover.
- No live storefront, published policy website, App Store listing, or paid account has been created.

## Files

- `CreativeMoments/`: Swift code, `Info.plist`, privacy manifest, icon, seasonal images.
- `CreativeMomentsTests/`: date, Codable and disk-persistence tests.
- `Submission/`: listing copy, privacy-policy draft, support draft, release checklist, validation record.
- `CreativeMoments.xcodeproj`: native Xcode project plus shared app scheme.

## Source references

Apple documentation checked November 15, 2026:
- https://developer.apple.com/documentation/pencilkit/pkcanvasview
- https://developer.apple.com/documentation/swiftui/uiviewrepresentable
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/submitting/
- https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/

© 2026 T. Crumble / Bridging the Gap. The creator may modify and distribute this app project. Do not treat the included buyer-use wording from earlier printable products as restricting the creator's own app development.
