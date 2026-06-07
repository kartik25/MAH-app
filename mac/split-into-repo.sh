#!/usr/bin/env bash
#
# Assemble the standalone "notch-reader" repo from this monorepo's mac/ folder.
# (The CI integration in the cloud sandbox can't create repos or push outside
#  mah-app, so run this on your machine to do the split.)
#
# Usage:  mac/split-into-repo.sh [target-dir]      (default: ../notch-reader)
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"     # .../mac
ROOT="$(cd "$SRC/.." && pwd)"            # repo root (contains index.html)
DEST="${1:-$ROOT/../notch-reader}"

mkdir -p "$DEST/NotchReader"
cp "$SRC"/NotchReader/* "$DEST/NotchReader/"
cp "$SRC/README.md"      "$DEST/README.md"
cp "$ROOT/index.html"    "$DEST/index.html"      # vendored: now the single source here

# Standalone project.yml: index.html lives at the repo root, not ../
sed 's#\.\./index.html#index.html#' "$SRC/project.yml" > "$DEST/project.yml"

cd "$DEST"
git init -q
git add .
git commit -q -m "Initial commit: NotchReader macOS teleprompter wrapper"

cat <<EOF

Standalone repo assembled at: $DEST

Next (create the empty private repo on github.com first, then):
  git -C "$DEST" remote add origin git@github.com:kartik25/notch-reader.git
  git -C "$DEST" branch -M main
  git -C "$DEST" push -u origin main
EOF
