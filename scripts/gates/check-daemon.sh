#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-daemon
# Zorladığı değişmezler: ARCHITECTURE.md M4 (XPC yüzeyi), M5 (config okumaz),
#                        M6 (ağ yok), G5 (imza doğrulaması)
# ADR: 0007-privilege-split.md, 0008-smappservice-xpc.md
#
# Daemon root olarak çalışır. Yüzeyi ne kadar dar olursa saldırı yüzeyi o kadar
# küçüktür. Bu kapı, yüzeyin fark ettirmeden genişlemesini önler.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-daemon — ayrıcalıklı yüzey sınırları"
require_tools git grep awk sort xargs


# ---------------------------------------------------------------------------
# M4 — XPC protokolü yalnızca dört metot içerir
#
# Bu denetim daemon kaynağından BAĞIMSIZ çalışır: yüzey, protokol yazıldığı
# anda sınırlıdır. Daemon'un varlığını beklemek, yüzeyin fark edilmeden
# genişlemesine izin verirdi.
#
# Metot çıkarımı protokol GÖVDESİNDEN yapılır, dosyanın tamamından değil.
# Daha önce '^func' deseniyle taranıyordu; 'public func' yazılmış bir metodu
# kaçırıyordu ve aynı dosyadaki static yardımcıları yanlışlıkla sayabilirdi.
# ---------------------------------------------------------------------------
PROTO_FILE=$(tracked 'Packages/SharedIPC/Sources/' | grep '\.swift$' \
             | while read -r f; do grep -lq 'protocol FanControlProtocol' "$f" && echo "$f"; done)

if [ -z "$PROTO_FILE" ]; then
  skip "FanControlProtocol henüz yok — P3.01'de yazılacak"
else
  ALLOWED='^(describeFans|applyTargets|releaseToFirmware|heartbeat)$'
  METHODS=$(awk '
    /protocol[[:space:]]+FanControlProtocol/ { inside = 1 }
    inside && /^[[:space:]]*(public[[:space:]]+|static[[:space:]]+)*func[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/^(public[[:space:]]+|static[[:space:]]+)*func[[:space:]]+/, "", line)
      sub(/[(<].*$/, "", line)
      print line
    }
    inside && /^}/ { inside = 0 }
  ' "$PROTO_FILE" | sort -u)

  COUNT_M=$(printf '%s\n' "$METHODS" | grep -c . || true)
  EXTRA=$(printf '%s\n' "$METHODS" | grep . | grep -vE "$ALLOWED" || true)

  if [ -n "$EXTRA" ]; then
    fail "XPC yüzeyinde izinsiz metot (M4) — genişletmek ADR gerektirir:"
    printf '%s\n' "$EXTRA" | sed 's/^/      /'
  elif [ "$COUNT_M" -ne 4 ]; then
    fail "XPC yüzeyinde $COUNT_M metot var, 4 bekleniyor (M4)"
    printf '%s\n' "$METHODS" | sed 's/^/      /'
  else
    ok "XPC yüzeyi dört metotla sınırlı"
  fi
fi

DAEMON=$(tracked 'Daemon/' | grep '\.swift$' || true)
COUNT=$(printf '%s\n' "$DAEMON" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "Daemon kaynağı yok — P3'te oluşacak"
else
  note "taranan daemon dosyası: $COUNT"

  # -------------------------------------------------------------------------
  # M5 — daemon yapılandırma/dosya okumaz
  # -------------------------------------------------------------------------
  CONFIG_IO='(JSONDecoder|JSONSerialization|PropertyListDecoder|contentsOfFile|Data\(contentsOf:)'
  if HITS=$(grep_files "$DAEMON" -nHE "$CONFIG_IO"); then
    fail "daemon dosya/yapılandırma okuyor (M5)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon yapılandırma okumuyor"
  fi

  # -------------------------------------------------------------------------
  # M6 — daemon ağ kullanmaz
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(URLSession|import[[:space:]]+Network|NWConnection)'); then
    fail "daemon ağ API'si kullanıyor (M6)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon ağ kullanmıyor"
  fi

  # -------------------------------------------------------------------------
  # Alt süreç yasağı — ayrıcalık yükseltme riski
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(Process\(\)|posix_spawn|NSTask|execv)'); then
    fail "daemon alt süreç başlatıyor — ayrıcalık yükseltme riski"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon alt süreç başlatmıyor"
  fi

  # -------------------------------------------------------------------------
  # G5 — imza doğrulaması mevcut olmalı
  # -------------------------------------------------------------------------
  # setCodeSigningRequirement, macOS 13'ten beri bunun DESTEKLENEN yolu.
  # Elle SecCodeCheckValidity çağırmak da kabul ediliyor ama tercih değil:
  # bir güvenlik kararını Apple'ın zaten doğru yaptığı yerde yeniden yazmak
  # sahiplenilecek yeni bir hata yüzeyi demek.
  if grep_files "$DAEMON" -lE '(setCodeSigningRequirement|SecCodeCheckValidity|SecRequirementCreateWithString)' >/dev/null; then
    ok "XPC imza doğrulaması mevcut"
  else
    fail "XPC imza doğrulaması bulunamadı (G5)"
  fi
fi

gate_result "gate-daemon"
