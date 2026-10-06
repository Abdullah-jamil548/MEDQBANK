from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


# ----- system -----


class HealthResponse(BaseModel):
    status: str
    app: str
    r2_configured: bool
    db_configured: bool
    db_ok: bool | None = None
    bucket: str | None = None


# ----- auth / users -----


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=200)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    phone: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID
    full_name: str
    email: EmailStr


class CollegeOut(BaseModel):
    college_id: UUID
    name: str
    city: str

    model_config = {"from_attributes": True}


class ProfileUpdateRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=200)
    phone: str | None = None
    college_id: UUID | None = None
    mbbs_year: str | None = None
    has_avatar: bool | None = None
    avatar_url: str | None = None
    notifications_enabled: bool | None = None
    onboarding_done: bool | None = None
    hide_presence: bool | None = None
    hide_reading_activity: bool | None = None


class UserOut(BaseModel):
    user_id: UUID
    full_name: str
    email: EmailStr
    phone: str | None = None
    college_id: UUID | None = None
    mbbs_year: str | None = None
    has_avatar: bool
    avatar_url: str | None = None
    streak_days: int
    notifications_enabled: bool
    onboarding_done: bool
    is_active: bool
    subscription_expires_at: datetime | None = None
    last_seen_at: datetime | None = None
    hide_presence: bool = False
    hide_reading_activity: bool = False

    model_config = {"from_attributes": True}


# ----- friends / presence -----


class FriendRequestCreate(BaseModel):
    email: EmailStr


class UserSearchHit(BaseModel):
    user_id: UUID
    full_name: str
    email: EmailStr
    friendship_id: UUID | None = None
    friendship_status: str | None = None  # pending | accepted | declined
    direction: str | None = None  # outgoing | incoming


class FriendReadingActivity(BaseModel):
    book_id: str
    book_title: str
    page_no: int
    progress_pct: float | None = None
    updated_at: datetime


class FriendOut(BaseModel):
    friendship_id: UUID
    user_id: UUID
    full_name: str
    email: EmailStr
    status: str
    is_online: bool | None = None
    last_seen_at: datetime | None = None
    presence_hidden: bool = False
    reading_hidden: bool = False
    last_reading: FriendReadingActivity | None = None


class FriendRequestOut(BaseModel):
    friendship_id: UUID
    user_id: UUID
    full_name: str
    email: EmailStr
    direction: str  # incoming | outgoing
    created_at: datetime


class PresenceOut(BaseModel):
    last_seen_at: datetime
    is_online: bool = True


# ----- chat -----


class ChatMessageCreate(BaseModel):
    message_type: str = Field(default="text", pattern="^(text|book_share)$")
    body: str | None = Field(default=None, max_length=4000)
    book_id: str | None = None
    book_title: str | None = None
    page_no: int | None = Field(default=None, ge=1)
    selected_text: str | None = Field(default=None, max_length=8000)


class ChatMessageOut(BaseModel):
    message_id: UUID
    sender_id: UUID
    recipient_id: UUID
    message_type: str
    body: str | None = None
    book_id: str | None = None
    book_title: str | None = None
    page_no: int | None = None
    selected_text: str | None = None
    created_at: datetime
    delivered_at: datetime | None = None
    read_at: datetime | None = None
    status: str = "sent"  # sent | delivered | seen
    mine: bool = False

    model_config = {"from_attributes": True}


class ChatThreadOut(BaseModel):
    friend_user_id: UUID
    full_name: str
    email: EmailStr
    last_message: ChatMessageOut | None = None
    unread_count: int = 0
    muted: bool = False


class MuteOut(BaseModel):
    friend_user_id: UUID
    muted: bool


# ----- books / R2 -----


class BookSummary(BaseModel):
    book_id: str
    title: str | None = None
    author: str | None = None
    subject: str | None = None
    year_label: str | None = None
    blurb: str | None = None
    size: int | None = None
    size_bytes: int | None = None
    format: str | None = None
    r2_key: str | None = None
    content_kind: str | None = "book"  # book | past_paper
    is_active: bool | None = None
    prefix: str | None = None
    key: str | None = None
    last_modified: str | None = None
    layout: str | None = None
    source: str | None = None  # "db" | "r2"


class BookObject(BaseModel):
    key: str
    filename: str
    size: int
    last_modified: str | None = None


class BookDetail(BaseModel):
    book_id: str
    title: str | None = None
    author: str | None = None
    subject: str | None = None
    year_label: str | None = None
    blurb: str | None = None
    size_bytes: int | None = None
    format: str | None = None
    r2_key: str | None = None
    is_active: bool | None = None
    objects: list[BookObject] = []


class BookAccessRequest(BaseModel):
    filename: str | None = Field(
        default=None,
        description=(
            "Optional. Leave null to auto-pick the book file. "
            "If set, use full name e.g. 'book.pdf' (extension optional)."
        ),
        examples=[None],
    )
    expires_in: int | None = Field(
        default=None,
        ge=30,
        le=3600,
        description="Signed URL lifetime in seconds (30–3600). Defaults to server setting.",
        examples=[300],
    )


class BookAccessResponse(BaseModel):
    book_id: str
    key: str
    filename: str
    size: int
    content_type_hint: str
    expires_in: int
    url: str
    delivery: str = Field(
        default="presigned_r2",
        description="Client should stream from this URL; do not persist to Downloads.",
    )
    note: str = (
        "URL is short-lived. Flutter should download once to app cache, then read offline. "
        "Persist highlights/notes locally and sync to API when online."
    )


class BookUpsertRequest(BaseModel):
    book_id: str
    title: str
    author: str | None = None
    subject: str | None = None
    year_label: str | None = None
    blurb: str | None = None
    size_bytes: int | None = None
    format: str = "pdf"
    r2_key: str | None = None
    content_type: str | None = None
    content_kind: str = "book"
    is_active: bool = True


# ----- progress / annotations -----


class ProgressUpsert(BaseModel):
    book_id: str
    page_no: int = Field(ge=1)
    progress_pct: float | None = Field(default=None, ge=0, le=1)


class ProgressOut(BaseModel):
    progress_id: UUID
    user_id: UUID
    book_id: str
    page_no: int
    progress_pct: float | None = None
    updated_at: datetime

    model_config = {"from_attributes": True}


class HighlightUpsert(BaseModel):
    highlight_id: UUID | None = None
    book_id: str
    page_no: int = Field(ge=1)
    selected_text: str | None = None
    rects: list[Any] | dict[str, Any] | None = None
    text_color: str = "amber"
    note: str = ""
    updated_at: datetime | None = None
    deleted: bool = False


class HighlightOut(BaseModel):
    highlight_id: UUID
    user_id: UUID
    book_id: str
    page_no: int
    selected_text: str | None = None
    rects: list[Any] | dict[str, Any] | None = None
    text_color: str
    note: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = {"from_attributes": True}


class NoteUpsert(BaseModel):
    note_id: UUID | None = None
    book_id: str
    page_no: int = Field(ge=1)
    text: str = Field(min_length=1)
    updated_at: datetime | None = None
    deleted: bool = False


class NoteOut(BaseModel):
    note_id: UUID
    user_id: UUID
    book_id: str
    page_no: int
    text: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = {"from_attributes": True}


class BookmarkCreate(BaseModel):
    book_id: str
    page_no: int = Field(ge=1)


class BookmarkOut(BaseModel):
    bookmark_id: UUID
    user_id: UUID
    book_id: str
    page_no: int
    created_at: datetime

    model_config = {"from_attributes": True}


class SyncPullResponse(BaseModel):
    highlights: list[HighlightOut]
    notes: list[NoteOut]
    progress: list[ProgressOut]
    bookmarks: list[BookmarkOut]


# ----- admin -----


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str = "admin"
    email: str


class AdminUserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=200)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    phone: str | None = None
    is_active: bool = True
    subscription_expires_at: datetime | None = None


class AdminUserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=200)
    email: EmailStr | None = None
    password: str | None = Field(default=None, min_length=6, max_length=128)
    phone: str | None = None
    is_active: bool | None = None
    subscription_expires_at: datetime | None = None


class AdminStats(BaseModel):
    users_total: int
    users_active: int
    books_total: int
    past_papers_total: int
    live_now: int = 0


class AdminLiveUser(BaseModel):
    user_id: UUID
    full_name: str
    email: EmailStr
    last_seen_at: datetime | None = None
    socket_online: bool = False


class AdminHourPoint(BaseModel):
    hour_label: str
    hour_iso: datetime
    unique_users: int


class AdminActivity(BaseModel):
    live_count: int
    live_users: list[AdminLiveUser]
    hours: list[AdminHourPoint]
