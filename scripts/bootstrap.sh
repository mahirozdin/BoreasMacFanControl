#!/usr/bin/env bash
# ============================================================================
# Boreas — yerel geliştirme ortamı kurulumu ve doğrulaması
#
# Idempotenttir: kaç kez çalıştırılırsa çalıştırılsın aynı sonucu verir,
# hiçbir şeyi silmez, var olanı yeniden kurmaz.
#
# TASARIM NOTU — araçları "var mı" değil "çalışıyor mu" diye kontrol eder.
# Bozuk bir global kurulum sessizce durabilir; `command -v` onu yakalamaz,
# `--version` yakalar. Bu, sahada gerçekten karşılaşılmış bir tuzaktır.
#
# Çıkış kodu: 0 = ortam hazır, 1 = eksik/bozuk var (her biri raporlanır)
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

printf '\033[1mBoreas — ortam kontrolü\033[0m\n'

# ---------------------------------------------------------------------------
head_ "Platform"
# ---------------------------------------------------------------------------
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ok "mimari: arm64"
else
  bad "mimari: $ARCH — Boreas yalnızca Apple Silicon hedefler (ADR 0004)"
fi

OSV=$(sw_vers -productVersion)
OSMAJ=${OSV%%.*}
if [ "$OSMAJ" -ge 14 ]; then
  ok "macOS $OSV (minimum 14.0)"
else
  bad "macOS $OSV — minimum 14.0 gerekli (ADR 0003)"
fi

# ---------------------------------------------------------------------------
head_ "Araçlar"   # var mı DEĞİL, çalışıyor mu
# ---------------------------------------------------------------------------
# check_tool <görünen ad> <ipucu> -- <komut> [arg...]
#
# Komut ARGÜMAN OLARAK geçilir, tek bir string olarak değil. Bir string'i
# `$cmd` ile açmak kabuğa göre farklı davranıyor (zsh varsayılan olarak
# kelime ayırması yapmaz) ve komut "xcodebuild -version" tek bir isim gibi
# aranıp "command not found" veriyordu — kontrol, sağlıklı bir Xcode'u
# bozuk sanıyordu.
check_tool() {
  local name="$1" hint="$2"; shift 3   # 3. argüman "--" ayıracı
  if ! command -v "$1" >/dev/null 2>&1; then
    bad "$name yok — çözüm: $hint"
    return
  fi
  local out
  out=$("$@" 2>&1 | head -1)
  if [ -n "$out" ]; then
    ok "$name — $out"
  else
    bad "$name kurulu ama ÇALIŞMIYOR (boş çıktı) — çözüm: $hint"
  fi
}

check_tool "Xcode"        "App Store'dan Xcode 26+ kur"                 -- xcodebuild -version
check_tool "Swift"        "Xcode kurulumu bozuk: xcode-select --install" -- swift --version
check_tool "swift format" "Swift 6.2+ gerekli (araç zincirine yerleşik)" -- swift format --version
check_tool "XcodeGen"     "brew bundle"                                  -- xcodegen --version
check_tool "SwiftLint"    "brew bundle"                                  -- swiftlint --version
check_tool "xcbeautify"   "brew bundle"                                  -- xcbeautify --version
check_tool "Python 3"     "kapı script'leri için gerekli"                -- python3 --version

# Swift sürümü 6.2+ mi
SWV=$(swift --version 2>/dev/null | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ -n "$SWV" ]; then
  MAJ=${SWV%%.*}; MIN=${SWV##*.}
  if [ "$MAJ" -gt 6 ] || { [ "$MAJ" -eq 6 ] && [ "$MIN" -ge 2 ]; }; then
    ok "Swift $SWV (minimum 6.2)"
  else
    bad "Swift $SWV — minimum 6.2 gerekli (değişmez T1)"
  fi
fi

# ---------------------------------------------------------------------------
head_ "Depo"
# ---------------------------------------------------------------------------
[ -d .git ] && ok "git deposu" || bad "git deposu değil"
[ -f BLUEPRINT.md ] && ok "blueprint yerinde" || bad "BLUEPRINT.md yok — yanlış dizin?"
[ -f LICENSE ] && ok "LICENSE yerinde" || bad "LICENSE yok"

if git ls-files 2>/dev/null | grep -qE '\.(p12|p8|mobileprovision|provisionprofile)$'; then
  bad "İMZALAMA MATERYALİ DEPODA — derhal kaldır"
else
  ok "gizli materyal yok"
fi

# ---------------------------------------------------------------------------
head_ "Kapılar"
# ---------------------------------------------------------------------------
if make check >/tmp/boreas-bootstrap-gates.log 2>&1; then
  ok "make check — 8/8 PASS"
else
  bad "make check başarısız — ayrıntı: /tmp/boreas-bootstrap-gates.log"
  grep -E '^  ✗' /tmp/boreas-bootstrap-gates.log | head -5 | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
head_ "Sıradaki iş"
# ---------------------------------------------------------------------------
if scripts/next-task.py >/tmp/boreas-next.log 2>&1; then
  sed 's/^/  /' /tmp/boreas-next.log
else
  warn "yapılabilir iş yok:"
  sed 's/^/      /' /tmp/boreas-next.log
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m✓ Ortam hazır.\033[0m  Başlamak için: make next\n\n'
else
  printf '\033[31m✗ Eksikler var.\033[0m  Yukarıdaki çözümleri uygula ve tekrar çalıştır.\n\n'
fi
exit "$FAIL"
