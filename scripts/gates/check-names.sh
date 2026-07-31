#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-names
# Zorladığı değişmezler: AGENTS.md §2.1 H1, H4  ·  LEGAL.md Y5, Y6
# ADR: docs/architecture/adr/0006-independent-development-policy.md
#
# NEDEN AD LİSTESİ YOK:
#   Yasaklı ürün adlarını bu dosyada saklamak, yasağın kendisini ihlal ederdi —
#   o adlar depoya girmiş olurdu. Bu yüzden kapı, ad gerektirmeyen üç katman
#   kullanır: karşılaştırmalı pazarlama kalıpları, dış alan adı allowlist'i ve
#   marka sembolü taraması. Kalan boşluk PR beyanı + insan incelemesiyle
#   kapatılır. Bkz. LEGAL.md §5.2.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-names — üçüncü taraf ürün adı / karşılaştırmalı pazarlama"
require_tools git grep sed sort xargs

# ---------------------------------------------------------------------------
# Politika dosyaları taramadan muaftır: kuralın KENDİ metnini içerdikleri için
# kaçınılmaz olarak yanlış pozitif üretirler.
# ---------------------------------------------------------------------------
EXCLUDE_RE='^(LEGAL\.md|AGENTS\.md|CLAUDE\.md|BLUEPRINT\.md|BOOT\.md|docs/blueprint/|docs/architecture/adr/0006-|docs/reference/blueprint-map\.md|scripts/gates/check-names\.sh|scripts/gates/_lib\.sh|\.github/PULL_REQUEST_TEMPLATE\.md)'

FILES=$(tracked "" "$EXCLUDE_RE")
COUNT=$(printf '%s\n' "$FILES" | grep -c . || true)
note "taranan dosya: $COUNT"

if [ "$COUNT" -eq 0 ]; then
  warn "taranacak tracked dosya yok — 'git add' yapılmamış olabilir"
fi

# ---------------------------------------------------------------------------
# 1. Karşılaştırmalı pazarlama kalıpları (Y6)
# ---------------------------------------------------------------------------
COMPARATIVE='(alternative[[:space:]]+to|better[[:space:]]+than|instead[[:space:]]+of[[:space:]]+[A-Z]|replacement[[:space:]]+for|drop-in[[:space:]]+replacement|competitor|rakip[[:space:]]+(ürün|uygulama|yazılım)|alternatifidir|alternatifi[[:space:]]+olarak|yerine[[:space:]]+kullanılabilir|gibi[[:space:]]+ama)'

if HITS=$(grep_files "$FILES" -nEHi "$COMPARATIVE"); then
  fail "karşılaştırmalı pazarlama kalıbı bulundu (Y6)"
  printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
else
  ok "karşılaştırmalı pazarlama kalıbı yok"
fi

# ---------------------------------------------------------------------------
# 2. Marka sembolü — üçüncü taraf marka referansının işareti
# ---------------------------------------------------------------------------
if HITS=$(grep_files "$FILES" -nH -e '™' -e '®'); then
  fail "marka sembolü (™/®) bulundu — üçüncü taraf marka referansı olabilir"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
else
  ok "marka sembolü yok"
fi

# ---------------------------------------------------------------------------
# 3. Dış alan adı allowlist'i
#    Ad listesi tutmadan üçüncü taraf ürün referansını yakalamanın yolu:
#    izinli olmayan her dış alan adı insan incelemesi ister.
# ---------------------------------------------------------------------------
ALLOWED='(apple\.com|developer\.apple\.com|support\.apple\.com|github\.com|githubusercontent\.com|swift\.org|opensource\.org|spdx\.org|keepachangelog\.com|semver\.org|contributor-covenant\.org|brew\.sh|conventionalcommits\.org|localhost|127\.0\.0\.1|example\.org|example\.com|bubiapps\.com)'

if [ "$COUNT" -gt 0 ]; then
  URLS=$(grep_files "$FILES" -ohE 'https?://[a-zA-Z0-9._-]+' || true)
  UNKNOWN=$(printf '%s\n' "$URLS" | sed -E 's#https?://##' | grep . | sort -u \
            | grep -vE "^${ALLOWED}$" || true)
  if [ -n "$UNKNOWN" ]; then
    fail "allowlist dışı dış alan adı — insan incelemesi gerekli:"
    printf '%s\n' "$UNKNOWN" | sed 's/^/      /'
    note "izinliyse bu script'teki ALLOWED listesine ekle"
  else
    ok "tüm dış alan adları allowlist'te"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Yerel ad listesi (opsiyonel, .gitignore'da)
# ---------------------------------------------------------------------------
LOCAL_LIST="scripts/gates/.forbidden-names.local"
if [ -f "$LOCAL_LIST" ]; then
  HITS_FOUND=0
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    if OUT=$(grep_files "$FILES" -nHiF -e "$name"); then
      HITS_FOUND=1
      printf '%s\n' "$OUT" | head -5 | sed 's/^/      /'
    fi
  done < "$LOCAL_LIST"
  if [ "$HITS_FOUND" -eq 1 ]; then
    fail "yerel yasaklı ad listesinden eşleşme bulundu (Y5)"
  else
    ok "yerel ad listesi: eşleşme yok"
  fi
else
  note "yerel ad listesi yok — opsiyonel, bkz. LEGAL.md §5.2"
fi

gate_result "gate-names"
