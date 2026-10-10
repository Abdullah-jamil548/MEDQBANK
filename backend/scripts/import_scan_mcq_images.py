"""Free image-backed MCQ import for scanned MCQ PDFs (no paid vision API).

Processes every scan-style option-MCQ book (skips native-text Anatomy topic-wise).

Pipeline per page column:
  1. Render PDF → OpenCV deskew + contrast
  2. Save PNG for quiz display
  3. Tesseract OCR; if confidence high enough, parse A–E text
  4. Always attach stem_image so the quiz can show the scan

Usage (from backend/):
  python scripts/import_scan_mcq_images.py --parse --import-db
  python scripts/import_scan_mcq_images.py --only histology --parse --import-db
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import cv2
import fitz
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import importlib.util  # noqa: E402

_pilot_path = ROOT / "scripts" / "import_mcq_pilot.py"
_spec = importlib.util.spec_from_file_location("import_mcq_pilot", _pilot_path)
_pilot = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_pilot)
ANSWER_RE = _pilot.ANSWER_RE
parse_ocr_pages = _pilot.parse_ocr_pages

PAST_PAPERS = Path(r"D:\Past papers-20261005T064648Z-1-001\Past papers")
TESSERACT = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
# Image fallback only when OCR is badly broken. Readable text MCQs stay text.
CONF_UNREADABLE = 55.0
FIGURE_OPT_RE = re.compile(
    r"(?i)\b(fig\.?|figure|diagram|image|see\s+(the\s+)?(fig|plate|picture)|shown\s+below)\b"
)


@dataclass(frozen=True)
class ScanJob:
    key: str  # short id slug used in paths
    pdf_name: str
    set_id: str
    subject: str
    title: str
    topic: str | None = None


# Native-text Anatomy topic-wise is handled by import_anatomy_topic_wise.py — skip here.
JOBS: list[ScanJob] = [
    ScanJob(
        key="general-anatomy-key",
        pdf_name="General anatomy (key to uhs)-1_034706.pdf",
        set_id="anatomy-general-key-scan-mcqs",
        subject="Anatomy",
        title="General Anatomy Key MCQs",
        topic="General Anatomy",
    ),
    ScanJob(
        key="histology-key",
        pdf_name="Histology (key to uhs).pdf",
        set_id="histology-key-scan-mcqs",
        subject="Histology",
        title="Histology Key MCQs",
        topic="Histology",
    ),
    ScanJob(
        key="lower-limb",
        pdf_name="Lower Limb Past Papers_084723.pdf",
        set_id="anatomy-lower-limb-scan-mcqs",
        subject="Anatomy",
        title="Lower Limb Past Papers MCQs",
        topic="Gross: Lower Limb",
    ),
    ScanJob(
        key="embryology-mcqs",
        pdf_name="Embryology past papers MCQs(0)_102030.pdf",
        set_id="embryology-past-papers-scan-mcqs",
        subject="Embryology",
        title="Embryology Past Papers MCQs (scan)",
        topic="Embryology",
    ),
]


def pix_to_bgr(pix: fitz.Pixmap) -> np.ndarray:
    if pix.alpha:
        pix = fitz.Pixmap(fitz.csRGB, pix)
    arr = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    if pix.n == 1:
        return cv2.cvtColor(arr, cv2.COLOR_GRAY2BGR)
    return cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)


def deskew_enhance(bgr: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.fastNlMeansDenoising(gray, None, 12, 7, 21)
    thr = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
    coords = np.column_stack(np.where(thr > 0))
    angle = 0.0
    if len(coords) > 80:
        rect = cv2.minAreaRect(coords)
        angle = rect[-1]
        if angle < -45:
            angle = 90 + angle
        elif angle > 45:
            angle = angle - 90
        if abs(angle) > 0.4:
            h, w = gray.shape
            m = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0)
            gray = cv2.warpAffine(
                gray, m, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE
            )
    clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(8, 8))
    gray = clahe.apply(gray)
    return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)


def ocr_image(bgr: np.ndarray, label: str) -> tuple[str, float | None]:
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "p.png"
        cv2.imwrite(str(png), bgr)
        out = Path(td) / "out"
        r = subprocess.run(
            [str(TESSERACT), str(png), str(out), "--psm", "6", "-l", "eng", "tsv"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        subprocess.run(
            [str(TESSERACT), str(png), str(out), "--psm", "6", "-l", "eng"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        txt_path = Path(str(out) + ".txt")
        tsv_path = Path(str(out) + ".tsv")
        text = txt_path.read_text(encoding="utf-8", errors="ignore") if txt_path.is_file() else ""
        confs: list[float] = []
        if tsv_path.is_file() and r.returncode == 0:
            for line in tsv_path.read_text(encoding="utf-8", errors="ignore").splitlines()[1:]:
                parts = line.split("\t")
                if len(parts) < 12:
                    continue
                try:
                    conf = float(parts[10])
                except ValueError:
                    continue
                if conf >= 0 and parts[11].strip():
                    confs.append(conf)
        mean = sum(confs) / len(confs) if confs else None
        conf_s = f"{mean:.1f}" if mean is not None else "n/a"
        print(f"  OCR {label}: conf={conf_s} chars={len(text.strip())}", flush=True)
        return text, mean


def letter_options() -> list[dict]:
    return [{"key": k, "text": k} for k in ("A", "B", "C", "D", "E")]


def weak_image_questions(
    page_no: int,
    side: str,
    text: str,
    stem_image: str,
    topic: str | None,
) -> list[dict]:
    qnums = [int(m.group(1)) for m in re.finditer(r"(?m)^\s*\(?\s*(\d{1,3})\s*[\.\)]\s*", text)]
    ans_all = [m.group(1).upper() for m in ANSWER_RE.finditer(text)]
    out: list[dict] = []
    if not qnums:
        ans = ans_all[0] if ans_all else None
        out.append(
            {
                "sort_order": page_no * 10 + (0 if side == "L" else 5),
                "topic": topic,
                "stem": f"Page {page_no} ({side}) — answer from the image",
                "explanation": "Image-backed scan item. Review answer_key before trusting score.",
                "answer_key": ans,
                "source_page": page_no,
                "stem_image": stem_image,
                "mode": "image",
                "options": letter_options(),
            }
        )
        return out

    for i, qn in enumerate(qnums):
        ans = None
        for m in re.finditer(
            rf"(?is)(?:^|\n)\s*\(?\s*{qn}\s*[\.\)]\s*.{{0,800}}?\bAns(?:wer)?\.?\s*[\(\:\-]?\s*([A-Ea-e])\b",
            text,
        ):
            ans = m.group(1).upper()
            break
        if ans is None and i < len(ans_all):
            ans = ans_all[i]
        out.append(
            {
                "sort_order": page_no * 100 + qn,
                "topic": topic,
                "stem": f"Q{qn} — see image (page {page_no})",
                "explanation": "Image-backed; OCR text was too weak for a full stem.",
                "answer_key": ans,
                "source_page": page_no,
                "stem_image": stem_image,
                "mode": "image",
                "options": letter_options(),
            }
        )
    return out


def _options_are_real(options: list[dict]) -> bool:
    texts = [re.sub(r"\s+", " ", (o.get("text") or "")).strip() for o in options]
    useful = [t for t in texts if len(t) > 2 and t.upper() not in {"A", "B", "C", "D", "E"}]
    return len(useful) >= 3


def _looks_like_figure_options(options: list[dict]) -> bool:
    blob = " ".join((o.get("text") or "") for o in options)
    return bool(FIGURE_OPT_RE.search(blob))


def enrich_parsed(
    questions: list[dict],
    stem_image: str,
    page_no: int,
    conf: float | None,
    topic: str | None,
) -> list[dict]:
    """Prefer text MCQs. Image mode only if unreadable or figure-style options."""
    out: list[dict] = []
    for q in questions:
        opts = q.get("options") or []
        real = _options_are_real(opts)
        fig = _looks_like_figure_options(opts)
        unreadable = conf is not None and conf < CONF_UNREADABLE
        if topic and not q.get("topic"):
            q["topic"] = topic
        q["source_page"] = page_no
        q["ocr_confidence"] = round(conf, 1) if conf is not None else None

        if real and not fig and not unreadable:
            # Readable text MCQ — do NOT force image UI
            q["mode"] = "text"
            q.pop("stem_image", None)
            out.append(q)
            continue

        # Image fallback (unreadable / figure options / weak parse)
        q["mode"] = "image"
        q["stem_image"] = stem_image
        if fig or not real:
            q["options"] = letter_options()
        if not (q.get("stem") or "").strip() or not real:
            q["stem"] = q.get("stem") or f"See image (page {page_no})"
            if not real:
                q["stem"] = f"Q — see image (page {page_no})"
        out.append(q)
    return out


def process_job(job: ScanJob) -> dict:
    pdf_path = PAST_PAPERS / job.pdf_name
    if not pdf_path.is_file():
        raise SystemExit(f"PDF not found: {pdf_path}")
    if not TESSERACT.is_file():
        raise SystemExit(f"Tesseract not found: {TESSERACT}")

    out_dir = ROOT / ".mcq_pilot" / f"scan_{job.key.replace('-', '_')}"
    img_dir = out_dir / "images"
    ocr_dir = out_dir / "ocr_text"
    json_path = out_dir / f"{job.key.replace('-', '_')}_mcqs.json"
    flutter_json = ROOT.parent / "assets" / "mcqs" / f"{job.key.replace('-', '_')}_mcqs.json"
    # Keep stable asset names used by Flutter
    asset_slug = job.key
    flutter_img = ROOT.parent / "assets" / "mcqs" / "images" / asset_slug
    static_img = ROOT / "static" / "mcq_images" / asset_slug

    for d in (img_dir, ocr_dir, flutter_img, static_img):
        d.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(pdf_path)
    all_q: list[dict] = []
    print(f"\n=== {job.title} ===", flush=True)
    print(f"Scan-import {pdf_path.name} pages={doc.page_count}", flush=True)

    for i in range(doc.page_count):
        page_no = i + 1
        page = doc[i]
        rect = page.rect
        mid = (rect.x0 + rect.x1) / 2
        overlap = 10
        clips = {
            "L": fitz.Rect(rect.x0, rect.y0, mid + overlap, rect.y1),
            "R": fitz.Rect(mid - overlap, rect.y0, rect.x1, rect.y1),
        }
        mat = fitz.Matrix(2.4, 2.4)
        for side, clip in clips.items():
            pix = page.get_pixmap(matrix=mat, clip=clip, alpha=False)
            bgr = deskew_enhance(pix_to_bgr(pix))
            fname = f"p{page_no:02d}_{side}.png"
            img_path = img_dir / fname
            cv2.imwrite(str(img_path), bgr)
            shutil.copyfile(img_path, flutter_img / fname)
            shutil.copyfile(img_path, static_img / fname)

            stem_image = f"assets/mcqs/images/{asset_slug}/{fname}"
            text, conf = ocr_image(bgr, f"p{page_no}{side}")
            (ocr_dir / f"p{page_no:02d}_{side}.txt").write_text(
                f"conf={conf}\n{text}", encoding="utf-8"
            )

            parsed = parse_ocr_pages([(page_no, text)])
            if parsed:
                all_q.extend(enrich_parsed(parsed, stem_image, page_no, conf, job.topic))
            elif conf is None or conf < CONF_UNREADABLE:
                all_q.extend(
                    weak_image_questions(page_no, side, text, stem_image, job.topic)
                )
            # else: readable column but nothing parsed — skip rather than fake image cards

    doc.close()

    best: dict[tuple, dict] = {}
    for q in all_q:
        key = (q.get("source_page"), int(q.get("sort_order") or 0), (q.get("stem") or "")[:40])
        prev = best.get(key)
        score = len(q.get("options") or []) + (3 if q.get("answer_key") else 0)
        score += 5 if q.get("mode") == "text" else 0
        score += min(sum(len(o.get("text") or "") for o in (q.get("options") or [])), 200) / 50
        if prev is None or score >= (
            len(prev.get("options") or [])
            + (3 if prev.get("answer_key") else 0)
            + (5 if prev.get("mode") == "text" else 0)
        ):
            best[key] = q

    questions = sorted(
        best.values(), key=lambda q: (q.get("source_page") or 0, q.get("sort_order") or 0)
    )
    for i, q in enumerate(questions, start=1):
        q["sort_order"] = i

    answered = sum(1 for q in questions if q.get("answer_key"))
    text_n = sum(1 for q in questions if q.get("mode") == "text")
    image_n = sum(1 for q in questions if q.get("mode") == "image")
    presentation = "text" if image_n == 0 else ("image" if text_n == 0 else "hybrid")
    payload = {
        "set_id": job.set_id,
        "subject": job.subject,
        "title": job.title,
        "source_pdf": pdf_path.name,
        "topic": job.topic,
        "presentation": presentation,
        "question_count": len(questions),
        "answered_count": answered,
        "text_count": text_n,
        "image_count": image_n,
        "questions": questions,
        "notes": (
            "OpenCV deskew + Tesseract. Text MCQs extracted when readable; "
            "image mode only for unreadable pages or figure-style options."
        ),
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    # Prefer readable filenames matching Flutter assets
    flutter_name = {
        "general-anatomy-key": "general_anatomy_key_mcqs.json",
        "histology-key": "histology_key_mcqs.json",
        "lower-limb": "lower_limb_mcqs.json",
        "embryology-mcqs": "embryology_scan_mcqs.json",
    }[job.key]
    json_path = out_dir / flutter_name
    flutter_json = ROOT.parent / "assets" / "mcqs" / flutter_name
    json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    flutter_json.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(json_path, flutter_json)
    print(
        f"Wrote {flutter_name}: questions={len(questions)} answered={answered} "
        f"text={text_n} image_fallback={image_n}",
        flush=True,
    )
    return payload


def import_db(payload: dict) -> None:
    from sqlalchemy import select

    from app.db import SessionLocal, init_schemas_and_tables
    from app.models import McqOption, McqQuestion, McqSet

    if SessionLocal is None:
        raise SystemExit("Database is not configured")

    init_schemas_and_tables()
    db = SessionLocal()
    try:
        set_id = payload["set_id"]
        row = db.get(McqSet, set_id)
        if row is None:
            row = McqSet(set_id=set_id)
            db.add(row)
        row.subject = payload.get("subject") or "Past Papers"
        row.title = payload.get("title") or set_id
        row.source_pdf = payload.get("source_pdf")
        row.topic = payload.get("topic")
        row.is_active = True
        db.flush()

        for q in db.scalars(select(McqQuestion).where(McqQuestion.set_id == set_id)).all():
            db.delete(q)
        db.flush()

        for item in payload.get("questions") or []:
            q = McqQuestion(
                set_id=set_id,
                topic=item.get("topic"),
                stem=item.get("stem") or "See image",
                explanation=item.get("explanation") or "",
                answer_key=(item.get("answer_key") or None),
                sort_order=int(item.get("sort_order") or 0),
                source_page=item.get("source_page"),
                stem_image=item.get("stem_image"),
            )
            db.add(q)
            db.flush()
            for opt in item.get("options") or letter_options():
                key = str(opt.get("key") or "").upper()[:1]
                text = str(opt.get("text") or key).strip() or key
                if not key:
                    continue
                db.add(McqOption(question_id=q.question_id, key=key, text=text))
        db.commit()
        print(f"DB import ok: {set_id} questions={len(payload.get('questions') or [])}", flush=True)
    finally:
        db.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--import-db", action="store_true")
    ap.add_argument("--parse", action="store_true", help="Force OCR even if JSON exists")
    ap.add_argument(
        "--only",
        action="append",
        default=[],
        help="Job key filter (repeatable): general-anatomy-key, histology-key, lower-limb, embryology-mcqs",
    )
    args = ap.parse_args()

    jobs = JOBS
    if args.only:
        wanted = {x.strip().lower() for x in args.only}
        jobs = [j for j in JOBS if j.key in wanted]
        if not jobs:
            raise SystemExit(f"No jobs matched --only {args.only}")

    for job in jobs:
        flutter_name = {
            "general-anatomy-key": "general_anatomy_key_mcqs.json",
            "histology-key": "histology_key_mcqs.json",
            "lower-limb": "lower_limb_mcqs.json",
            "embryology-mcqs": "embryology_scan_mcqs.json",
        }[job.key]
        existing = ROOT / ".mcq_pilot" / f"scan_{job.key.replace('-', '_')}" / flutter_name
        # Also check alternate path after first write layout
        alt = list((ROOT / ".mcq_pilot").glob(f"**/ {flutter_name}".replace(" ", "")))
        json_file = existing if existing.is_file() else ROOT.parent / "assets" / "mcqs" / flutter_name

        if args.import_db and not args.parse and json_file.is_file():
            payload = json.loads(json_file.read_text(encoding="utf-8"))
            import_db(payload)
            continue

        payload = process_job(job)
        if args.import_db:
            import_db(payload)


if __name__ == "__main__":
    main()
