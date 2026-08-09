#!/usr/bin/env bash
# ============================================================================
# GATE: gate-a11y
# Enforces: docs/product/ui.md "Accessibility — not negotiable"
#   A1  every SF Symbol is named or explicitly hidden
#   A2  every Canvas and Chart carries a label
#   A3  no animation ignores Reduce Motion
#
# The checks themselves are Python, in check-a11y.py, for the same reason
# check-catalog.py is: they need to look at a window of lines around a match,
# and shell is the wrong instrument for that.
#
# Why not walk the accessibility tree instead — the stronger evidence anyone
# would reach for first: SwiftUI builds its accessibility nodes lazily, only
# when an accessibility client is attached. Reading our own tree in-process was
# probed three ways in P6.12 and returned nothing. Attaching a real client means
# the Accessibility permission, which I2 forbids. The reasoning is recorded in
# App/Sources/Helper/AccessibilityDrill.swift.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-a11y — accessibility labels, pictures and motion"
require_tools git python3

UI=$(tracked 'App/Sources/' | grep '\.swift$' || true)
COUNT=$(printf '%s\n' "$UI" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "no App/Sources Swift sources"
else
  python3 scripts/gates/check-a11y.py App/Sources || GATE_FAIL=1
fi

gate_result "gate-a11y"
