"""
Upload past-paper PDFs to Cloudflare R2 and register them in books.book
with content_kind='past_paper'.

Source (default):
  D:/Past papers-20261005T064648Z-1-001/Past papers/*.pdf

R2 layout:
  books/{book_id}/{book_id}.pdf

Usage:
  cd backend
  python scripts/upload_past_papers.py
  python scripts/upload_past_papers.py --limit 2
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

from sqlalchemy import select

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.config import get_settings
from app.db import SessionLocal, init_schemas_and_tables
from app.models import Book
from app.paper_format import infer_paper_format
from app.r2 import R2Service

DEFAULT_INPUT = Path(r"D:\Past papers-20261005T064648Z-1-001\Past papers")

# Exact duplicate copies (same bytes / redundant uploads)
SKIP_NAME_FRAGMENTS = (
    "(1).pdf",
    "_054455.pdf",
)


def slugify(name: str) -> str:
    s = name.lower().strip()
    s = s.replace("&", " and ")
    s = re.sub(r"[\[\]\(\)]", " ", s)
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return ("pp-" + s.strip("-"))[:90]


def clean_title(stem: str) -> str:
    title = re.sub(r"[+_]+", " ", stem)
    title = re.sub(r"\s+", " ", title).strip(" .-_")
    # Drop trailing copy markers
    title = re.sub(r"\s*\(\d+\)\s*$", "", title)
    title = re.sub(r"_\d{6}$", "", title)
    return title[:160] or "Past Paper"


def infer_subject(name: str) -> str:
    n = name.lower()
    if "all subject" in n or "solved past uqs" in n:
        return "All Subjects"
    if "physio" in n:
        return "Physiology"
    if "biochem" in n or "bio chem" in n:
        return "Biochemistry"
    if "histo" in n:
        return "Histology"
    if "embryo" in n:
        return "Embryology"
    if "minor" in n:
        return "Minors"
    if "anat" in n or "limb" in n or "respiratory module anatomy" in n:
        return "Anatomy"
    return "Past Papers"


def file_fingerprint(path: Path, sample: int = 2_000_000) -> str:
    h = hashlib.sha1()
    size = path.stat().st_size
    h.update(str(size).encode())
    with path.open("rb") as f:
        h.update(f.read(sample))
        if size > sample:
            f.seek(max(0, size - sample))
            h.update(f.read(sample))
    return h.hexdigest()


def collect_jobs(input_dir: Path) -> list[dict]:
    if not input_dir.is_dir():
        raise SystemExit(f"Input folder not found: {input_dir}")

    jobs: list[dict] = []
    seen_fp: set[str] = set()

    for path in sorted(input_dir.glob("*.pdf")):
        lower = path.name.lower()
        if any(frag in lower for frag in SKIP_NAME_FRAGMENTS):
            # Keep one of each pair; skip obvious Windows "Copy (1)" / timestamp dupes
            # when a cleaner sibling exists.
            sibling_guess = path.name.replace("(1)", "").replace("_054455", "")
            if (input_dir / sibling_guess).exists() or any(
                p.name.lower().replace("(1)", "").replace("_054455", "")
                == sibling_guess.lower()
                for p in input_dir.glob("*.pdf")
                if p != path
            ):
                print(f"SKIP duplicate name: {path.name}", flush=True)
                continue

        fp = file_fingerprint(path)
        if fp in seen_fp:
            print(f"SKIP duplicate content: {path.name}", flush=True)
            continue
        seen_fp.add(fp)

        title = clean_title(path.stem)
        subject = infer_subject(path.name)
        book_id = slugify(title)
        paper_format = infer_paper_format(path.name, title, subject)
        jobs.append(
            {
                "path": path,
                "book_id": book_id,
                "title": title,
                "author": "UHS Past Papers",
                "subject": subject,
                "year_label": "Past Papers",
                "blurb": (
                    f"{subject} option MCQs (A–E)"
                    if paper_format == "mcq_options"
                    else f"{subject} question & answer / SEQ past papers"
                    if paper_format == "qa"
                    else f"{subject} past papers (mixed UQ + MCQ)"
                ),
                "paper_format": paper_format,
                "filename": f"{book_id}.pdf",
            }
        )
    return jobs


def object_exists(client, bucket: str, key: str, expected_size: int) -> bool:
    try:
        meta = client.head_object(Bucket=bucket, Key=key)
        return int(meta.get("ContentLength", -1)) == expected_size
    except Exception:
        return False


def upload_and_register(jobs: list[dict]) -> None:
    settings = get_settings()
    if not settings.r2_configured:
        raise SystemExit("R2 is not configured in .env")
    if SessionLocal is None:
        raise SystemExit("Database is not configured in .env")

    init_schemas_and_tables()
    r2 = R2Service(settings)
    client = r2.client
    bucket = settings.r2_bucket_name

    db = SessionLocal()
    try:
        for i, job in enumerate(jobs, start=1):
            path: Path = job["path"]
            book_id = job["book_id"]
            r2_key = f"books/{book_id}/{job['filename']}"
            size = path.stat().st_size

            print(f"\n[{i}/{len(jobs)}] {path.name}", flush=True)
            if object_exists(client, bucket, r2_key, size):
                print(f"  SKIP already in R2 ({size / 1_000_000:.1f} MB)", flush=True)
            else:
                print(f"  UPLOAD -> s3://{bucket}/{r2_key} ({size / 1_000_000:.1f} MB)", flush=True)
                client.upload_file(
                    str(path),
                    bucket,
                    r2_key,
                    ExtraArgs={"ContentType": "application/pdf"},
                )

            row = db.get(Book, book_id)
            if row is None:
                row = Book(book_id=book_id)
                db.add(row)

            row.title = job["title"]
            row.author = job["author"]
            row.subject = job["subject"]
            row.year_label = job["year_label"]
            row.blurb = job["blurb"]
            row.size_bytes = size
            row.format = "pdf"
            row.r2_key = r2_key
            row.content_type = "application/pdf"
            row.content_kind = "past_paper"
            row.paper_format = job.get("paper_format") or infer_paper_format(
                job["title"], book_id
            )
            row.is_active = True
            db.commit()
            print(
                f"  DB ok: {book_id} [{job['subject']}] format={row.paper_format}",
                flush=True,
            )
    finally:
        db.close()

    db = SessionLocal()
    try:
        rows = db.scalars(
            select(Book)
            .where(Book.is_active.is_(True), Book.content_kind == "past_paper")
            .order_by(Book.subject, Book.title)
        ).all()
        print("\n=== past papers catalog ===", flush=True)
        for row in rows:
            mb = (row.size_bytes or 0) / 1_000_000
            fmt = getattr(row, "paper_format", None) or "?"
            print(
                f"  [{row.subject}|{fmt}] {row.title} ({mb:.1f} MB)",
                flush=True,
            )
        print(f"Total: {len(rows)} past papers", flush=True)
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload past papers to R2 + DB")
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help="Folder containing past-paper PDFs",
    )
    parser.add_argument("--limit", type=int, default=0, help="Upload at most N files")
    args = parser.parse_args()

    jobs = collect_jobs(args.input)
    if args.limit and args.limit > 0:
        jobs = jobs[: args.limit]
    if not jobs:
        raise SystemExit("No past-paper PDFs found")

    print(f"Found {len(jobs)} past papers to upload from {args.input}\n", flush=True)
    for j in jobs:
        print(f"  [{j['subject']}] {j['title']}", flush=True)
    print(flush=True)
    upload_and_register(jobs)
    print("\nDone.", flush=True)


if __name__ == "__main__":
    main()
