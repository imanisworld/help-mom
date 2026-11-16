# Creative Moments — Web companion

This standalone browser companion is **not** the native SwiftUI/PencilKit app. It keeps plans, notes, covers and drawings in the browser only; no login, cloud sync or server-side user storage.

## Run and test

From this `web/` directory:
- `python3 -m http.server 8765` then visit http://localhost:8765/
- `node --check app.mjs && node --check data.mjs && node --check sw.js`
- `node --test tests/*.test.mjs`

The app uses the original preview storage key `creative-moments-browser-preview-v1`. Browsers on **different hostnames do not share stored data**. Export a complete JSON backup before moving to another domain/browser/device. Restore validates the format, confirms replacement, and retains a separate local recovery snapshot when possible. Imported data is not synced.

## What this release includes

Four-section home, month/date tasks, Today and overdue list, move unfinished tasks, journal, seasonal coloring and freehand drawing with marker/eraser/undo/redo/zoom, saved-creations gallery, cover photo/title, export/restore, printable monthly PDF flow, service-worker cache, manifest and local art assets.

## Manual acceptance still required

- iPhone/iPad Safari: install from Home Screen, launch offline after one full online visit, image loading, export/import and Files integration.
- Finger/stylus input, pinch/zoom, large text, VoiceOver, landscape/tablet sizes.
- Storage quota, interrupted saves, restore from downloaded backup, and long-running use.

For release status, separate **automated checks** from **real-device validation**. This site remains a test release until manual acceptance. The original iOS implementation stays in `CreativeMoments/`.
