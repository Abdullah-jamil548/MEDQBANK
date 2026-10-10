"""OCR + parse Embryology MCQ PDF into reviewable JSON, then optional DB import.

Two-column scanned Keys are OCR'd left/right separately for cleaner parsing.

Usage:
  python scripts/import_mcq_pilot.py              # OCR + write JSON only
  python scripts/import_mcq_pilot.py --import-db  # load existing JSON into Postgres
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import fitz  # noqa: E402

PDF_PATH = Path(
    r"D:\Past papers-20261005T064648Z-1-001\Past papers\Embryology past papers MCQs(0)_102030.pdf"
)
OUT_DIR = ROOT / ".mcq_pilot"
JSON_PATH = OUT_DIR / "embryology_mcqs.json"
OCR_DIR = OUT_DIR / "ocr_text"
TESSERACT = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")

SET_META = {
    "set_id": "embryology-past-papers-mcqs",
    "subject": "Embryology",
    "title": "Embryology Past Papers MCQs",
    "source_pdf": PDF_PATH.name,
    "topic": None,
}

# (12) Stem...   or 12. Stem...
Q_START_RE = re.compile(
    r"(?m)^\s*\(?\s*(\d{1,3})\s*[\.\)\]]\s*(.+?)\s*$"
)
# a) option   (a) option   A. option   : b) option (OCR junk prefix)
OPTION_RE = re.compile(
    r"(?m)^\s*[:\|\'\"\.\,]*\s*\(?\s*([A-Ea-e])\s*\)?[\.\)\]\:\-]\s*(.+?)\s*$"
)
# Ans. (B)  Answer: C  Ans-(A)
ANSWER_RE = re.compile(
    r"(?i)\bAns(?:wer)?\.?\s*[\(\:\-]?\s*([A-Ea-e])\b"
)
TOPIC_RE = re.compile(
    r"(?im)^\s*(?:TOPIC|CHAPTER|SECTION)\s*[#:\-]?\s*(.*)$"
)
SKIP_LINE = re.compile(
    r"(?i)camscanner|scanned with|mcqs?\s+for\s+uhs|past\s+solved|ref\.?\s*(klm|langman)"
)


def ocr_pixmap(pix: fitz.Pixmap, label: str) -> str:
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "p.png"
        pix.save(str(png))
        out_base = Path(td) / "out"
        r = subprocess.run(
            [str(TESSERACT), str(png), str(out_base), "--psm", "6", "-l", "eng"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        txt_path = Path(str(out_base) + ".txt")
        if r.returncode != 0 or not txt_path.is_file():
            err = (r.stderr or r.stdout or "ocr failed").strip()
            print(f"  OCR fail {label}: {err[:120]}", flush=True)
            return ""
        return txt_path.read_text(encoding="utf-8", errors="ignore")


def ocr_page_columns(page: fitz.Page, page_no: int) -> str:
    """OCR left then right column; two-column Keys mix badly as a full page."""
    OCR_DIR.mkdir(parents=True, exist_ok=True)
    rect = page.rect
    mid = (rect.x0 + rect.x1) / 2
    overlap = 8
    left = fitz.Rect(rect.x0, rect.y0, mid + overlap, rect.y1)
    right = fitz.Rect(mid - overlap, rect.y0, rect.x1, rect.y1)
    mat = fitz.Matrix(2.2, 2.2)
    left_txt = ocr_pixmap(page.get_pixmap(matrix=mat, clip=left, alpha=False), f"p{page_no}L")
    right_txt = ocr_pixmap(page.get_pixmap(matrix=mat, clip=right, alpha=False), f"p{page_no}R")
    combined = f"----- PAGE {page_no} LEFT -----\n{left_txt}\n----- PAGE {page_no} RIGHT -----\n{right_txt}\n"
    (OCR_DIR / f"p{page_no:02d}.txt").write_text(combined, encoding="utf-8")
    return combined


def clean_line(line: str) -> str:
    line = line.replace("|", "I").replace("—", "-").replace("–", "-")
    line = re.sub(r"\s+", " ", line).strip()
    # Drop leading OCR debris before a real option / question marker
    line = re.sub(r"^[\s\|\:\;\'\"\.\`\,]+", "", line)
    return line


_INLINE_OPT = re.compile(r"(?i)(?:^|(?<=[\s\.\,\;\:]))([a-e])\)\s*")


def _explode_options(opts: list[dict]) -> list[dict]:
    """Split OCR-glued option text like 'elbow. d) Meta… e) Tempo…'."""
    expanded: list[dict] = []
    for o in opts:
        key = (o.get("key") or "").upper()
        text = (o.get("text") or "").strip()
        matches = list(_INLINE_OPT.finditer(text))
        if not matches:
            if text:
                expanded.append({"key": key, "text": text})
            continue
        if matches[0].start() > 0:
            head = text[: matches[0].start()].strip()
            if head:
                expanded.append({"key": key, "text": head})
        for i, m in enumerate(matches):
            k = m.group(1).upper()
            start = m.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            chunk = text[start:end].strip()
            if chunk:
                expanded.append({"key": k, "text": chunk})
    return expanded


def parse_ocr_pages(pages: list[tuple[int, str]]) -> list[dict]:
    questions: list[dict] = []
    current: dict | None = None
    current_topic: str | None = None
    stem_buf: list[str] = []

    def flush() -> None:
        nonlocal current, stem_buf
        if current is None:
            return
        if stem_buf:
            current["stem"] = " ".join(stem_buf).strip()
            stem_buf = []
        opts = _explode_options(current.get("options") or [])
        by_key: dict[str, str] = {}
        for o in opts:
            k = o["key"]
            t = re.sub(r"\s+", " ", o["text"]).strip(" .")
            # Drop answer/ref tails stuck on option text
            t = ANSWER_RE.split(t)[0].strip(" .;-")
            t = re.sub(r"(?i)\bRef\.?\s*.*$", "", t).strip(" .;-")
            if len(t) < 1:
                continue
            by_key[k] = t
        ordered = [{"key": k, "text": by_key[k]} for k in ("A", "B", "C", "D", "E") if k in by_key]
        stem = re.sub(r"\s+", " ", current.get("stem") or "").strip()
        # Strip a leading glued option from stem
        stem = re.sub(r"(?i)\s+[a-e]\)\s+.*$", "", stem).strip()
        if stem and len(ordered) >= 3:
            current["stem"] = stem
            current["options"] = ordered
            # Pull trailing Ans from stem/options if missing
            if not current.get("answer_key"):
                blob = stem + " " + " ".join(o["text"] for o in ordered)
                m = ANSWER_RE.search(blob)
                if m:
                    current["answer_key"] = m.group(1).upper()
            questions.append(current)
        current = None

    for page_no, text in pages:
        for raw in text.splitlines():
            line = clean_line(raw)
            if not line or len(line) < 2:
                continue
            if line.startswith("----- PAGE"):
                continue
            if SKIP_LINE.search(line) and not ANSWER_RE.search(line):
                # Keep Ans lines; skip headers/footers
                if not ANSWER_RE.search(line):
                    continue

            tm = TOPIC_RE.match(line)
            if tm:
                topic = tm.group(1).strip(" #:-")
                current_topic = topic[:120] if topic else current_topic
                continue

            am = ANSWER_RE.search(line)
            # Standalone answer line
            if am and re.match(r"(?i)^\s*Ans", line) and current is not None:
                current["answer_key"] = am.group(1).upper()
                # Drop ref noise from being treated as options
                continue

            qm = Q_START_RE.match(line)
            if qm:
                # Avoid mistaking years like 2011 at line start without stem length
                qnum = int(qm.group(1))
                rest = qm.group(2).strip()
                if qnum > 300:
                    continue
                # Option-like false positive: "a) foo" already handled; numbers 1-99 ok
                flush()
                current = {
                    "sort_order": qnum,
                    "topic": current_topic,
                    "stem": "",
                    "explanation": "",
                    "answer_key": None,
                    "source_page": page_no,
                    "options": [],
                }
                # Strip leading option letter if OCR glued first option into stem start
                stem_buf = [rest] if rest else []
                if am:
                    current["answer_key"] = am.group(1).upper()
                continue

            om = OPTION_RE.match(line)
            if om and current is not None:
                if stem_buf:
                    current["stem"] = " ".join(stem_buf).strip()
                    stem_buf = []
                key = om.group(1).upper()
                text_opt = om.group(2).strip()
                # Remove inline Ans from option text
                inline = ANSWER_RE.search(text_opt)
                if inline:
                    current["answer_key"] = inline.group(1).upper()
                    text_opt = text_opt[: inline.start()].strip(" .;-")
                opts = [o for o in current["options"] if o["key"] != key]
                opts.append({"key": key, "text": text_opt})
                current["options"] = opts
                continue

            if current is not None:
                if am and re.search(r"(?i)\bAns", line):
                    current["answer_key"] = am.group(1).upper()
                    continue
                if current.get("options"):
                    last = current["options"][-1]
                    last["text"] = (last["text"] + " " + line).strip()
                else:
                    stem_buf.append(line)

    flush()

    # Deduplicate by (page, question number) — columns reuse 1..N
    best: dict[tuple[int, int], dict] = {}
    for q in questions:
        so = int(q.get("sort_order") or 0)
        page = int(q.get("source_page") or 0)
        key = (page, so)
        prev = best.get(key)
        score = (
            len(q.get("options") or [])
            + (2 if q.get("answer_key") else 0)
            + min(len(q.get("stem") or ""), 80) / 80
        )
        if prev is None:
            best[key] = q
            continue
        prev_score = (
            len(prev.get("options") or [])
            + (2 if prev.get("answer_key") else 0)
            + min(len(prev.get("stem") or ""), 80) / 80
        )
        if score > prev_score:
            best[key] = q
    return [best[k] for k in sorted(best)]


def build_payload(questions: list[dict]) -> dict:
    with_ans = sum(1 for q in questions if q.get("answer_key"))
    return {
        **SET_META,
        "question_count": len(questions),
        "answered_count": with_ans,
        "questions": questions,
        "notes": (
            "Pilot OCR extract from two-column scan. Review stems/options/answer_key "
            "before --import-db. Some OCR noise is expected."
        ),
    }


def run_ocr_parse() -> dict:
    if not PDF_PATH.is_file():
        raise SystemExit(f"PDF not found: {PDF_PATH}")
    if not TESSERACT.is_file():
        raise SystemExit(f"Tesseract not found: {TESSERACT}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(PDF_PATH)
    print(f"OCR {PDF_PATH.name} pages={doc.page_count} (column split)", flush=True)
    pages: list[tuple[int, str]] = []
    for i in range(doc.page_count):
        page_no = i + 1
        print(f"  page {page_no}/{doc.page_count}", flush=True)
        text = ocr_page_columns(doc[i], page_no)
        pages.append((page_no, text))
    doc.close()

    questions = parse_ocr_pages(pages)
    payload = build_payload(questions)
    JSON_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(
        f"Wrote {JSON_PATH} questions={len(questions)} answered={payload['answered_count']}",
        flush=True,
    )
    return payload


def import_db(payload: dict | None = None) -> None:
    from sqlalchemy import select

    from app.db import SessionLocal, init_schemas_and_tables
    from app.models import McqOption, McqQuestion, McqSet

    if SessionLocal is None:
        raise SystemExit("Database is not configured")
    if payload is None:
        if not JSON_PATH.is_file():
            raise SystemExit(f"Missing {JSON_PATH}; run without --import-db first")
        payload = json.loads(JSON_PATH.read_text(encoding="utf-8"))

    init_schemas_and_tables()
    db = SessionLocal()
    try:
        set_id = payload["set_id"]
        row = db.get(McqSet, set_id)
        if row is None:
            row = McqSet(set_id=set_id)
            db.add(row)
        row.subject = payload.get("subject") or "Embryology"
        row.title = payload.get("title") or set_id
        row.source_pdf = payload.get("source_pdf")
        row.topic = payload.get("topic")
        row.is_active = True
        db.flush()

        existing = list(db.scalars(select(McqQuestion).where(McqQuestion.set_id == set_id)).all())
        for q in existing:
            db.delete(q)
        db.flush()

        for item in payload.get("questions") or []:
            q = McqQuestion(
                set_id=set_id,
                topic=item.get("topic"),
                stem=item.get("stem") or "",
                explanation=item.get("explanation") or "",
                answer_key=(item.get("answer_key") or None),
                sort_order=int(item.get("sort_order") or 0),
                source_page=item.get("source_page"),
                stem_image=item.get("stem_image"),
            )
            db.add(q)
            db.flush()
            for opt in item.get("options") or []:
                key = str(opt.get("key") or "").upper()[:1]
                text = str(opt.get("text") or "").strip()
                if not key or not text:
                    continue
                db.add(McqOption(question_id=q.question_id, key=key, text=text))
        db.commit()
        print(f"DB import ok: {set_id} questions={len(payload.get('questions') or [])}", flush=True)
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--import-db", action="store_true", help="Import existing JSON into Postgres")
    parser.add_argument("--ocr", action="store_true", help="Force OCR even when importing")
    args = parser.parse_args()

    if args.import_db and not args.ocr:
        import_db()
        return

    payload = run_ocr_parse()
    if args.import_db:
        import_db(payload)


if __name__ == "__main__":
    main()
