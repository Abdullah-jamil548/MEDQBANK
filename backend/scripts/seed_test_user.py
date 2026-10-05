"""Ensure test users with a fresh 60-day subscription."""

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

USERS = [
    ("test@medqbank.com", "Test1234", "Test Student"),
    ("test2@medqbank.com", "Test1234", "Test Friend"),
]


def upsert_user(db, email: str, password: str, name: str, expires: datetime) -> None:
    user = db.scalar(select(User).where(User.email == email))
    now = datetime.now(timezone.utc)
    if user is None:
        user = User(
            full_name=name,
            email=email,
            hashed_password=hash_password(password),
            auth_provider="email",
            is_active=True,
            onboarding_done=True,
            subscription_expires_at=expires,
        )
        db.add(user)
        print(f"Created {email}")
    else:
        user.full_name = name
        user.hashed_password = hash_password(password)
        user.is_active = True
        user.onboarding_done = True
        user.subscription_expires_at = expires
        user.updated_at = now
        print(f"Updated {email}")


def main() -> None:
    init_schemas_and_tables()
    assert SessionLocal is not None
    db = SessionLocal()
    try:
        expires = datetime.now(timezone.utc) + timedelta(days=60)
        for email, password, name in USERS:
            upsert_user(db, email, password, name, expires)
            print(f"  Password: {password}")
        db.commit()
        print(f"Active until: {expires.isoformat()}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
