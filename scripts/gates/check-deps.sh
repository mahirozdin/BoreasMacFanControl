#!/usr/bin/env bash
# ============================================================================
# GATE: gate-deps
# Enforces: AGENTS.md T4 (zero dependencies), H5 (licence compatibility)
# ADR: 0013-json-config-zero-deps.md, 0005-apache-2-license.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-deps — dependencies and licence compatibility"
require_tools git grep xargs

# ---------------------------------------------------------------------------
# T4 — no external dependency inside Package.swift
# ---------------------------------------------------------------------------
MANIFESTS=$(tracked 'Package.swift **/Package.swift')
HAS_DEPS=0

if [ -z "$MANIFESTS" ]; then
  skip "no Package.swift — arrives in P1"
else
  note "manifests scanned: $(printf '%s\n' "$MANIFESTS" | grep -c .)"
  if HITS=$(grep_files "$MANIFESTS" -nHE '\.package\(url:'); then
    HAS_DEPS=1
    fail "external dependency found (T4 — zero runtime dependencies)"
    printf '%s\n' "$HITS" | sed 's/^/      /'
    note "if it is truly necessary, write an ADR and add it to NOTICE"
  else
    ok "no external dependencies"
  fi
fi

# ---------------------------------------------------------------------------
# H5 — forbidden licence traces
# ---------------------------------------------------------------------------
LICENSE_EXCLUDE='^(LEGAL\.md|AGENTS\.md|BLUEPRINT\.md|BOOT\.md|docs/blueprint/|docs/architecture/adr/0005-|scripts/gates/check-deps\.sh)'
ALL=$(tracked "" "$LICENSE_EXCLUDE")
BANNED_LICENSE='(GNU GENERAL PUBLIC LICENSE|GNU LESSER GENERAL PUBLIC|GNU AFFERO|SPDX-License-Identifier:[[:space:]]*(GPL|LGPL|AGPL|SSPL))'

if [ -n "$ALL" ]; then
  if HITS=$(grep_files "$ALL" -lE "$BANNED_LICENSE"); then
    fail "forbidden licence trace (H5) — GPL/LGPL/AGPL/SSPL is not acceptable:"
    printf '%s\n' "$HITS" | sed 's/^/      /'
  else
    ok "no forbidden licence traces"
  fi
fi

# ---------------------------------------------------------------------------
# If there are dependencies, NOTICE is mandatory
# ---------------------------------------------------------------------------
if [ "$HAS_DEPS" -eq 1 ] && [ ! -f NOTICE ]; then
  fail "dependencies exist but there is no NOTICE file"
fi

gate_result "gate-deps"
