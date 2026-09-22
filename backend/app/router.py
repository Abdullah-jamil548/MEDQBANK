import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import StreamingResponse
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.auth import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.config import Settings, get_settings
from app.db import check_db, get_db
from app.models import Book, Bookmark, College, Highlight, Note, Progress, User
from app.r2 import R2Service
from app.schemas import (
    BookAccessRequest,
    BookAccessResponse,
    BookDetail,
    BookmarkCreate,
    BookmarkOut,
    BookObject,
    BookSummary,
    BookUpsertRequest,
    CollegeOut,
    HealthResponse,
    HighlightOut,
    HighlightUpsert,
    LoginRequest,
    NoteOut,
    NoteUpsert,
    ProfileUpdateRequest,
    ProgressOut,
    ProgressUpsert,
    RegisterRequest,
    SyncPullResponse,
    TokenResponse,
    UserOut,
)

router = APIRouter()


def get_r2(settings: Settings = Depends(get_settings)) -> R2Service:
    return R2Service(settings)


def _guess_content_type(filename: str) -> str:
    lower = filename.lower()
    if lower.endswith(".epub"):
        return "application/epub+zip"
    if lower.endswith(".pdf"):
        return "application/pdf"
    if lower.endswith(".html") or lower.endswith(".htm"):
        return "text/html; charset=utf-8"
    if lower.endswith(".json"):
        return "application/json"
    if lower.endswith(".txt"):
        return "text/plain; charset=utf-8"
    return "application/octet-stream"


def _pick_object(objects: list[dict], filename: str | None) -> dict:
    if filename:
        wanted = filename.strip()
        wanted_lower = wanted.lower()
        wanted_stem = wanted_lower.rsplit(".", 1)[0]

        for obj in objects:
            name = obj["filename"]
            name_lower = name.lower()
            stem = name_lower.rsplit(".", 1)[0]
            if (
                name == wanted
                or name_lower == wanted_lower
                or stem == wanted_stem
                or name_lower == f"{wanted_lower}.pdf"
                or name_lower == f"{wanted_lower}.epub"
            ):
                return obj

        available = [obj["filename"] for obj in objects]
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                f"File '{filename}' not found for this book. "
                f"Available: {available}. Tip: omit filename or use the full name including .pdf"
            ),
        )

    preferred = (".epub", ".pdf", ".html", ".htm")
    for ext in preferred:
        for obj in objects:
            if obj["filename"].lower().endswith(ext):
                return obj
    return objects[0]


def _ensure_book(db: Session, book_id: str) -> Book:
    book = db.get(Book, book_id)
    if book is None or not book.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    return book


# ----- system -----


@router.get("/health", response_model=HealthResponse, tags=["system"])
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    db_ok = None
    if settings.db_configured:
        try:
            db_ok = check_db()
        except Exception:
            db_ok = False

    return HealthResponse(
        status="ok" if (db_ok is not False) else "degraded",
        app=settings.app_name,
        r2_configured=settings.r2_configured,
        db_configured=settings.db_configured,
        db_ok=db_ok,
        bucket=settings.r2_bucket_name if settings.r2_configured else None,
    )


# ----- auth -----


def _subscription_active(user: User) -> bool:
    if user.subscription_expires_at is None:
        return False
    expires = user.subscription_expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires > datetime.now(timezone.utc)


def _enforce_subscription(db: Session, user: User) -> None:
    """Deactivate users whose 60-day access window has ended."""
    if user.subscription_expires_at is None:
        user.subscription_expires_at = datetime.now(timezone.utc) + timedelta(days=60)
        user.is_active = True
        user.updated_at = datetime.now(timezone.utc)
        db.commit()
        return

    if not _subscription_active(user):
        if user.is_active:
            user.is_active = False
            user.updated_at = datetime.now(timezone.utc)
            db.commit()
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Subscription expired. This account is inactive and cannot log in.",
        )


@router.post("/auth/register", response_model=TokenResponse, tags=["auth"])
def register(
    body: RegisterRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> TokenResponse:
    email = body.email.lower().strip()
    existing = db.scalar(select(User).where(User.email == email))
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    now = datetime.now(timezone.utc)
    user = User(
        full_name=body.full_name.strip(),
        email=email,
        phone=body.phone,
        hashed_password=hash_password(body.password),
        auth_provider="email",
        is_active=True,
        subscription_expires_at=now + timedelta(days=60),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.user_id, settings)
    return TokenResponse(
        access_token=token,
        user_id=user.user_id,
        full_name=user.full_name,
        email=user.email,
    )


@router.post("/auth/login", response_model=TokenResponse, tags=["auth"])
def login(
    body: LoginRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> TokenResponse:
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    _enforce_subscription(db, user)

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")

    token = create_access_token(user.user_id, settings)
    return TokenResponse(
        access_token=token,
        user_id=user.user_id,
        full_name=user.full_name,
        email=user.email,
    )


@router.get("/me", response_model=UserOut, tags=["auth"])
def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.patch("/me", response_model=UserOut, tags=["auth"])
def update_me(
    body: ProfileUpdateRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> User:
    data = body.model_dump(exclude_unset=True)
    if "college_id" in data and data["college_id"] is not None:
        college = db.get(College, data["college_id"])
        if college is None or not college.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="College not found")
    for key, value in data.items():
        setattr(user, key, value)
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return user


@router.get("/colleges", response_model=list[CollegeOut], tags=["auth"])
def list_colleges(
    q: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> list[College]:
    stmt = select(College).where(College.is_active.is_(True)).order_by(College.name)
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(College.name.ilike(like), College.city.ilike(like)))
    return list(db.scalars(stmt).all())


# ----- books -----


@router.get("/books", response_model=list[BookSummary], tags=["books"])
def list_books(
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    source: str = Query(default="db", pattern="^(db|r2|both)$"),
) -> list[BookSummary]:
    """
    List books.
    - db: active rows in books.book (preferred for the app)
    - r2: discover from Cloudflare R2
    - both: merge R2 discoveries into DB response
    """
    results: dict[str, BookSummary] = {}

    if source in ("db", "both"):
        rows = db.scalars(
            select(Book).where(Book.is_active.is_(True)).order_by(Book.title)
        ).all()
        for row in rows:
            results[row.book_id] = BookSummary(
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
                is_active=row.is_active,
                source="db",
            )

    if source in ("r2", "both"):
        for item in r2.list_books():
            book_id = item["book_id"]
            if book_id in results:
                continue
            results[book_id] = BookSummary(
                book_id=book_id,
                title=book_id,
                size=item.get("size"),
                size_bytes=item.get("size"),
                prefix=item.get("prefix"),
                key=item.get("key"),
                last_modified=item.get("last_modified"),
                layout=item.get("layout"),
                source="r2",
            )

    return list(results.values())


@router.post("/books/sync-from-r2", response_model=list[BookSummary], tags=["books"])
def sync_books_from_r2(
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
) -> list[BookSummary]:
    """Upsert R2-discovered books into books.book (PDF catalog)."""
    upserted: list[BookSummary] = []
    for item in r2.list_books():
        book_id = item["book_id"]
        r2_key = item.get("key") or item.get("prefix")
        size = item.get("size")
        row = db.get(Book, book_id)
        if row is None:
            row = Book(
                book_id=book_id,
                title=book_id.replace("-", " ").replace("_", " ").title(),
                size_bytes=size,
                format="pdf",
                r2_key=r2_key,
                content_type="application/pdf",
                is_active=True,
            )
            db.add(row)
        else:
            row.size_bytes = size or row.size_bytes
            row.r2_key = r2_key or row.r2_key
            row.updated_at = datetime.now(timezone.utc)
        db.flush()
        upserted.append(
            BookSummary(
                book_id=row.book_id,
                title=row.title,
                size_bytes=row.size_bytes,
                format=row.format,
                r2_key=row.r2_key,
                is_active=row.is_active,
                source="db",
            )
        )
    db.commit()
    return upserted


@router.post("/books", response_model=BookSummary, tags=["books"])
def upsert_book(body: BookUpsertRequest, db: Session = Depends(get_db)) -> BookSummary:
    row = db.get(Book, body.book_id)
    if row is None:
        row = Book(book_id=body.book_id)
        db.add(row)
    row.title = body.title
    row.author = body.author
    row.subject = body.subject
    row.year_label = body.year_label
    row.blurb = body.blurb
    row.size_bytes = body.size_bytes
    row.format = body.format
    row.r2_key = body.r2_key
    row.content_type = body.content_type
    row.is_active = body.is_active
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return BookSummary(
        book_id=row.book_id,
        title=row.title,
        author=row.author,
        subject=row.subject,
        year_label=row.year_label,
        blurb=row.blurb,
        size_bytes=row.size_bytes,
        format=row.format,
        r2_key=row.r2_key,
        is_active=row.is_active,
        source="db",
    )


@router.get("/books/{book_id}", response_model=BookDetail, tags=["books"])
def get_book(
    book_id: str,
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
) -> BookDetail:
    row = db.get(Book, book_id)
    objects: list[BookObject] = []
    try:
        objects = [BookObject(**obj) for obj in r2.list_book_objects(book_id)]
    except HTTPException:
        if row is None:
            raise

    return BookDetail(
        book_id=book_id,
        title=row.title if row else None,
        author=row.author if row else None,
        subject=row.subject if row else None,
        year_label=row.year_label if row else None,
        blurb=row.blurb if row else None,
        size_bytes=row.size_bytes if row else None,
        format=row.format if row else None,
        r2_key=row.r2_key if row else None,
        is_active=row.is_active if row else None,
        objects=objects,
    )


@router.post(
    "/books/{book_id}/access",
    response_model=BookAccessResponse,
    tags=["books"],
)
def get_book_access(
    book_id: str,
    body: BookAccessRequest | None = None,
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    settings: Settings = Depends(get_settings),
    user: User = Depends(get_current_user),
) -> BookAccessResponse:
    """
    Auth required. Returns short-lived presigned URL.
    Flutter should download once to app cache, then annotate offline.
    """
    _ = user  # authenticated gate
    row = db.get(Book, book_id)
    if row is not None and not row.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    body = body or BookAccessRequest()
    objects = r2.list_book_objects(book_id)
    chosen = _pick_object(objects, body.filename)

    meta = r2.head_object(chosen["key"])
    size = int(meta.get("ContentLength", chosen.get("size", 0)))
    expires_in = body.expires_in or settings.r2_signed_url_expires

    disposition = f'inline; filename="{chosen["filename"]}"'
    url = r2.create_presigned_get_url(
        key=chosen["key"],
        expires_in=expires_in,
        response_content_disposition=disposition,
    )

    if row is not None:
        row.size_bytes = size
        row.r2_key = chosen["key"]
        row.updated_at = datetime.now(timezone.utc)
        db.commit()

    return BookAccessResponse(
        book_id=book_id,
        key=chosen["key"],
        filename=chosen["filename"],
        size=size,
        content_type_hint=_guess_content_type(chosen["filename"]),
        expires_in=expires_in,
        url=url,
    )


@router.get("/books/{book_id}/download", tags=["books"])
def download_book_stream(
    book_id: str,
    filename: str | None = Query(default=None),
    db: Session = Depends(get_db),
    r2: R2Service = Depends(get_r2),
    user: User = Depends(get_current_user),
):
    """
    Stream the PDF through the API (avoids browser CORS blocks on R2).
    Preferred for Flutter web; native apps may still use /access + direct R2.
    """
    _ = user
    row = db.get(Book, book_id)
    if row is not None and not row.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    objects = r2.list_book_objects(book_id)
    chosen = _pick_object(objects, filename)
    body, content_type, size = r2.open_object_stream(chosen["key"])

    headers = {
        "Content-Disposition": f'inline; filename="{chosen["filename"]}"',
        "Cache-Control": "private, max-age=3600",
        "X-Delivery": "api-stream",
    }
    if size > 0:
        headers["Content-Length"] = str(size)

    return StreamingResponse(
        body.iter_chunks(chunk_size=1024 * 1024),
        media_type=content_type or "application/pdf",
        headers=headers,
    )


@router.post("/books/r2-cors", tags=["books"])
def configure_r2_cors(
    r2: R2Service = Depends(get_r2),
    user: User = Depends(get_current_user),
):
    """One-shot: allow browser GET of presigned R2 URLs."""
    _ = user
    r2.ensure_public_read_cors()
    return {"status": "ok", "detail": "R2 CORS updated for GET/HEAD from any origin"}


@router.get("/books/{book_id}/content", tags=["books"])
def get_book_content_proxy(
    book_id: str,
    filename: str | None = Query(default=None),
    r2: R2Service = Depends(get_r2),
    user: User = Depends(get_current_user),
):
    """Test-only proxy. Prefer POST /books/{book_id}/access for real clients."""
    _ = user
    objects = r2.list_book_objects(book_id)
    chosen = _pick_object(objects, filename)
    data, content_type = r2.get_object_bytes(chosen["key"])

    return Response(
        content=data,
        media_type=content_type,
        headers={
            "Content-Disposition": f'inline; filename="{chosen["filename"]}"',
            "Cache-Control": "no-store",
            "X-Delivery": "api-proxy-test-only",
        },
    )


# ----- progress -----


@router.get("/progress", response_model=list[ProgressOut], tags=["annotations"])
def list_progress(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Progress]:
    return list(
        db.scalars(select(Progress).where(Progress.user_id == user.user_id)).all()
    )


@router.put("/progress", response_model=ProgressOut, tags=["annotations"])
def upsert_progress(
    body: ProgressUpsert,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Progress:
    _ensure_book(db, body.book_id)
    row = db.scalar(
        select(Progress).where(
            Progress.user_id == user.user_id,
            Progress.book_id == body.book_id,
        )
    )
    if row is None:
        row = Progress(user_id=user.user_id, book_id=body.book_id)
        db.add(row)
    row.page_no = body.page_no
    row.progress_pct = body.progress_pct
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row


# ----- bookmarks -----


@router.get("/bookmarks", response_model=list[BookmarkOut], tags=["annotations"])
def list_bookmarks(
    book_id: str | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Bookmark]:
    stmt = select(Bookmark).where(Bookmark.user_id == user.user_id)
    if book_id:
        stmt = stmt.where(Bookmark.book_id == book_id)
    return list(db.scalars(stmt).all())


@router.post("/bookmarks", response_model=BookmarkOut, tags=["annotations"])
def create_bookmark(
    body: BookmarkCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Bookmark:
    _ensure_book(db, body.book_id)
    existing = db.scalar(
        select(Bookmark).where(
            Bookmark.user_id == user.user_id,
            Bookmark.book_id == body.book_id,
            Bookmark.page_no == body.page_no,
        )
    )
    if existing:
        return existing
    row = Bookmark(user_id=user.user_id, book_id=body.book_id, page_no=body.page_no)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.delete("/bookmarks/{bookmark_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["annotations"])
def delete_bookmark(
    bookmark_id: uuid.UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    row = db.get(Bookmark, bookmark_id)
    if row is None or row.user_id != user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bookmark not found")
    db.delete(row)
    db.commit()


# ----- highlights -----


@router.get("/highlights", response_model=list[HighlightOut], tags=["annotations"])
def list_highlights(
    book_id: str | None = None,
    include_deleted: bool = False,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Highlight]:
    stmt = select(Highlight).where(Highlight.user_id == user.user_id)
    if book_id:
        stmt = stmt.where(Highlight.book_id == book_id)
    if not include_deleted:
        stmt = stmt.where(Highlight.deleted_at.is_(None))
    return list(db.scalars(stmt).all())


@router.put("/highlights", response_model=HighlightOut, tags=["annotations"])
def upsert_highlight(
    body: HighlightUpsert,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Highlight:
    _ensure_book(db, body.book_id)
    now = datetime.now(timezone.utc)
    row = None
    if body.highlight_id:
        row = db.get(Highlight, body.highlight_id)
        if row and row.user_id != user.user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    if row is None:
        row = Highlight(
            highlight_id=body.highlight_id or uuid.uuid4(),
            user_id=user.user_id,
            book_id=body.book_id,
        )
        db.add(row)

    row.book_id = body.book_id
    row.page_no = body.page_no
    row.selected_text = body.selected_text
    row.rects = body.rects
    row.text_color = body.text_color
    row.note = body.note
    row.updated_at = body.updated_at or now
    row.deleted_at = now if body.deleted else None
    db.commit()
    db.refresh(row)
    return row


# ----- notes -----


@router.get("/notes", response_model=list[NoteOut], tags=["annotations"])
def list_notes(
    book_id: str | None = None,
    include_deleted: bool = False,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Note]:
    stmt = select(Note).where(Note.user_id == user.user_id)
    if book_id:
        stmt = stmt.where(Note.book_id == book_id)
    if not include_deleted:
        stmt = stmt.where(Note.deleted_at.is_(None))
    return list(db.scalars(stmt).all())


@router.put("/notes", response_model=NoteOut, tags=["annotations"])
def upsert_note(
    body: NoteUpsert,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Note:
    _ensure_book(db, body.book_id)
    now = datetime.now(timezone.utc)
    row = None
    if body.note_id:
        row = db.get(Note, body.note_id)
        if row and row.user_id != user.user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    if row is None:
        row = Note(
            note_id=body.note_id or uuid.uuid4(),
            user_id=user.user_id,
            book_id=body.book_id,
            text=body.text,
            page_no=body.page_no,
        )
        db.add(row)

    row.book_id = body.book_id
    row.page_no = body.page_no
    row.text = body.text
    row.updated_at = body.updated_at or now
    row.deleted_at = now if body.deleted else None
    db.commit()
    db.refresh(row)
    return row


# ----- sync pull (offline catch-up) -----


@router.get("/sync", response_model=SyncPullResponse, tags=["annotations"])
def sync_pull(
    since: datetime | None = Query(
        default=None,
        description="ISO timestamp; return rows updated after this time",
    ),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SyncPullResponse:
    hl_stmt = select(Highlight).where(Highlight.user_id == user.user_id)
    note_stmt = select(Note).where(Note.user_id == user.user_id)
    prog_stmt = select(Progress).where(Progress.user_id == user.user_id)
    bm_stmt = select(Bookmark).where(Bookmark.user_id == user.user_id)

    if since is not None:
        hl_stmt = hl_stmt.where(Highlight.updated_at > since)
        note_stmt = note_stmt.where(Note.updated_at > since)
        prog_stmt = prog_stmt.where(Progress.updated_at > since)
        bm_stmt = bm_stmt.where(Bookmark.created_at > since)

    return SyncPullResponse(
        highlights=list(db.scalars(hl_stmt).all()),
        notes=list(db.scalars(note_stmt).all()),
        progress=list(db.scalars(prog_stmt).all()),
        bookmarks=list(db.scalars(bm_stmt).all()),
    )
