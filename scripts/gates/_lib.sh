#!/usr/bin/env bash
# ============================================================================
# Kapı script'leri için ortak yardımcılar.
#
# UYUMLULUK NOTU — ÖNEMLİ:
#   macOS /bin/bash sürümü 3.2.57'dir (lisans nedeniyle Apple güncellemiyor).
#   Bash 4+ özellikleri KULLANILMAZ: mapfile/readarray, ${x,,}, ${x^^},
#   ilişkisel diziler (declare -A), ${!x[@]} üzerinde string anahtar.
#
#   Bu kural gerçek bir hatadan doğdu: kapılar `mapfile` kullanıyordu, komut
#   bulunamıyordu, tarama hiç çalışmıyordu ve kapı yine de PASS veriyordu.
#   Klasik "sahte kapı". Aşağıdaki require_bash_features bunu tekrarlanamaz
#   kılar: eksik bir yetenek varsa kapı sessizce geçmek yerine kırmızıya döner.
# ============================================================================

# Kapı sonucu
GATE_FAIL=0

ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; GATE_FAIL=1; }
warn() { printf '  ! %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
skip() { printf '  ○ SKIP: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Kapının çalışması için gereken dış komutlar mevcut mu.
# Eksikse kapı PASS veremez — sessiz geçiş yasaktır.
# ---------------------------------------------------------------------------
require_tools() {
  local missing=""
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  if [ -n "$missing" ]; then
    printf '  ✗ gerekli komut eksik:%s\n' "$missing"
    printf '    Kapı doğrulama yapamaz. Sessiz geçiş yasak.\n'
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Tracked dosya listesi (newline ayrılmış). İsteğe bağlı hariç tutma regex'i.
# Bash 3.2 uyumlu: dizi yerine newline ayrılmış string döner.
# ---------------------------------------------------------------------------
tracked() {
  local pattern="${1:-}"
  local exclude="${2:-}"
  local out
  if [ -n "$pattern" ]; then
    out=$(git ls-files -- $pattern 2>/dev/null || true)
  else
    out=$(git ls-files 2>/dev/null || true)
  fi
  if [ -n "$exclude" ]; then
    out=$(printf '%s\n' "$out" | grep -vE "$exclude" || true)
  fi
  printf '%s' "$out" | grep -c . >/dev/null 2>&1
  printf '%s\n' "$out" | grep . || true
}

# ---------------------------------------------------------------------------
# Dosya listesi üzerinde grep. Liste boşsa grep ÇALIŞTIRILMAZ
# (aksi halde stdin'den okur ve asılır / yanlış sonuç verir).
# Kullanım: grep_files "<dosya listesi>" "<grep bayrakları>" "<desen>"
# Çıktı: eşleşmeler (varsa). Dönüş: 0 = eşleşme var, 1 = yok.
# ---------------------------------------------------------------------------
grep_files() {
  local files="$1"; shift
  [ -n "$files" ] || return 1
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep "$@" 2>/dev/null
}

gate_result() {
  local name="$1"
  echo
  if [ "$GATE_FAIL" -eq 0 ]; then
    echo "✓ $name PASS"
  else
    echo "✗ $name FAIL"
  fi
  return "$GATE_FAIL"
}
