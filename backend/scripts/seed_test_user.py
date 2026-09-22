"""Ensure a test user with a fresh 60-day subscription."""

from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sqlalchemy import select

from app.auth import hash_password
from app.db import SessionLocal, init_schemas_and_tables
from app.models import User

EMAIL = "test@medqbank.com"
PASSWORD = "Test1234"
NAME = "Test Student"


def main() -> None:
    init_schemas_and_tables()
    assert SessionLocal is not None
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == EMAIL))
        now = datetime.now(timezone.utc)
        expires = now + timedelta(days=60)
        if user is None:
            user = User(
                full_name=NAME,
                email=EMAIL,
                hashed_password=hash_password(PASSWORD),
                auth_provider="email",
                is_active=True,
                onboarding_done=True,
                subscription_expires_at=expires,
            )
            db.add(user)
            print(f"Created {EMAIL}")
        else:
            user.hashed_password = hash_password(PASSWORD)
            user.is_active = True
            user.onboarding_done = True
            user.subscription_expires_at = expires
            user.updated_at = now
            print(f"Updated {EMAIL}")
        db.commit()
        print(f"Password: {PASSWORD}")
        print(f"Active until: {expires.isoformat()}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
