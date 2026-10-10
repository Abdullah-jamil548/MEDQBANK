"""Find past-paper PDFs that are true A-E MCQs with near-native text (~99%)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

import fitz

ROOT = Path(r"D:\Past papers-20261005T064648Z-1-001\Past papers")
# Already imported / handled
DONE = {
    "Embryology past papers MCQs(0)_102030.pdf",
    "Anatomy topic wise past papers.pdf",
}


def analyze(pdf: Path) -> dict:
    doc = fitz.open(pdf)
    n = doc.page_count
    idxs = sorted({0, min(1, n - 1), n // 2, max(0, n - 1)})[:5]
    chars = opts = qs = ans = seq = 0
    snip = ""
    for i in idxs:
        t = doc[i].get_text("text") or ""
        chars += len(t.strip())
        opts += len(re.findall(r"(?m)^\s*[A-Ea-e][\.\)]\s+\S+", t))
        qs += len(re.findall(r"(?m)^\s*\(?\d{1,3}[\.\)]\s+\S+", t))
        qs += len(re.findall(r"(?m)^\s*\d{1,3}\.\s*$", t))
        ans += len(
            re.findall(
                r"(?i)answer\s*key|\bAns(?:wer)?\.?\s*[\(\:\-]?\s*[A-Ea-e]\b",
                t,
            )
        )
        seq += len(
            re.findall(
                r"(?i)\b(define|enumerate|draw and label|briefly describe|write short|name the|what are)\b",
                t,
            )
        )
        if not snip:
            snip = re.sub(r"\s+", " ", t)[:200]
    avg = chars / max(len(idxs), 1)
    doc.close()
    mcq = opts >= 8 and qs >= 3
    seq_like = seq >= 5 and opts < 5
    if mcq and avg >= 400:
        verdict = "GO_MCQ"
    elif mcq and avg >= 150:
        verdict = "MAYBE_MCQ"
    elif seq_like and avg >= 400:
        verdict = "SEQ_SKIP"
    elif avg >= 400:
        verdict = "TEXT_OTHER"
    else:
        verdict = "SCAN_SKIP"
    return {
        "mb": pdf.stat().st_size / 1e6,
        "pages": n,
        "avg": avg,
        "opts": opts,
        "qs": qs,
        "ans": ans,
        "seq": seq,
        "verdict": verdict,
        "done": pdf.name in DONE,
        "name": pdf.name,
        "snip": snip,
    }


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    rows = []
    for pdf in sorted(ROOT.glob("*.pdf")):
        try:
            rows.append(analyze(pdf))
        except Exception as e:
            print("FAIL", pdf.name, e)
    order = {
        "GO_MCQ": 0,
        "MAYBE_MCQ": 1,
        "TEXT_OTHER": 2,
        "SEQ_SKIP": 3,
        "SCAN_SKIP": 4,
    }
    rows.sort(key=lambda r: (order[r["verdict"]], -r["avg"]))
    print(
        f"{'verdict':10} {'done':4} {'MB':>5} {'pgs':>4} {'chars':>6} "
        f"{'opt':>4} {'q':>4} {'ans':>3} name"
    )
    for r in rows:
        print(
            f"{r['verdict']:10} {'Y' if r['done'] else '-':4} {r['mb']:5.1f} "
            f"{r['pages']:4d} {r['avg']:6.0f} {r['opts']:4d} {r['qs']:4d} "
            f"{r['ans']:3d} {r['name']}"
        )
    print("\n=== GO_MCQ remaining ===")
    for r in rows:
        if r["verdict"] == "GO_MCQ" and not r["done"]:
            print(f"- {r['name']}")
            print(f"  {r['snip']}")
    print("\n=== MAYBE_MCQ ===")
    for r in rows:
        if r["verdict"] == "MAYBE_MCQ" and not r["done"]:
            print(f"- {r['name']} (chars={r['avg']:.0f} opts={r['opts']})")
            print(f"  {r['snip']}")


if __name__ == "__main__":
    main()
