# Release checklist

## Identity and configuration
- [ ] Enroll/verify the publishing Apple Developer account; do not share passwords or private signing keys in chat.
- [ ] Confirm app name availability; set team, unique bundle ID, version/build and icon.
- [ ] Publish actual privacy and support URLs and configure them in `ReleaseConfiguration`.
- [ ] Review policy wording against the final app and any future SDKs or hosting services.

## Build and tests — not yet executed
- [ ] Clean build in current Xcode; resolve warnings/errors.
- [ ] Product → Test; all included XCTest tests pass.
- [ ] Launch on smallest supported iPhone and a large iPad, both orientations.
- [ ] Type long notes, emoji, accented text, and many tasks. Confirm no text is lost on PDF export.
- [ ] Add/edit/check/delete tasks, leave the month, and return.
- [ ] Quit and relaunch after typing, checking a task, and drawing; confirm persistence.
- [ ] Draw different marks in all four sections and in adjacent months; verify isolation.
- [ ] Test pen/marker/eraser, clear cancel/confirm, undo/redo on real hardware.
- [ ] Zoom, pan, rotate, and relaunch: artwork and strokes stay aligned.
- [ ] Use Apple Pencil and finger on a real iPad. Test compact iPhone drawing.
- [ ] Import, replace, and remove cover photos; cancel selection and try unsupported content.
- [ ] Export months with blank and long content; verify calendar → checklist/notes → doodle order and leap day.
- [ ] Test PDF/PNG sharing and cancellation on iPhone/iPad. View exported files in Files/Preview.
- [ ] Check low-storage behavior, backgrounding, force quit, and corrupt JSON preservation.
- [ ] Check VoiceOver labels, larger text, contrast, and keyboard dismissal. Drawing is inherently visual; provide accurate accessibility descriptions.
- [ ] Verify app data is local and no unintended network requests occur.

## App Store Connect
- [ ] Create the app record and paid-app agreements/tax/banking details if charging.
- [ ] Choose category, territories, price and truthful age/content ratings.
- [ ] Review `LISTING.md`; capture real screenshots from the built app.
- [ ] Add privacy and support URLs; answer data-collection questions for the actual shipped binary.
- [ ] Confirm current SDK, signing and export-compliance requirements in Apple's submission documentation.
- [ ] Archive, validate, upload and test through TestFlight.
- [ ] Add review notes: no login; select a month; Calendar/Checklist/Doodle; tap a doodle card to draw.
- [ ] Submit only after all applicable checks pass. Track Apple's response and fix issues before release.
