# Development setup and import

Use `chore/creative-moments-phase1-audit` in `https://github.com/imanisworld/help-mom.git`. Never force-push or modify main.

## Local development

The `development` sibling checkout is the canonical Git working copy. The two extracted packages remain preserved. `CreativeMoments_iOS 2` supplies the newer app source; the older package is not imported over it. Source, artwork, project IDs and data formats are unchanged by setup.

Open the `development` folder in VS Code (File → Open Folder). Run Terminal → Run Build Task for the native build and tests, or select the static package check task. No VS Code extension, virtual environment, CocoaPods, package manager or third-party framework is required. The extracted package's Python environment mapping to the Xcode project is incorrect and is not used.

Install full Xcode and an iOS Simulator runtime supporting iOS 17 or newer. Launch Xcode once to finish installation and accept its license. If Command Line Tools remain selected, use a per-command override:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Tools/build_and_test.sh
```

The script builds for the simulator, selects an eligible installed simulator from Xcode's destinations, then runs XCTest. A missing Xcode or simulator is an error, not a successful test run. To select a specific simulator:

```bash
xcodebuild -project CreativeMoments.xcodeproj -scheme CreativeMoments -showdestinations
DESTINATION='platform=iOS Simulator,id=<device UUID>' bash Tools/build_and_test.sh
python3 Tools/validate_package.py
```

Simulator checks disable signing. A developer team and unique bundle ID are needed for device/distribution builds, not these checks. Build products stay in ignored `build/`.

## Import safety

The local import script was refreshed from the development branch, then changed to use dependency-free static checks and preserve existing remote files. It clones only that branch, copies missing project files without deleting or replacing remote files, lists remaining differences, and asks for review before committing/pushing. Existing file updates must be merged manually in a persistent checkout; the import helper is for missing files, not synchronization. Review `git diff` and staged files; never include `.venv`, credentials, user state or build products.

For this setup, the existing remote README heading and CI workflow were retained. The README was extended with project documentation. The branch's import-script fix was retained and improved. Git's normal push rejects a concurrent remote update; fetch and review before retrying.

## Outstanding validation

This Mac has only `/Library/Developer/CommandLineTools`; no full Xcode was found in `/Applications`. The attempted build exits 2 before compilation. Simulator/XCTest and real iPad/Pencil checks remain required. See `TEST_PLAN.md` for actual results. Do not merge or begin major features until native checks succeed.
