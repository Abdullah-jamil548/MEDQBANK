"""Parse native-text Anatomy topic-wise BCQs (no OCR) into reviewable JSON.

Source is digital text (~99% parse accuracy). Skips photo/Key-to-UHS books.

Usage (from backend/):
  python scripts/import_anatomy_topic_wise.py
  python scripts/import_anatomy_topic_wise.py --import-db
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import fitz  # noqa: E402

PDF_PATH = Path(
    r"D:\Past papers-20261005T064648Z-1-001\Past papers\Anatomy topic wise past papers.pdf"
)
OUT_DIR = ROOT / ".mcq_pilot"
JSON_PATH = OUT_DIR / "anatomy_topic_wise_mcqs.json"
FLUTTER_ASSET = ROOT.parent / "assets" / "mcqs" / "anatomy_topic_wise_mcqs.json"

SET_META = {
    "set_id": "anatomy-topic-wise-past-papers",
    "subject": "Anatomy",
    "title": "Anatomy Topic-wise Past Papers",
    "source_pdf": PDF_PATH.name,
    "topic": None,
}

# "12. Stem..." or bare "12." with stem on following lines (common in this PDF)
Q_START_RE = re.compile(r"(?m)^\s*(\d{1,3})\.\s*(.*)$")
OPTION_RE = re.compile(r"(?m)^\s*([A-Ea-e])\.\s*(.+?)\s*$")
ANSWER_KEY_RE = re.compile(r"(?i)answer\s*key")
HEADER_NOISE = re.compile(
    r"(?i)^(anatomy|1st\s*year\s*mbbs|med\s*drive|bcqs?|option(?:\s*q\.?\s*no)?|"
    r"q\.?\s*no\.?|q\.?\s*o\.?)$"
)
TOPIC_CANDIDATE = re.compile(r"^[A-Z][A-Z0-9 &\-/\.;:]{2,60}$")
# Short option-like all-caps lines (A. 45XY already caught by OPTION_RE)
SKIP_TOPIC = {
    "ANATOMY",
    "MED DRIVE",
    "OPTION",
    "OPTION Q. NO",
    "Q. NO",
    "Q. O",
    "BCQS",
}


def clean_line(line: str) -> str:
    line = line.replace("\u00a0", " ").replace("—", "-").replace("–", "-")
    return re.sub(r"\s+", " ", line).strip()


def is_topic(line: str) -> bool:
    if not TOPIC_CANDIDATE.fullmatch(line):
        return False
    if line in SKIP_TOPIC or HEADER_NOISE.match(line):
        return False
    if re.fullmatch(r"[A-E]\. .*", line):
        return False
    # Avoid lone chromosome / number option leftovers already handled
    if len(line) <= 3:
        return False
    return True


def parse_answer_pairs(block: str) -> dict[int, str]:
    """Extract qnum -> A-E from answer-key table text (column-scrambled OK)."""
    tokens: list[str] = []
    for raw in block.splitlines():
        line = clean_line(raw)
        if not line or HEADER_NOISE.match(line) or ANSWER_KEY_RE.search(line):
            continue
        # Split glued "22 D 43 A" style leftovers
        for tok in re.split(r"\s+", line):
            if tok:
                tokens.append(tok)

    answers: dict[int, str] = {}
    i = 0
    while i < len(tokens) - 1:
        a, b = tokens[i], tokens[i + 1]
        if re.fullmatch(r"\d{1,3}", a) and re.fullmatch(r"[A-Ea-e]", b):
            answers[int(a)] = b.upper()
            i += 2
            continue
        i += 1
    return answers


def parse_question_block(block: str, page_hint: int) -> list[dict]:
    questions: list[dict] = []
    current: dict | None = None
    stem_buf: list[str] = []
    topic: str | None = None

    def flush() -> None:
        nonlocal current, stem_buf
        if current is None:
            return
        if stem_buf:
            current["stem"] = " ".join(stem_buf).strip()
            stem_buf = []
        by_key: dict[str, str] = {}
        for o in current.get("options") or []:
            t = re.sub(r"\s+", " ", o["text"]).strip(" .")
            if t:
                by_key[o["key"]] = t
        ordered = [{"key": k, "text": by_key[k]} for k in ("A", "B", "C", "D", "E") if k in by_key]
        stem = re.sub(r"\s+", " ", current.get("stem") or "").strip()
        if stem and len(ordered) >= 3:
            current["stem"] = stem
            current["options"] = ordered
            questions.append(current)
        current = None

    for raw in block.splitlines():
        line = clean_line(raw)
        if not line or HEADER_NOISE.match(line) or line.isdigit():
            continue
        if ANSWER_KEY_RE.search(line):
            break
        if is_topic(line):
            flush()
            topic = re.sub(r"\s+", " ", line.replace(";", ":")).strip()
            topic = topic.title()
            topic = topic.replace("Respi.", "Respi.").replace("Sysytem", "System")
            topic = topic.replace("Lymohoid", "Lymphoid")
            # Keep GROSS: prefix readable after title()
            topic = re.sub(r"(?i)^Gross:\s*", "Gross: ", topic)
            continue

        qm = Q_START_RE.match(line)
        if qm:
            qnum = int(qm.group(1))
            rest = (qm.group(2) or "").strip()
            # Ignore years / page junk: need stem now or on later lines; cap qnum
            if qnum > 200:
                continue
            flush()
            current = {
                "local_number": qnum,
                "topic": topic,
                "stem": "",
                "explanation": "",
                "answer_key": None,
                "source_page": page_hint,
                "options": [],
            }
            stem_buf = [rest] if rest else []
            continue

        om = OPTION_RE.match(line)
        if om and current is not None:
            if stem_buf:
                current["stem"] = " ".join(stem_buf).strip()
                stem_buf = []
            key = om.group(1).upper()
            text_opt = om.group(2).strip()
            opts = [o for o in current["options"] if o["key"] != key]
            opts.append({"key": key, "text": text_opt})
            current["options"] = opts
            continue

        if current is not None:
            if current.get("options"):
                last = current["options"][-1]
                last["text"] = (last["text"] + " " + line).strip()
            else:
                stem_buf.append(line)

    flush()
    return questions


def extract_pages(doc: fitz.Document) -> list[tuple[int, str]]:
    pages: list[tuple[int, str]] = []
    for i in range(doc.page_count):
        pages.append((i + 1, doc[i].get_text("text") or ""))
    return pages


def run_parse() -> dict:
    if not PDF_PATH.is_file():
        raise SystemExit(f"PDF not found: {PDF_PATH}")

    doc = fitz.open(PDF_PATH)
    pages = extract_pages(doc)
    doc.close()

    # Build full text with page markers for segmenting on ANSWER KEY
    full_parts: list[str] = []
    for page_no, text in pages:
        full_parts.append(f"\n<<<<<PAGE {page_no}>>>>>\n{text}")
    full = "".join(full_parts)

    # Split into (questions_block, answers_block) pairs
    # Pattern: content ... ANSWER KEY ... (until next real Q section or EOF)
    segments = re.split(r"(?i)\bANSWER\s*KEY\s*:?", full)
    all_questions: list[dict] = []

    # First segment is TOC / preamble — may contain early questions before first key
    # Remaining: odd handling — segments[0]=before first key, segments[1]=after first key...
    # Pair segments[i] questions with segments[i+1] answers for i even? 
    # Actually: text = Q0 + KEY + A0 + Q1 + KEY + A1 + ...
    # split -> [Q0, A0+Q1, A1+Q2, ...] — messy when A and next Q share a segment.
    #
    # Better: find KEY spans and take text between keys as Q, key body until next Q start.

    key_iter = list(re.finditer(r"(?i)\bANSWER\s*KEY\s*:?", full))
    if not key_iter:
        raise SystemExit("No ANSWER KEY sections found")

    bounds = [0] + [m.start() for m in key_iter] + [len(full)]
    # For each key at key_iter[k], questions are text from previous key-end (or 0) to key start
    # answers are from key end to start of next key (or EOF), but stop when a new topic+Q run begins
    for k, m in enumerate(key_iter):
        q_start = 0 if k == 0 else key_iter[k - 1].end()
        # After previous answers, skip leftover answer tokens — questions start at topic or "1."
        q_block = full[q_start : m.start()]
        # Trim leading answer residue from prior key: drop until GENERAL/EMBRYOLOGY/... or blank+digit.
        a_end = key_iter[k + 1].start() if k + 1 < len(key_iter) else len(full)
        a_block = full[m.end() : a_end]

        # Page hint = first PAGE marker in q_block
        pm = re.search(r"<<<<<PAGE (\d+)>>>>>", q_block)
        page_hint = int(pm.group(1)) if pm else 1

        # Strip page markers for parsers
        q_clean = re.sub(r"<<<<<PAGE \d+>>>>>", "\n", q_block)
        a_clean = re.sub(r"<<<<<PAGE \d+>>>>>", "\n", a_block)

        # Answers may include start of next section — cut at strong topic header followed by "1."
        cut = re.search(
            r"(?m)^(GENERAL ANATOMY|EMBRYOLOGY|HISTOLOGY|GROSS[: ].+|LOWER LIMB|UPPER LIMB|THORAX|"
            r"RESPI\.|SKELETAL SYSYTEM|SKIN|LYMOHOID ORGANS|MUSCULAR SYSTEM|CIRCULATORY SYSTEM|"
            r"RESPIRATORY SYSTEM|CVS)\s*$",
            a_clean,
        )
        if cut and re.search(r"(?m)^\s*1\.\s+\S+", a_clean[cut.end() : cut.end() + 400]):
            a_clean = a_clean[: cut.start()]

        answers = parse_answer_pairs(a_clean)
        qs = parse_question_block(q_clean, page_hint)
        matched = 0
        for q in qs:
            num = int(q.pop("local_number"))
            if num in answers:
                q["answer_key"] = answers[num]
                matched += 1
            q["sort_order"] = 0  # filled later
            # stash for debug
            q["_local"] = num
        all_questions.extend(qs)
        print(
            f"  segment {k + 1}: questions={len(qs)} answers_parsed={len(answers)} matched={matched}",
            flush=True,
        )

    # Global sort_order; drop helper
    for i, q in enumerate(all_questions, start=1):
        q["sort_order"] = i
        q.pop("_local", None)

    with_ans = sum(1 for q in all_questions if q.get("answer_key"))
    payload = {
        **SET_META,
        "question_count": len(all_questions),
        "answered_count": with_ans,
        "questions": all_questions,
        "notes": (
            "Native-text extract from Anatomy topic-wise BCQs (no OCR). "
            "High accuracy expected; spot-check answer keys before relying on scores."
        ),
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    FLUTTER_ASSET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(JSON_PATH, FLUTTER_ASSET)
    print(
        f"Wrote {JSON_PATH} and {FLUTTER_ASSET} "
        f"questions={len(all_questions)} answered={with_ans}",
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
        row.subject = payload.get("subject") or "Anatomy"
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
    parser.add_argument("--import-db", action="store_true")
    parser.add_argument("--parse", action="store_true", help="Force re-parse even with --import-db")
    args = parser.parse_args()

    if args.import_db and not args.parse:
        import_db()
        return

    payload = run_parse()
    if args.import_db:
        import_db(payload)


if __name__ == "__main__":
    main()
