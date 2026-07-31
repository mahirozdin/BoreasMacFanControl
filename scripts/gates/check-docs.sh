#!/usr/bin/env bash
# ============================================================================
# KAPI: docs-check
# Zorladığı kural: AGENTS.md §7 doküman güncelleme protokolü
# Denetimler:
#   1. Kırık göreli markdown linkleri
#   2. İzlenebilirlik matrisindeki her hedefin gerçekten var olması
#   3. ADR dosyaları  ==  ADR indeksi  ==  ARCHITECTURE.md tablosu
#   4. Dokümandaki make komutları == Makefile hedefleri
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

FAIL=0
ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; FAIL=1; }

echo "▶ docs-check — doküman bütünlüğü"

# ---------------------------------------------------------------------------
# 1. Kırık göreli linkler
# ---------------------------------------------------------------------------
BROKEN=""
while IFS= read -r md; do
  [ -f "$md" ] || continue
  dir=$(dirname "$md")
  # [metin](hedef) → hedef; http(s), mailto ve #anchor hariç
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    case "$target" in http*|mailto:*|\#*) continue ;; esac
    clean=${target%%#*}
    [ -z "$clean" ] && continue
    if [ ! -e "$dir/$clean" ] && [ ! -e "$clean" ]; then
      BROKEN+="    $md → $clean"$'\n'
    fi
  done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//')
done < <(git ls-files '*.md' 2>/dev/null)

if [ -n "$BROKEN" ]; then
  fail "kırık göreli link:"
  printf '%s' "$BROKEN"
else
  ok "kırık göreli link yok"
fi

# ---------------------------------------------------------------------------
# 2. İzlenebilirlik matrisi hedefleri
# ---------------------------------------------------------------------------
MAP="docs/reference/blueprint-map.md"
if [ -f "$MAP" ]; then
  MISSING=""
  while IFS= read -r t; do
    [ -e "$t" ] || MISSING+="    $t"$'\n'
  done < <(grep -oE '`(docs/[^`]+\.md|[A-Z_]+\.md)`' "$MAP" 2>/dev/null | tr -d '`' | sort -u)
  if [ -n "$MISSING" ]; then
    fail "izlenebilirlik matrisinde var olmayan hedef:"
    printf '%s' "$MISSING"
  else
    ok "izlenebilirlik matrisi hedefleri mevcut"
  fi

  # Kayıp bölüm kontrolü
  if grep -qiE '^\|.*\|[[:space:]]*(—|-|yok|KAYIP)[[:space:]]*\|' "$MAP"; then
    fail "izlenebilirlik matrisinde eşlenmemiş bölüm var (kayıp = 0 olmalı)"
  else
    ok "eşlenmemiş blueprint bölümü yok"
  fi
else
  fail "$MAP bulunamadı"
fi

# ---------------------------------------------------------------------------
# 3. ADR üçlü senkronu
# ---------------------------------------------------------------------------
ADR_DIR="docs/architecture/adr"
if [ -d "$ADR_DIR" ]; then
  FILES=$(find "$ADR_DIR" -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; | sed -E 's/^([0-9]{4}).*/\1/' | sort -u)
  IDX=$(grep -oE '\[?[0-9]{4}\]?\([^)]*\)|\b[0-9]{4}-[a-z0-9-]+\.md' "$ADR_DIR/README.md" 2>/dev/null \
        | grep -oE '[0-9]{4}' | sort -u)
  ARCH=$(grep -oE 'adr/[0-9]{4}-[a-z0-9-]+\.md' ARCHITECTURE.md 2>/dev/null \
        | grep -oE '[0-9]{4}' | sort -u)

  if [ "$FILES" = "$IDX" ]; then
    ok "ADR dosyaları == ADR indeksi ($(echo "$FILES" | grep -c . ) adet)"
  else
    fail "ADR dosyaları ile indeks uyuşmuyor"
    printf '      dosyalar: %s\n' "$(echo $FILES)"
    printf '      indeks:   %s\n' "$(echo $IDX)"
  fi

  if [ "$FILES" = "$ARCH" ]; then
    ok "ADR dosyaları == ARCHITECTURE.md tablosu"
  else
    fail "ADR dosyaları ile ARCHITECTURE.md tablosu uyuşmuyor"
    printf '      dosyalar:        %s\n' "$(echo $FILES)"
    printf '      ARCHITECTURE.md: %s\n' "$(echo $ARCH)"
  fi
else
  fail "$ADR_DIR bulunamadı"
fi

# ---------------------------------------------------------------------------
# 4. Dokümandaki make komutları Makefile'da var mı
# ---------------------------------------------------------------------------
# Dondurulmuş blueprint bu denetimin dışındadır: planlanan (henüz yazılmamış)
# hedefleri tarif eder, mevcut durumu değil.
if [ -f Makefile ]; then
  MISSING=""
  while IFS= read -r tgt; do
    grep -qE "^${tgt}:" Makefile || MISSING+="    make $tgt"$'\n'
  done < <(git ls-files '*.md' 2>/dev/null \
           | grep -vE '^(BLUEPRINT\.md|docs/blueprint/)' \
           | tr '\n' '\0' | xargs -0 grep -ohE '\bmake [a-z][a-z0-9-]*' 2>/dev/null \
           | awk '{print $2}' | sort -u)
  if [ -n "$MISSING" ]; then
    fail "dokümanda geçen ama Makefile'da olmayan hedef:"
    printf '%s' "$MISSING"
  else
    ok "dokümandaki make hedefleri Makefile ile tutarlı"
  fi
fi

echo
[ "$FAIL" -eq 0 ] && echo "✓ docs-check PASS" || echo "✗ docs-check FAIL"
exit "$FAIL"
