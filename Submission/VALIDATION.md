# Validation record

Prepared November 15, 2026.

## Checks completed in the authoring environment
- Seven Swift files parsed with the tree-sitter Swift grammar without syntax errors.
- Xcode OpenStep project parsed; 67 object references checked.
- All referenced source/resource files exist; all twelve seasonal scenes are bundled at print-quality resolution.
- Info.plist and PrivacyInfo.xcprivacy parse; shared Xcode scheme parses as XML.
- App icon is 1024×1024, opaque RGB; asset-catalog metadata parses.
- Independent date checks confirm 18 consecutive months, December 2026–May 2028, and February 29, 2028.
- Package ZIP contents validated after creation.

## Not validated here
No Swift compiler, Apple SDK, Xcode, simulator or Apple device is present in this environment. Syntax parsing does not establish that APIs type-check, that an Xcode build succeeds, or that UI, drawing, persistence, export, signing, TestFlight or App Review work correctly.

The six XCTest cases are included but have not run. Execute the release checklist on a Mac and actual devices. Fix any failures before submission.

## Remaining owner configuration
Signing team; production bundle ID; published privacy and support/contact URLs; pricing/territories; App Store screenshots; age rating/privacy/export compliance answers; archive and upload.
