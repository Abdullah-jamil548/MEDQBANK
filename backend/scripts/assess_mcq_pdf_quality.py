"""Score past-paper PDFs for MCQ OCR suitability (text vs scan, sharpness).

Usage (from backend/):
  python scripts/assess_mcq_pdf_quality.py
  python scripts/assess_mcq_pdf_quality.py --ocr-sample  # slow: Tesseract mean conf on page 1
"""
from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

import fitz

DEFAULT_ROOT = Path(r"D:\Past papers-20261005T064648Z-1-001\Past papers")
TESSERACT = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")

# Formats that look like dedicated MCQ dumps (not giant Key-to-UHS photo books)
MCQISH = re.compile(
    r"(?i)mcq|topical|topic\s*wise|past\s*papers?(?!.*key)|chapter\s*1\s*past"
)
KEY_BOOK = re.compile(r"(?i)key\s*to\s*uhs|compiled\s*by|edition|amna\s*iqbal|block-?\d")


def native_text_stats(doc: fitz.Document, max_pages: int = 5) -> tuple[float, float, bool]:
    n = doc.page_count
    idxs = sorted(set([0, min(1, n - 1), n // 2, n - 1]))[:max_pages]
    chars = words = 0
    has_mcq_shape = False
    for i in idxs:
        t = (doc[i].get_text("text") or "").strip()
        chars += len(t)
        words += len(t.split())
        if re.search(r"(?m)^\s*\(?\d{1,3}[\.\)]\s+\S+", t) and re.search(
            r"(?m)^\s*[A-Ea-e][\.\)]\s+\S+", t
        ):
            has_mcq_shape = True
    k = max(len(idxs), 1)
    return chars / k, words / k, has_mcq_shape


def sharpness_proxy(page: fitz.Page) -> float:
    """Laplacian-ish variance on a downscaled grayscale pixmap (higher = sharper)."""
    pix = page.get_pixmap(matrix=fitz.Matrix(0.35, 0.35), colorspace=fitz.csGRAY, alpha=False)
    samples = pix.samples
    w, h = pix.width, pix.height
    if w < 3 or h < 3:
        return 0.0
    # simple 3x3 Laplacian approx on every 2nd pixel for speed
    acc = 0.0
    n = 0
    for y in range(1, h - 1, 2):
        row = y * w
        for x in range(1, w - 1, 2):
            c = samples[row + x]
            lap = (
                4 * c
                - samples[row + x - 1]
                - samples[row + x + 1]
                - samples[row - w + x]
                - samples[row + w + x]
            )
            acc += lap * lap
            n += 1
    return (acc / n) if n else 0.0


def tesseract_mean_conf(page: fitz.Page) -> float | None:
    if not TESSERACT.is_file():
        return None
    pix = page.get_pixmap(matrix=fitz.Matrix(2.0, 2.0), alpha=False)
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "p.png"
        pix.save(str(png))
        out = Path(td) / "out"
        r = subprocess.run(
            [str(TESSERACT), str(png), str(out), "--psm", "6", "-l", "eng", "tsv"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        tsv = Path(str(out) + ".tsv")
        if r.returncode != 0 or not tsv.is_file():
            return None
        confs: list[float] = []
        for line in tsv.read_text(encoding="utf-8", errors="ignore").splitlines()[1:]:
            parts = line.split("\t")
            if len(parts) < 12:
                continue
            try:
                conf = float(parts[10])
            except ValueError:
                continue
            text = parts[11].strip()
            if conf >= 0 and text:
                confs.append(conf)
        return sum(confs) / len(confs) if confs else None


def classify(avg_chars: float, sharp: float, conf: float | None, name: str) -> str:
    """go / maybe / skip — bias toward near-99% accuracy only."""
    # Large Key-to-UHS / compiled photo books: skip unless OCR conf is excellent
    if KEY_BOOK.search(name):
        if conf is not None and conf < 90:
            return "skip"
        if avg_chars < 200 and (conf is None or conf < 92):
            return "skip"
    if avg_chars >= 500 and (conf is None or conf >= 88):
        return "go"  # native/digital text → near-perfect parse
    if conf is not None:
        if conf >= 90 and sharp >= 200:
            return "go"
        if conf >= 82 and sharp >= 160:
            return "maybe"
        return "skip"
    # no OCR sample: use text + sharpness + naming heuristics
    if avg_chars >= 200 and sharp >= 220:
        return "go"
    if MCQISH.search(name) and sharp >= 200 and avg_chars < 80:
        return "maybe"  # clean dedicated MCQ scan possible
    if sharp < 150 or (KEY_BOOK.search(name) and avg_chars < 100):
        return "skip"
    return "maybe"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--ocr-sample", action="store_true", help="Run Tesseract conf on page 0")
    args = ap.parse_args()

    rows = []
    for pdf in sorted(args.root.glob("*.pdf")):
        try:
            doc = fitz.open(pdf)
            avg_c, avg_w, mcq_shape = native_text_stats(doc)
            sharp = sharpness_proxy(doc[0])
            conf = tesseract_mean_conf(doc[0]) if args.ocr_sample else None
            verdict = classify(avg_c, sharp, conf, pdf.name)
            rows.append(
                {
                    "mb": pdf.stat().st_size / 1e6,
                    "pages": doc.page_count,
                    "avg_chars": avg_c,
                    "avg_words": avg_w,
                    "sharp": sharp,
                    "conf": conf,
                    "mcq_shape": mcq_shape,
                    "verdict": verdict,
                    "name": pdf.name,
                }
            )
            doc.close()
            print(f"scored {pdf.name}", flush=True)
        except Exception as e:
            print(f"FAIL {pdf.name}: {e}", flush=True)

    order = {"go": 0, "maybe": 1, "skip": 2}
    rows.sort(key=lambda r: (order[r["verdict"]], -r["avg_chars"], r["mb"]))

    print()
    hdr = f"{'verdict':7} {'MB':>5} {'pgs':>4} {'chars':>6} {'sharp':>7} {'conf':>5} {'mcq':3} name"
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        conf_s = f"{r['conf']:5.1f}" if r["conf"] is not None else "  n/a"
        print(
            f"{r['verdict']:7} {r['mb']:5.1f} {r['pages']:4d} {r['avg_chars']:6.0f} "
            f"{r['sharp']:7.0f} {conf_s} {'Y' if r['mcq_shape'] else '-':>3} {r['name']}"
        )

    print("\nGO (target ~99%):")
    for r in rows:
        if r["verdict"] == "go":
            print(f"  - {r['name']}")
    print("\nMAYBE (spot-check before OCR):")
    for r in rows:
        if r["verdict"] == "maybe":
            print(f"  - {r['name']}")
    print("\nSKIP (blur/tilt/Key-book photo risk):")
    for r in rows:
        if r["verdict"] == "skip":
            print(f"  - {r['name']}")


if __name__ == "__main__":
    main()
