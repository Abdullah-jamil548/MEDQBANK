"""Classify library PDFs: native outline vs scanned / missing TOC.

Writes backend/.toc_scan/report.json and outlines for books that need a fallback.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import fitz  # PyMuPDF

from scripts.upload_books import SKIP_NAMES, collect_jobs

TESSERACT = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
OUT_DIR = ROOT / ".toc_scan"
OUT_DIR.mkdir(exist_ok=True)

TOC_HEADER = re.compile(r"\b(contents|table of contents|list of contents|index of contents)\b", re.I)
CHAPTER_LINE = re.compile(
    r"(?i)^\s*(?:(?:chapter|ch\.?|unit|section|part|appendix)\s*)?"
    r"(\d{1,2}(?:\.\d+)?|[IVXLC]{1,6}|[A-Z])"
    r"[\.\:\)\-\s]+(.{8,90}?)\s+(\d{1,4})\s*$"
)
SIMPLE_DOTTED = re.compile(r"^(.{8,90}?)\s+[\.\s]{3,}\s*(\d{1,4})\s*$")
TRAILING_PAGE = re.compile(r"^(.{8,90}?)\s+(\d{1,4})\s*$")


def text_sample(doc: fitz.Document, pages: int = 12) -> tuple[int, str]:
    chunks: list[str] = []
    chars = 0
    n = min(pages, doc.page_count)
    for i in range(n):
        t = doc[i].get_text("text") or ""
        chars += len(t.strip())
        chunks.append(t)
    return chars, "\n".join(chunks)


def ocr_page(page: fitz.Page) -> str:
    if not TESSERACT.is_file():
        return ""
    pix = page.get_pixmap(matrix=fitz.Matrix(1.6, 1.6), alpha=False)
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "p.png"
        pix.save(str(png))
        out_base = Path(td) / "out"
        r = subprocess.run(
            [str(TESSERACT), str(png), str(out_base), "--psm", "6", "-l", "eng"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        txt = Path(str(out_base) + ".txt")
        if r.returncode != 0 or not txt.is_file():
            return ""
        return txt.read_text(encoding="utf-8", errors="ignore")


def parse_toc_lines(text: str) -> list[dict]:
    items: list[dict] = []
    seen: set[tuple[str, int]] = set()
    for raw in text.splitlines():
        line = re.sub(r"\s+", " ", raw).strip()
        if len(line) < 10:
            continue
        low = line.lower()
        if low.startswith("page ") or "camscanner" in low:
            continue
        m = CHAPTER_LINE.match(line) or SIMPLE_DOTTED.match(line)
        title = None
        printed = None
        if m and m.lastindex == 3:
            title = f"{m.group(1)}. {m.group(2).strip(' .-')}"
            printed = int(m.group(3))
        elif m and m.lastindex == 2:
            title = m.group(1).strip(" .-")
            printed = int(m.group(2))
        else:
            m2 = TRAILING_PAGE.match(line)
            if not m2:
                continue
            title = m2.group(1).strip(" .-")
            printed = int(m2.group(2))
            if not re.search(r"(?i)chapter|appendix|unit|section|part|\d", title):
                continue
        title = re.sub(r"[\.]{2,}", "", title).strip(" .-")
        if printed is None or printed < 1 or printed > 2000:
            continue
        if len(title) < 6:
            continue
        key = (title.lower()[:40], printed)
        if key in seen:
            continue
        seen.add(key)
        items.append({"title": title, "printed": printed})
    return items


def estimate_offset(doc: fitz.Document, sample_text: str) -> int:
    """PDF page index of printed page 1. Default: first page after a Contents header."""
    n = min(doc.page_count, 40)
    toc_pdf = None
    for i in range(n):
        t = doc[i].get_text("text") or ""
        if TOC_HEADER.search(t):
            toc_pdf = i + 1  # 1-based
    if toc_pdf:
        return toc_pdf  # often next page is printed 1, but Excel was Contents p6, printed 1 = p7 so offset=6
    # Excel-style: Contents then chapter 1 on following page => offset = toc_pdf
    # printed_page + offset = pdf_page, if printed 1 is pdf 7, offset 6 = toc page.
    return 0


def find_printed_one(doc: fitz.Document, use_ocr: bool) -> int | None:
    """Return 1-based PDF page that looks like printed page 1 / chapter 1 start."""
    n = min(doc.page_count, 20)
    for i in range(n):
        t = doc[i].get_text("text") or ""
        if use_ocr and len(t.strip()) < 40:
            t = ocr_page(doc[i])
        if re.search(r"(?i)^\s*1[\.\)]\s+[A-Z]", t, re.M) and i >= 2:
            return i + 1
        # footer printed page number 1 in a box is hard; look for lone "1" near end
        tail = "\n".join(t.strip().splitlines()[-4:])
        if re.search(r"(?m)^\s*1\s*$", tail) and i >= 4:
            return i + 1
    return None


def collect_front_text(doc: fitz.Document, use_ocr: bool, pages: int = 18) -> str:
    parts: list[str] = []
    n = min(pages, doc.page_count)
    for i in range(n):
        t = doc[i].get_text("text") or ""
        if use_ocr and len(t.strip()) < 80:
            t = ocr_page(doc[i]) or t
        parts.append(f"\n----- PDF {i+1} -----\n{t}")
    return "\n".join(parts)


def build_outline(items: list[dict], offset: int, page_count: int) -> list[dict]:
    out = []
    for it in items:
        printed = it["printed"]
        pdf = printed + offset
        if pdf < 1:
            pdf = 1
        if pdf > page_count:
            pdf = page_count
        rec = {"title": it["title"], "page": pdf, "printed": printed}
        out.append(rec)
    return out


def main() -> None:
    jobs = collect_jobs()
    report = []
    outlines: dict[str, list] = {}
    print(f"jobs={len(jobs)} tesseract={TESSERACT.is_file()}", flush=True)

    for job in jobs:
        path: Path = job["path"]
        book_id = job["book_id"]
        try:
            doc = fitz.open(path)
        except Exception as e:
            print(f"FAIL open {path.name}: {e}", flush=True)
            continue
        toc = doc.get_toc() or []
        chars, sample = text_sample(doc, 10)
        scanned = chars < 200
        native = len(toc) >= 3
        row = {
            "book_id": book_id,
            "title": job["title"],
            "file": path.name,
            "pages": doc.page_count,
            "native_toc": len(toc),
            "front_text_chars": chars,
            "scanned": scanned,
            "needs_fallback": (not native),
        }
        print(
            f"{'SCAN' if scanned else 'TEXT'} toc={len(toc):3d} p={doc.page_count:4d}  {book_id}",
            flush=True,
        )
        if not native:
            use_ocr = scanned or chars < 1500
            front = collect_front_text(doc, use_ocr=use_ocr, pages=16)
            (OUT_DIR / f"{book_id}.front.txt").write_text(front, encoding="utf-8")
            items = parse_toc_lines(front)
            p1 = find_printed_one(doc, use_ocr=use_ocr)
            # If Contents is on PDF page C and printed 1 is P, offset = P-1
            toc_pages = [int(m.group(1)) for m in re.finditer(r"----- PDF (\d+) -----", front)]
            header_pdf = None
            for block in front.split("----- PDF "):
                if TOC_HEADER.search(block):
                    try:
                        header_pdf = int(block.split(" ", 1)[0].strip("- \n"))
                    except ValueError:
                        pass
                    break
            if p1:
                offset = p1 - 1
            elif header_pdf:
                offset = header_pdf  # contents page number as offset (Excel: 6)
            else:
                offset = 0
            outline = build_outline(items, offset, doc.page_count)
            if header_pdf:
                outline.insert(0, {"title": "List of Contents", "page": header_pdf, "printed": None})
            row["offset"] = offset
            row["parsed_items"] = len(items)
            if len(outline) >= 4:
                outlines[book_id] = outline
                row["fallback_ok"] = True
            else:
                row["fallback_ok"] = False
                row["parse_hint"] = items[:8]
        doc.close()
        report.append(row)

    (OUT_DIR / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (OUT_DIR / "outlines.json").write_text(json.dumps(outlines, indent=2), encoding="utf-8")
    need = [r for r in report if r.get("needs_fallback")]
    ok = [r for r in need if r.get("fallback_ok")]
    print(f"\nDONE books={len(report)} need_fallback={len(need)} parsed={len(ok)}", flush=True)
    for r in need:
        print(
            f"  {'OK' if r.get('fallback_ok') else 'NO'} {r['book_id']} toc={r['native_toc']} items={r.get('parsed_items', 0)}",
            flush=True,
        )


if __name__ == "__main__":
    main()
