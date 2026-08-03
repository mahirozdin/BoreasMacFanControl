#!/usr/bin/env python3
"""
Sıradaki yapılabilir atomik işi TODO.md'den deterministik olarak seçer.

NEDEN BU SCRIPT VAR
    Seçim algoritması dokümanda düz metin olarak durduğu sürece model yorumuna
    kalıyor ve bir iş manuel blokaja takıldığında oturum durabiliyor. Bu script
    seçimi makineye devrediyor: manuel işe bağlı HER iş atlanır ve bir sonraki
    yapılabilir iş döner — faz sınırı fark etmeksizin.

SÖZLEŞME
    Atomik iş satırı:   - [ ] **P<n>.<nn> — Başlık.** açıklama
    Manuel blokaj:      satır sonunda  ⛔ M03  (birden fazla: ⛔ M03 M04)
    Faz bağımlılığı:    - **Bağımlılık:** P1, P2      (fazın kendi bloğunda)
    Manuel iş durumu:   | M03 | ... | OPEN |   ->  OPEN dışındaki her şey çözülmüş sayılır

BİR İŞ YAPILABİLİR SAYILIR EĞER
    1. işaretlenmemişse           - [ ]
    2. bağlı olduğu manuel işlerin hepsi çözülmüşse (veya hiç bağlı değilse)
    3. fazının bağımlılıklarındaki tüm işler bitmişse

Çıktı: seçilen iş + gerekçe. Yapılabilir iş yoksa neyin beklendiğini söyler.
Çıkış kodu: 0 = iş var, 1 = yapılabilir iş yok, 2 = ayrıştırma hatası
"""
import os
import re
import sys
import pathlib

# TODO_PATH ile değiştirilebilir — kapı testleri için gerekli
TODO = pathlib.Path(
    os.environ.get("TODO_PATH")
    or pathlib.Path(__file__).resolve().parent.parent / "TODO.md"
)

TASK_RE = re.compile(r"^- \[( |x)\] \*\*(P\d+)\.(\d+)\s*—\s*(.+?)\*\*(.*)$")
PHASE_RE = re.compile(r"^## (P\d+) — (.+)$")
DEP_RE = re.compile(r"^- \*\*Bağımlılık:\*\*\s*(.*)$")
MANUAL_RE = re.compile(r"^\|\s*(M\d+)\s*\|.*\|\s*(.+?)\s*\|\s*$")
BLOCK_RE = re.compile(r"⛔\s*((?:M\d+[\s,]*)+)")


def parse():
    if not TODO.exists():
        print(f"HATA: {TODO} bulunamadı", file=sys.stderr)
        sys.exit(2)
    lines = TODO.read_text(encoding="utf-8").split("\n")

    manual = {}
    phases = {}          # "P1" -> {"theme":..., "deps":[...], "tasks":[...]}
    order = []
    current = None
    in_manual = False

    for raw in lines:
        line = raw.rstrip()

        if line.startswith("## ") and "Manuel işler" in line:
            in_manual = True
            current = None
            continue
        if in_manual and line.startswith("## "):
            in_manual = False

        if in_manual:
            m = MANUAL_RE.match(line)
            if m and m.group(1) != "#":
                manual[m.group(1)] = m.group(2)
            continue

        m = PHASE_RE.match(line)
        if m:
            current = m.group(1)
            if current not in phases:
                phases[current] = {"theme": m.group(2), "deps": [], "tasks": []}
                order.append(current)
            continue

        if current:
            m = DEP_RE.match(line)
            if m:
                phases[current]["deps"] = re.findall(r"P\d+", m.group(1))
                continue

            m = TASK_RE.match(line)
            if m:
                done = m.group(1) == "x"
                tid = f"{m.group(2)}.{m.group(3)}"
                blockers = []
                b = BLOCK_RE.search(m.group(5) or "")
                if b:
                    blockers = re.findall(r"M\d+", b.group(1))
                phases[current]["tasks"].append(
                    {"id": tid, "done": done, "title": m.group(4).strip(), "blockers": blockers}
                )

    return manual, phases, order


def manual_open(mid, manual):
    """Manuel iş hâlâ bekliyor mu? Bilinmeyen id güvenli tarafta 'bekliyor' sayılır."""
    status = manual.get(mid)
    if status is None:
        return True
    s = status.upper()
    return "OPEN" in s and "DONE" not in s


def phase_complete(pid, phases):
    p = phases.get(pid)
    if not p:
        return True
    return all(t["done"] for t in p["tasks"])


def main():
    manual, phases, order = parse()
    if not phases:
        print("HATA: TODO.md içinde faz bulunamadı", file=sys.stderr)
        sys.exit(2)

    skipped = []
    waiting_on_phase = []

    for pid in order:
        p = phases[pid]
        unmet = [d for d in p["deps"] if not phase_complete(d, phases)]
        if unmet:
            pending = [t for t in p["tasks"] if not t["done"]]
            if pending:
                waiting_on_phase.append((pid, unmet))
            continue

        for t in p["tasks"]:
            if t["done"]:
                continue
            open_blockers = [b for b in t["blockers"] if manual_open(b, manual)]
            if open_blockers:
                skipped.append((t["id"], t["title"], open_blockers))
                continue

            print(f"SIRADAKİ İŞ: {t['id']}")
            print(f"  Faz    : {pid} — {p['theme']}")
            print(f"  Başlık : {t['title']}")
            if skipped:
                print(f"  Atlandı: {len(skipped)} iş manuel blokaj bekliyor")
                for sid, stitle, sb in skipped[:5]:
                    print(f"           {sid} ⛔ {' '.join(sb)} — {stitle[:52]}")
            sys.exit(0)

    # Yapılabilir iş kalmadı
    print("YAPILABİLİR İŞ YOK")
    if skipped:
        print(f"\n  {len(skipped)} iş manuel blokaj bekliyor:")
        for sid, stitle, sb in skipped:
            print(f"    {sid} ⛔ {' '.join(sb)} — {stitle[:60]}")
        need = sorted({b for _, _, bs in skipped for b in bs})
        print(f"\n  Çözülmesi gereken manuel işler: {', '.join(need)}")
    if waiting_on_phase:
        print("\n  Faz bağımlılığı bekleyenler:")
        for pid, unmet in waiting_on_phase:
            print(f"    {pid} <- {', '.join(unmet)}")
    if not skipped and not waiting_on_phase:
        print("\n  Tüm işler tamamlanmış görünüyor.")
    sys.exit(1)


if __name__ == "__main__":
    main()
