from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.auth import (
    create_admin_token,
    hash_password,
    require_admin,
    verify_admin_credentials,
)
from app.book_outlines import outline_for_book
from app.config import Settings, get_settings
from app.db import get_db
from app.models import ActivityHourUser, Book, ChatMessage, User
from app.r2 import R2Service
from app.realtime import manager as ws_manager
from app.schemas import (
    AdminActivity,
    AdminHourPoint,
    AdminLiveUser,
    AdminLoginRequest,
    AdminStats,
    AdminTokenResponse,
    AdminUserCreate,
    AdminUserUpdate,
    BookSummary,
    UserOut,
)

router = APIRouter(prefix="/admin", tags=["admin"])


PKT = timezone(timedelta(hours=5))
ONLINE_WINDOW_SECONDS = 120


def get_r2(settings: Settings = Depends(get_settings)) -> R2Service:
    return R2Service(settings)


def _as_utc(ts: datetime | None) -> datetime | None:
    if ts is None:
        return None
    if ts.tzinfo is None:
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def _slugify(name: str, *, past_paper: bool) -> str:
    s = name.lower().strip()
    s = s.replace("&", " and ")
    s = re.sub(r"[\[\]\(\)]", " ", s)
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = s.strip("-")[:80] or "item"
    if past_paper and not s.startswith("pp-"):
        s = f"pp-{s}"
    return s[:90]


def _book_summary(row: Book) -> BookSummary:
    return BookSummary(
        book_id=row.book_id,
        title=row.title,
        author=row.author,
        subject=row.subject,
        year_label=row.year_label,
        blurb=row.blurb,
        size=row.size_bytes,
        size_bytes=row.size_bytes,
        format=row.format,
        r2_key=row.r2_key,
        content_kind=getattr(row, "content_kind", None) or "book",
        outline=outline_for_book(row.book_id, getattr(row, "outline", None)),
        is_active=row.is_active,
        source="db",
    )


def _parse_bool(value: str | None, default: bool = True) -> bool:
    if value is None or value == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _delete_r2_for_book(r2: R2Service, book_id: str, r2_key: str | None) -> int:
    removed = r2.delete_prefix(f"books/{book_id}/")
    r2.delete_key(f"books/{book_id}.pdf")
    r2.delete_key(f"books/{book_id}.epub")
    if r2_key:
        r2.delete_key(r2_key)
    return removed


@router.post("/login", response_model=AdminTokenResponse)
def admin_login(body: AdminLoginRequest, settings: Settings = Depends(get_settings)) -> AdminTokenResponse:
    if not (settings.admin_email and settings.admin_password):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin login is not configured. Set ADMIN_EMAIL and ADMIN_PASSWORD.",
        )
    if not verify_admin_credentials(body.email, body.password, settings):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin credentials")
    return AdminTokenResponse(
        access_token=create_admin_token(settings),
        email=settings.admin_email.strip().lower(),
    )


@router.get("/stats", response_model=AdminStats)
def admin_stats(
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> AdminStats:
    users_total = db.scalar(select(func.count()).select_from(User)) or 0
    users_active = db.scalar(select(func.count()).select_from(User).where(User.is_active.is_(True))) or 0
    books_total = (
        db.scalar(select(func.count()).select_from(Book).where(Book.content_kind == "book")) or 0
    )
    papers_total = (
        db.scalar(select(func.count()).select_from(Book).where(Book.content_kind == "past_paper")) or 0
    )
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=ONLINE_WINDOW_SECONDS)
    live_now = 0
    for row in db.scalars(select(User)).all():
        seen = _as_utc(row.last_seen_at)
        if (seen and seen >= cutoff) or ws_manager.is_online(row.user_id):
            live_now += 1
    return AdminStats(
        users_total=users_total,
        users_active=users_active,
        books_total=books_total,
        past_papers_total=papers_total,
        live_now=live_now,
    )


@router.get("/activity", response_model=AdminActivity)
def admin_activity(
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> AdminActivity:
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=ONLINE_WINDOW_SECONDS)
    live_users: list[AdminLiveUser] = []
    for row in db.scalars(select(User).order_by(User.full_name)).all():
        socket_online = ws_manager.is_online(row.user_id)
        seen = _as_utc(row.last_seen_at)
        if socket_online or (seen is not None and seen >= cutoff):
            live_users.append(
                AdminLiveUser(
                    user_id=row.user_id,
                    full_name=row.full_name,
                    email=row.email,
                    last_seen_at=row.last_seen_at,
                    socket_online=socket_online,
                )
            )

    now_pkt = datetime.now(PKT).replace(minute=0, second=0, microsecond=0)
    start_pkt = now_pkt - timedelta(hours=23)
    start_utc = start_pkt.astimezone(timezone.utc)
    end_utc = now_pkt.astimezone(timezone.utc) + timedelta(hours=1)

    ping_rows = db.execute(
        select(ActivityHourUser.hour_start, ActivityHourUser.user_id).where(
            ActivityHourUser.hour_start >= start_utc,
            ActivityHourUser.hour_start < end_utc,
        )
    ).all()
    chat_rows = db.execute(
        select(ChatMessage.created_at, ChatMessage.sender_id).where(
            ChatMessage.created_at >= start_utc,
            ChatMessage.created_at < end_utc,
        )
    ).all()

    by_hour: dict[datetime, set[UUID]] = {}
    for hour_start, user_id in ping_rows:
        hour = _as_utc(hour_start)
        if hour is None:
            continue
        hour = hour.replace(minute=0, second=0, microsecond=0)
        by_hour.setdefault(hour, set()).add(user_id)
    for created_at, sender_id in chat_rows:
        hour = _as_utc(created_at)
        if hour is None:
            continue
        hour = hour.replace(minute=0, second=0, microsecond=0)
        by_hour.setdefault(hour, set()).add(sender_id)

    hours: list[AdminHourPoint] = []
    for i in range(24):
        pkt_hour = start_pkt + timedelta(hours=i)
        utc_hour = pkt_hour.astimezone(timezone.utc)
        count = len(by_hour.get(utc_hour, set()))
        label = pkt_hour.strftime("%I %p").lstrip("0")
        hours.append(
            AdminHourPoint(hour_label=label, hour_iso=utc_hour, unique_users=count)
        )

    return AdminActivity(live_count=len(live_users), live_users=live_users, hours=hours)


@router.get("/users", response_model=list[UserOut])
def list_users(
    q: str | None = Query(default=None),
    active: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> list[User]:
    stmt = select(User).order_by(User.created_at.desc())
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(User.full_name.ilike(like), User.email.ilike(like)))
    if active is not None:
        stmt = stmt.where(User.is_active.is_(active))
    return list(db.scalars(stmt.limit(500)).all())


@router.post("/users", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(
    body: AdminUserCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> User:
    email = body.email.lower().strip()
    existing = db.scalar(select(User).where(User.email == email))
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    user = User(
        full_name=body.full_name.strip(),
        email=email,
        phone=body.phone,
        hashed_password=hash_password(body.password),
        auth_provider="email",
        is_active=body.is_active,
        subscription_expires_at=body.subscription_expires_at,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}", response_model=UserOut)
def update_user(
    user_id: UUID,
    body: AdminUserUpdate,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    data = body.model_dump(exclude_unset=True)
    if "email" in data and data["email"] is not None:
        email = str(data["email"]).lower().strip()
        clash = db.scalar(select(User).where(User.email == email, User.user_id != user_id))
        if clash:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
        user.email = email
        data.pop("email")
    if "password" in data:
        password = data.pop("password")
        if password:
            user.hashed_password = hash_password(password)
    for key, value in data.items():
        setattr(user, key, value)
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> Response:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/catalog", response_model=list[BookSummary])
def list_catalog(
    kind: str = Query(default="all", pattern="^(book|past_paper|all)$"),
    q: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: dict = Depends(require_admin),
) -> list[BookSummary]:
    stmt = select(Book).order_by(Book.title)
    if kind != "all":
        stmt = stmt.where(Book.content_kind == kind)
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                Book.title.ilike(like),
                Book.subject.ilike(like),
                Book.author.ilike(like),
                Book.book_id.ilike(like),
            )
        )
    return [_book_summary(row) for row in db.scalars(stmt).all()]


@router.post("/catalog", response_model=BookSummary, status_code=status.HTTP_201_CREATED)
async def create_catalog_item(
    file: UploadFile = File(...),
    title: str = Form(...),
    content_kind: str = Form("book"),
    author: str | None = Form(None),
    subject: str | None = Form(None),
    year_label: str | None = Form(None),
    blurb: str | None = Form(None),
    is_active: str | None = Form("true"),
    book_id: str | None = Form(None),
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    _: dict = Depends(require_admin),
) -> BookSummary:
    kind = (content_kind or "book").strip()
    if kind not in {"book", "past_paper"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="content_kind must be book or past_paper")
    filename = file.filename or "document.pdf"
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only PDF files are supported")
    slug = (book_id or "").strip() or _slugify(title, past_paper=kind == "past_paper")
    existing = db.get(Book, slug)
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Catalog id already exists; use update")
    body = await file.read()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file")
    key = f"books/{slug}/{slug}.pdf"
    r2.put_object(key, body, content_type="application/pdf")
    row = Book(
        book_id=slug,
        title=title.strip(),
        author=author,
        subject=subject,
        year_label=year_label,
        blurb=blurb,
        size_bytes=len(body),
        format="pdf",
        r2_key=key,
        content_type="application/pdf",
        content_kind=kind,
        is_active=_parse_bool(is_active, True),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _book_summary(row)


@router.patch("/catalog/{book_id}", response_model=BookSummary)
async def update_catalog_item(
    book_id: str,
    file: UploadFile | None = File(None),
    title: str | None = Form(None),
    content_kind: str | None = Form(None),
    author: str | None = Form(None),
    subject: str | None = Form(None),
    year_label: str | None = Form(None),
    blurb: str | None = Form(None),
    is_active: str | None = Form(None),
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    _: dict = Depends(require_admin),
) -> BookSummary:
    row = db.get(Book, book_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Catalog item not found")
    if title is not None:
        row.title = title.strip()
    if content_kind is not None and content_kind.strip():
        kind = content_kind.strip()
        if kind not in {"book", "past_paper"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="content_kind must be book or past_paper")
        row.content_kind = kind
    if author is not None:
        row.author = author
    if subject is not None:
        row.subject = subject
    if year_label is not None:
        row.year_label = year_label
    if blurb is not None:
        row.blurb = blurb
    if is_active is not None and is_active != "":
        row.is_active = _parse_bool(is_active, row.is_active)
    if file is not None and file.filename:
        filename = file.filename
        if not filename.lower().endswith(".pdf"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only PDF files are supported")
        body = await file.read()
        if not body:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file")
        key = row.r2_key or f"books/{book_id}/{book_id}.pdf"
        r2.put_object(key, body, content_type="application/pdf")
        row.r2_key = key
        row.size_bytes = len(body)
        row.format = "pdf"
        row.content_type = "application/pdf"
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return _book_summary(row)


@router.delete("/catalog/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_catalog_item(
    book_id: str,
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    _: dict = Depends(require_admin),
) -> Response:
    row = db.get(Book, book_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Catalog item not found")
    _delete_r2_for_book(r2, book_id, row.r2_key)
    db.delete(row)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
