#!/usr/bin/env bash
# ============================================================================
# Ürün adını tek komutla değiştirir (değişmez K2: ad koda gömülmez).
#
#   scripts/rename-product.sh <YeniAd> [yeni.bundle.prefix]
#
# Değiştirilen yerler: project.yml, Info.plist özellikleri (project.yml içinde),
# SharedIPC Mach servis adı, yerelleştirme kataloğu (varsa).
# Kod tanımlayıcıları DEĞİŞMEZ — ad zaten koda gömülü değil.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

NEW_NAME="${1:-}"
NEW_PREFIX="${2:-}"
[ -n "$NEW_NAME" ] || { echo "kullanım: $0 <YeniAd> [yeni.bundle.prefix]"; exit 1; }

OLD_NAME=$(grep -E '^\s+PRODUCT_NAME:' project.yml | head -1 | awk '{print $2}')
OLD_PREFIX=$(grep -E '^\s+BUNDLE_PREFIX:' project.yml | head -1 | awk '{print $2}')
[ -n "$NEW_PREFIX" ] || NEW_PREFIX="$(echo "$OLD_PREFIX" | sed "s/[^.]*$//")$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')"

echo "  $OLD_NAME  ->  $NEW_NAME"
echo "  $OLD_PREFIX  ->  $NEW_PREFIX"

FILES=$(git ls-files 'project.yml' '*.swift' '*.xcstrings' 'Makefile' 2>/dev/null)
for f in $FILES; do
  [ -f "$f" ] || continue
  # NOT: macOS'ta BSD sed \b kelime sınırını DESTEKLEMEZ; sessizce hiçbir şey
  # eşleştirmez. BSD sözdizimi [[:<:]] ve [[:>:]] kullanılır.
  LC_ALL=C sed -i '' \
    -e "s/${OLD_PREFIX}/${NEW_PREFIX}/g" \
    -e "s/[[:<:]]${OLD_NAME}[[:>:]]/${NEW_NAME}/g" "$f"
done

echo "  ✓ tamamlandı. Şimdi: make generate && make check"
echo "  ! docs/ ve README elle gözden geçirilmeli — orada ad bilinçli olarak geçiyor."
