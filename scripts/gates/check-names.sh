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
# MUAFİYET — iki katman
#
# Politika dosyaları kuralın KENDİ metnini içerdikleri için kaçınılmaz olarak
# yanlış pozitif üretir (ör. yasaklı kalıpları listeleyen bir tablo).
#
#   1) Sabit muafiyet: temel yönetişim dosyaları
#   2) İşaretleyici muafiyeti: içinde POLICY_MARKER geçen her dosya
#
# İşaretleyici tercih edilir çünkü dosya kendi muafiyetini beyan eder ve bu
# beyan kod incelemesinde görünür. Sabit liste zamanla bayatlar.
# ---------------------------------------------------------------------------
POLICY_MARKER='gate-names:policy-doc'
EXCLUDE_RE='^(LEGAL\.md|AGENTS\.md|CLAUDE\.md|BLUEPRINT\.md|BOOT\.md|docs/blueprint/|scripts/gates/check-names\.sh|scripts/gates/_lib\.sh)'

ALL_FILES=$(tracked "" "$EXCLUDE_RE")

# İşaretleyici taşıyan dosyaları da çıkar
MARKED=$(grep_files "$ALL_FILES" -lF -e "$POLICY_MARKER" || true)
if [ -n "$MARKED" ]; then
  FILES=$(printf '%s\n' "$ALL_FILES" | grep -vxF "$(printf '%s\n' "$MARKED")" || true)
  note "politika işaretleyicisiyle muaf: $(printf '%s\n' "$MARKED" | grep -c .) dosya"
else
  FILES="$ALL_FILES"
fi
COUNT=$(printf '%s\n' "$FILES" | grep -c . || true)
note "taranan dosya: $COUNT"

if [ "$COUNT" -eq 0 ]; then
  warn "taranacak tracked dosya yok — 'git add' yapılmamış olabilir"
fi

# NOT: tüm metin taramalarında grep -I kullanılır — ikili dosyalar (PNG vb.)
# atlanır. Aksi halde rastgele bayt dizileri ™/® olarak eşleşiyor.
# ---------------------------------------------------------------------------
# 1. Karşılaştırmalı pazarlama kalıpları (Y6)
# ---------------------------------------------------------------------------
# Büyük/küçük harf DUYARSIZ kalıplar: bir ürün adının nasıl yazıldığından
# bağımsız olarak karşılaştırma yapan ifadeler.
COMPARATIVE_ANY='(alternative[[:space:]]+to|better[[:space:]]+than|replacement[[:space:]]+for|drop-in[[:space:]]+replacement|competitor|rakip[[:space:]]+(ürün|uygulama|yazılım)|alternatifidir|alternatifi[[:space:]]+olarak|yerine[[:space:]]+kullanılabilir|gibi[[:space:]]+ama)'

# Büyük harf DUYARLI kalıplar: burada büyük harf, bir ÜRÜN ADINI işaret eder.
# Bu ayrım şart — `grep -i` ile taransaydı [A-Z] şartı anlamsızlaşır ve
# "instead of returning", "instead of failing" gibi sıradan İngilizce de
# eşleşirdi. Gerçekten oldu.
COMPARATIVE_CASED='instead[[:space:]]+of[[:space:]]+[A-Z]'

COMP_FAIL=0
if HITS=$(grep_files "$FILES" -InEHi "$COMPARATIVE_ANY"); then
  fail "karşılaştırmalı pazarlama kalıbı bulundu (Y6)"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  COMP_FAIL=1
fi
if HITS=$(grep_files "$FILES" -InEH "$COMPARATIVE_CASED"); then
  fail "büyük harfli ürün adıyla karşılaştırma kalıbı (Y6)"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  COMP_FAIL=1
fi
[ "$COMP_FAIL" -eq 0 ] && ok "karşılaştırmalı pazarlama kalıbı yok"

# ---------------------------------------------------------------------------
# 2. Marka sembolü — üçüncü taraf marka referansının işareti
# ---------------------------------------------------------------------------
if HITS=$(grep_files "$FILES" -InH -e '™' -e '®'); then
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
ALLOWED='(apple\.com|developer\.apple\.com|support\.apple\.com|github\.com|githubusercontent\.com|swift\.org|opensource\.org|spdx\.org|keepachangelog\.com|semver\.org|contributor-covenant\.org|brew\.sh|conventionalcommits\.org|www\.apache\.org|apache\.org|www\.apple\.com|www\.contributor-covenant\.org|www\.w3\.org|w3\.org|localhost|127\.0\.0\.1|example\.org|example\.com|bubiapps\.com)'

if [ "$COUNT" -gt 0 ]; then
  URLS=$(grep_files "$FILES" -IohE 'https?://[a-zA-Z0-9._-]+' || true)
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
    if OUT=$(grep_files "$FILES" -InHiF -e "$name"); then
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
