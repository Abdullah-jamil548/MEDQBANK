"""Set paper_format on existing past_paper rows (no re-upload).

Usage (from backend/):
  python scripts/backfill_paper_format.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sqlalchemy import select

from app.db import SessionLocal, init_schemas_and_tables
from app.models import Book
from app.paper_format import infer_paper_format


def main() -> None:
    if SessionLocal is None:
        raise SystemExit("Database is not configured")
    init_schemas_and_tables()
    db = SessionLocal()
    try:
        rows = db.scalars(
            select(Book).where(Book.content_kind == "past_paper")
        ).all()
        for row in rows:
            # Prefer title + id only — upload blurb often says "key-to-UHS" for every file
            fmt = infer_paper_format(row.title, row.book_id)
            row.paper_format = fmt
            print(f"  {fmt:12}  {row.subject:16}  {row.title}", flush=True)
        db.commit()
        print(f"Updated {len(rows)} past papers", flush=True)
    finally:
        db.close()


if __name__ == "__main__":
    main()
