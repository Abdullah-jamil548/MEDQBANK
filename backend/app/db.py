from collections.abc import Generator

from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings


class Base(DeclarativeBase):
    pass


settings = get_settings()

engine = (
    create_engine(
        settings.database_url,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )
    if settings.db_configured
    else None
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False) if engine else None


def get_db() -> Generator[Session, None, None]:
    if SessionLocal is None:
        raise RuntimeError("Database is not configured")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_schemas_and_tables() -> None:
    """Create users/books schemas and all ORM tables."""
    if engine is None:
        raise RuntimeError("Database is not configured")

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS users"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS books"))

    # Import models so metadata is populated
    import app.models  # noqa: F401

    Base.metadata.create_all(bind=engine)


def check_db() -> bool:
    if engine is None:
        return False
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return True
