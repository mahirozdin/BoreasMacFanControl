#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-deps
# Zorladığı değişmezler: AGENTS.md T4 (sıfır bağımlılık), H5 (lisans uyumu)
# ADR: 0013-json-config-zero-deps.md, 0005-apache-2-license.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-deps — bağımlılık ve lisans uyumu"
require_tools git grep xargs

# ---------------------------------------------------------------------------
# T4 — Package.swift içinde harici bağımlılık olmamalı
# ---------------------------------------------------------------------------
MANIFESTS=$(tracked 'Package.swift **/Package.swift')
HAS_DEPS=0

if [ -z "$MANIFESTS" ]; then
  skip "Package.swift yok — P1'de oluşacak"
else
  note "taranan manifest: $(printf '%s\n' "$MANIFESTS" | grep -c .)"
  if HITS=$(grep_files "$MANIFESTS" -nHE '\.package\(url:'); then
    HAS_DEPS=1
    fail "harici bağımlılık bulundu (T4 — sıfır çalışma zamanı bağımlılığı)"
    printf '%s\n' "$HITS" | sed 's/^/      /'
    note "gerçekten gerekliyse ADR yaz ve NOTICE'a ekle"
  else
    ok "harici bağımlılık yok"
  fi
fi

# ---------------------------------------------------------------------------
# H5 — yasaklı lisans izi
# ---------------------------------------------------------------------------
LICENSE_EXCLUDE='^(LEGAL\.md|AGENTS\.md|BLUEPRINT\.md|BOOT\.md|docs/blueprint/|docs/architecture/adr/0005-|scripts/gates/check-deps\.sh)'
ALL=$(tracked "" "$LICENSE_EXCLUDE")
BANNED_LICENSE='(GNU GENERAL PUBLIC LICENSE|GNU LESSER GENERAL PUBLIC|GNU AFFERO|SPDX-License-Identifier:[[:space:]]*(GPL|LGPL|AGPL|SSPL))'

if [ -n "$ALL" ]; then
  if HITS=$(grep_files "$ALL" -lE "$BANNED_LICENSE"); then
    fail "yasaklı lisans izi (H5) — GPL/LGPL/AGPL/SSPL kabul edilmez:"
    printf '%s\n' "$HITS" | sed 's/^/      /'
  else
    ok "yasaklı lisans izi yok"
  fi
fi

# ---------------------------------------------------------------------------
# Bağımlılık varsa NOTICE zorunlu
# ---------------------------------------------------------------------------
if [ "$HAS_DEPS" -eq 1 ] && [ ! -f NOTICE ]; then
  fail "bağımlılık var ama NOTICE dosyası yok"
fi

gate_result "gate-deps"
