#!/usr/bin/env bash
# ============================================================================
# Renames the product in one command (invariant K2: the name is not embedded
# in code).
#
#   scripts/rename-product.sh <NewName> [new.bundle.prefix]
#
# Places changed: project.yml, Info.plist properties (inside project.yml),
# the SharedIPC Mach service name, the localisation catalogue (if present).
# Code identifiers are NOT touched — the name is not embedded in code.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

NEW_NAME="${1:-}"
NEW_PREFIX="${2:-}"
[ -n "$NEW_NAME" ] || { echo "usage: $0 <NewName> [new.bundle.prefix]"; exit 1; }

OLD_NAME=$(grep -E '^\s+PRODUCT_NAME:' project.yml | head -1 | awk '{print $2}')
OLD_PREFIX=$(grep -E '^\s+BUNDLE_PREFIX:' project.yml | head -1 | awk '{print $2}')
[ -n "$NEW_PREFIX" ] || NEW_PREFIX="$(echo "$OLD_PREFIX" | sed "s/[^.]*$//")$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')"

echo "  $OLD_NAME  ->  $NEW_NAME"
echo "  $OLD_PREFIX  ->  $NEW_PREFIX"

FILES=$(git ls-files 'project.yml' '*.swift' '*.xcstrings' 'Makefile' 2>/dev/null)
for f in $FILES; do
  [ -f "$f" ] || continue
  # NOTE: BSD sed on macOS does NOT support the \b word boundary; it silently
  # matches nothing. The BSD syntax [[:<:]] and [[:>:]] is used instead.
  LC_ALL=C sed -i '' \
    -e "s/${OLD_PREFIX}/${NEW_PREFIX}/g" \
    -e "s/[[:<:]]${OLD_NAME}[[:>:]]/${NEW_NAME}/g" "$f"
done

echo "  ✓ done. Now: make generate && make check"
echo "  ! docs/ and the README need a manual pass — the name appears there on purpose."
