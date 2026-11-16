#!/usr/bin/env bash
# Import the locally extracted Creative Moments Xcode project into its development branch.
# Does not modify main or force-push. Shows and confirms changes before the push.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH='chore/creative-moments-phase1-audit'
REMOTE='https://github.com/imanisworld/help-mom.git'

for tool in git rsync mktemp; do
  command -v "$tool" >/dev/null || { printf 'Missing command: %s\n' "$tool" >&2; exit 1; }
done

[[ -f "$ROOT/CreativeMoments.xcodeproj/project.pbxproj" ]] ||
  { echo 'STOP: CreativeMoments.xcodeproj not found. Run from the extracted Xcode project.' >&2; exit 1; }
[[ -f "$ROOT/CreativeMoments/CreativeMomentsApp.swift" ]] ||
  { echo 'STOP: App source code not found.' >&2; exit 1; }
for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
  [[ -f "$ROOT/CreativeMoments/Resources/Scenes/scene-$n.png" ]] ||
    { echo "STOP: Missing artwork scene-$n.png" >&2; exit 1; }
done
[[ -f "$ROOT/CreativeMoments/Assets.xcassets/AppIcon.appiconset/AppIcon.png" ]] ||
  { echo 'STOP: App icon missing.' >&2; exit 1; }

# The optional tree-sitter validator belongs to the original source package.
# It requires dependencies that are not necessary for importing source files.
# The project/artwork checks above are mandatory; native Xcode checks run in CI.
if [[ -f "$ROOT/Tools/validate_package.py" ]]; then
  if python3 -c 'import tree_sitter' >/dev/null 2>&1; then
    python3 "$ROOT/Tools/validate_package.py"
  else
    echo 'NOTICE: Optional tree-sitter package validation skipped (dependency absent).'
    echo 'The Xcode build and tests must pass before this branch is merged.'
  fi
fi

echo 'IMPORTANT: The GitHub repository is currently PUBLIC.'
echo 'This will publish the code and artwork to its DEVELOPMENT branch.'
printf 'Continue preparing a preview (no upload yet)? [y/N] '
read -r prepare
[[ "$prepare" == y || "$prepare" == Y ]] || { echo 'Canceled.'; exit 0; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone --quiet --single-branch --branch "$BRANCH" "$REMOTE" "$WORK/help-mom"

for name in CreativeMoments CreativeMoments.xcodeproj CreativeMomentsTests; do
  [[ -d "$ROOT/$name" ]] || { echo "STOP: Missing $name" >&2; exit 1; }
  rsync -a --exclude '.DS_Store' --exclude 'xcuserdata/' --exclude 'DerivedData/' \
    "$ROOT/$name/" "$WORK/help-mom/$name/"
done
for name in README.md AGENTS.md CLAUDE.md .gitignore; do
  if [[ -f "$ROOT/$name" ]]; then cp "$ROOT/$name" "$WORK/help-mom/$name"; fi
done
for name in Tools docs Submission; do
  if [[ -d "$ROOT/$name" ]]; then
    mkdir -p "$WORK/help-mom/$name"
    rsync -a --exclude '.DS_Store' "$ROOT/$name/" "$WORK/help-mom/$name/"
  fi
done

cd "$WORK/help-mom"
git add -A
git diff --cached --check
if git diff --cached --quiet; then
  echo 'No changes to import.'
  exit 0
fi
echo 'Files to commit:'
git diff --cached --stat
echo
printf 'Commit and PUSH these files to the development branch? [y/N] '
read -r approval
[[ "$approval" == y || "$approval" == Y ]] || { echo 'Canceled; no changes pushed.'; exit 0; }

git commit -m 'feat: import Creative Moments iOS project'
git push origin "$BRANCH"
echo "Import complete: https://github.com/imanisworld/help-mom/tree/$BRANCH"
echo 'Review GitHub Actions and do not merge until the iOS tests pass.'
