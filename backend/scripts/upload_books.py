"""
Upload local PDF folders to Cloudflare R2 and register rows in books.book.

Year mapping (per product request):
  Books-.../Books/*.pdf              -> 1st / 2nd Year
  3rd year-.../3rd year/*.pdf        -> 3rd Year   (not in 4th year subfolder)
  3rd year-.../3rd year/4th year/*   -> 4th Year
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from sqlalchemy import select

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.config import get_settings
from app.db import SessionLocal, init_schemas_and_tables
from app.models import Book
from app.r2 import R2Service

BACKEND = ROOT
BOOKS_1_2 = BACKEND / "Books-20260922T101946Z-1-001" / "Books"
BOOKS_3 = BACKEND / "3rd year-20260922T101946Z-1-001" / "3rd year"
BOOKS_4 = BOOKS_3 / "4th year"

# Skip duplicate copies (same content / "Copy of ...")
SKIP_NAMES = {
    "copy of jataoi(eye).pdf",
    "excel (cm).pdf",  # duplicate of Excel Community Medicine 13th edition
}

# Manual metadata overrides keyed by normalized filename stem (lowercase)
META: dict[str, dict] = {
    "firdous histology (10th edition)": {
        "title": "Firdous Histology (10th Edition)",
        "author": "Firdous",
        "subject": "Histology",
        "year_label": "1st / 2nd Year",
    },
    "firdous physiology (20th edition)": {
        "title": "Firdous Physiology (20th Edition)",
        "author": "Firdous",
        "subject": "Physiology",
        "year_label": "1st / 2nd Year",
    },
    "general anatomy by laiq hussain 5th edition": {
        "title": "General Anatomy by Laiq Hussain (5th Edition)",
        "author": "Laiq Hussain",
        "subject": "Anatomy",
        "year_label": "1st / 2nd Year",
    },
    "guyton+&+hall+physiology+review+3e": {
        "title": "Guyton & Hall Physiology Review (3e)",
        "author": "Guyton & Hall",
        "subject": "Physiology",
        "year_label": "1st / 2nd Year",
    },
    "harper_s illustrated biochemistry 31e-1": {
        "title": "Harper's Illustrated Biochemistry (31e)",
        "author": "Harper",
        "subject": "Biochemistry",
        "year_label": "1st / 2nd Year",
    },
    "jaypee physiology": {
        "title": "Jaypee Physiology",
        "author": "Jaypee",
        "subject": "Physiology",
        "year_label": "1st / 2nd Year",
    },
    "big katzung 14e-1-1": {
        "title": "Big Katzung (14e)",
        "author": "Katzung",
        "subject": "Pharmacology",
        "year_label": "3rd Year",
    },  
    "mini katzung": {
        "title": "Mini Katzung",
        "author": "Katzung",
        "subject": "Pharmacology",
        "year_label": "3rd Year",
    },
    "excel community medicine 13th edition-1": {
        "title": "Excel Community Medicine (13th Edition)",
        "author": "Excel",
        "subject": "Community Medicine",
        "year_label": "3rd Year",
    },
    "pathoma": {
        "title": "Pathoma",
        "author": "Husain Sattar",
        "subject": "Pathology",
        "year_label": "3rd Year",
    },
    "robbins & kumar basic pathology 11th edition [medicalstudyzone.com]": {
        "title": "Robbins & Kumar Basic Pathology (11th Edition)",
        "author": "Robbins & Kumar",
        "subject": "Pathology",
        "year_label": "3rd Year",
    },
    "jataoi(eye)": {
        "title": "Jatoi Ophthalmology (Eye)",
        "author": "Jatoi",
        "subject": "Ophthalmology",
        "year_label": "4th Year",
    },
    "dhingra ent": {
        "title": "Dhingra ENT",
        "author": "Dhingra",
        "subject": "ENT",
        "year_label": "4th Year",
    },
}


def slugify(name: str) -> str:
    s = name.lower().strip()
    s = s.replace("&", " and ")
    s = s.replace("+", " ")
    s = re.sub(r"[\[\]\(\)]", " ", s)
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")[:80]


def stem_key(path: Path) -> str:
    return path.stem.lower().strip()


def collect_jobs() -> list[dict]:
    jobs: list[dict] = []

    def add(path: Path, default_year: str) -> None:
        if not path.is_file() or path.suffix.lower() != ".pdf":
            return
        if path.name.lower() in SKIP_NAMES:
            print(f"SKIP duplicate: {path.name}", flush=True)
            return
        key = stem_key(path)
        meta = META.get(key)
        if meta is None:
            # fallback from filename
            title = re.sub(r"[+_]+", " ", path.stem).strip()
            meta = {
                "title": title,
                "author": None,
                "subject": None,
                "year_label": default_year,
            }
            print(f"WARN no META override for: {path.name} -> using defaults", flush=True)
        else:
            # ensure year from folder wins if META year differs? Prefer META year_label
            pass

        book_id = slugify(meta["title"])
        jobs.append(
            {
                "path": path,
                "book_id": book_id,
                "title": meta["title"],
                "author": meta.get("author"),
                "subject": meta.get("subject"),
                "year_label": meta.get("year_label") or default_year,
                "filename": f"{book_id}.pdf",
            }
        )

    if BOOKS_1_2.is_dir():
        for p in sorted(BOOKS_1_2.glob("*.pdf")):
            add(p, "1st / 2nd Year")

    if BOOKS_3.is_dir():
        for p in sorted(BOOKS_3.glob("*.pdf")):
            add(p, "3rd Year")

    if BOOKS_4.is_dir():
        for p in sorted(BOOKS_4.glob("*.pdf")):
            add(p, "4th Year")

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
        for job in jobs:
            path: Path = job["path"]
            book_id = job["book_id"]
            r2_key = f"books/{book_id}/{job['filename']}"
            size = path.stat().st_size

            if object_exists(client, bucket, r2_key, size):
                print(f"SKIP already in R2: {path.name}", flush=True)
            else:
                print(f"UPLOAD {path.name}", flush=True)
                print(f"  -> s3://{bucket}/{r2_key} ({size / 1_000_000:.1f} MB)", flush=True)
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
            row.size_bytes = size
            row.format = "pdf"
            row.r2_key = r2_key
            row.content_type = "application/pdf"
            row.is_active = True
            db.commit()
            print(f"  DB ok: {book_id} [{job['year_label']}] — {job['author']}", flush=True)
    finally:
        db.close()

    # summary
    db = SessionLocal()
    try:
        rows = db.scalars(select(Book).where(Book.is_active.is_(True)).order_by(Book.year_label, Book.title)).all()
        print("\n=== books.book catalog ===", flush=True)
        for row in rows:
            print(f"  [{row.year_label}] {row.title} — {row.author} ({row.book_id})", flush=True)
    finally:
        db.close()


def main() -> None:
    jobs = collect_jobs()
    if not jobs:
        raise SystemExit("No PDF jobs found — check folder paths")
    print(f"Found {len(jobs)} books to upload:\n", flush=True)
    for j in jobs:
        print(f"  [{j['year_label']}] {j['title']} ({j['author']})", flush=True)
    print(flush=True)
    upload_and_register(jobs)
    print("\nDone.", flush=True)


if __name__ == "__main__":
    main()
