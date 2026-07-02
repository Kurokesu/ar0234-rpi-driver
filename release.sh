#!/bin/bash
# Thin launcher for the canonical release script in Kurokesu/ci.
# REF must match the @ref in the release.yml/ci.yml shims.
set -euo pipefail

REF=main

SHA=$(git ls-remote https://github.com/Kurokesu/ci.git "refs/heads/$REF" | cut -f1)
[ -n "$SHA" ] || { echo "ERROR: cannot resolve '$REF' on Kurokesu/ci." >&2; exit 1; }
echo "release-dkms.sh @ $REF (${SHA:0:12})"

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
curl -fsSL "https://raw.githubusercontent.com/Kurokesu/ci/$SHA/scripts/release-dkms.sh" -o "$TMP"
bash "$TMP" "$@"
