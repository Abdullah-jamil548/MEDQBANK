import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class College(Base):
    __tablename__ = "college"
    __table_args__ = {"schema": "users"}

    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    city: Mapped[str] = mapped_column(Text, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")

    users: Mapped[list["User"]] = relationship(back_populates="college")


class User(Base):
    __tablename__ = "user"
    __table_args__ = {"schema": "users"}

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    full_name: Mapped[str] = mapped_column(Text, nullable=False)
    email: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(Text, nullable=True)
    hashed_password: Mapped[str | None] = mapped_column(Text, nullable=True)
    auth_provider: Mapped[str] = mapped_column(Text, nullable=False, server_default="email")
    google_sub: Mapped[str | None] = mapped_column(Text, unique=True, nullable=True)
    college_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.college.college_id"),
        nullable=True,
    )
    mbbs_year: Mapped[str | None] = mapped_column(Text, nullable=True)
    has_avatar: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    streak_days: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    notifications_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    onboarding_done: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    subscription_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    hide_presence: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    hide_reading_activity: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    college: Mapped[College | None] = relationship(back_populates="users")


class Friendship(Base):
    __tablename__ = "friendship"
    __table_args__ = (
        UniqueConstraint("requester_id", "addressee_id", name="uq_friendship_pair"),
        {"schema": "users"},
    )

    friendship_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    requester_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
    )
    addressee_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default="pending")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Book(Base):
    __tablename__ = "book"
    __table_args__ = {"schema": "books"}

    book_id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str | None] = mapped_column(Text, nullable=True)
    subject: Mapped[str | None] = mapped_column(Text, nullable=True)
    year_label: Mapped[str | None] = mapped_column(Text, nullable=True)
    blurb: Mapped[str | None] = mapped_column(Text, nullable=True)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    format: Mapped[str] = mapped_column(Text, nullable=False, server_default="pdf")
    r2_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    content_type: Mapped[str | None] = mapped_column(Text, nullable=True)
    # book | past_paper — keeps past papers out of the main library feed
    content_kind: Mapped[str] = mapped_column(Text, nullable=False, server_default="book")
    # Chapter map for scanned PDFs that have no embedded outline.
    outline: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Progress(Base):
    __tablename__ = "progress"
    __table_args__ = (
        UniqueConstraint("user_id", "book_id", name="uq_progress_user_book"),
        {"schema": "books"},
    )

    progress_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user.user_id", ondelete="CASCADE"), nullable=False
    )
    book_id: Mapped[str] = mapped_column(
        Text, ForeignKey("books.book.book_id", ondelete="CASCADE"), nullable=False
    )
    page_no: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    progress_pct: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Bookmark(Base):
    __tablename__ = "bookmark"
    __table_args__ = (
        UniqueConstraint("user_id", "book_id", "page_no", name="uq_bookmark_user_book_page"),
        {"schema": "books"},
    )

    bookmark_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user.user_id", ondelete="CASCADE"), nullable=False
    )
    book_id: Mapped[str] = mapped_column(
        Text, ForeignKey("books.book.book_id", ondelete="CASCADE"), nullable=False
    )
    page_no: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Highlight(Base):
    __tablename__ = "highlight"
    __table_args__ = {"schema": "books"}

    highlight_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user.user_id", ondelete="CASCADE"), nullable=False
    )
    book_id: Mapped[str] = mapped_column(
        Text, ForeignKey("books.book.book_id", ondelete="CASCADE"), nullable=False
    )
    page_no: Mapped[int] = mapped_column(Integer, nullable=False)
    selected_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    rects: Mapped[dict | list | None] = mapped_column(JSONB, nullable=True)
    text_color: Mapped[str] = mapped_column(Text, nullable=False, server_default="amber")
    note: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Note(Base):
    __tablename__ = "note"
    __table_args__ = {"schema": "books"}

    note_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user.user_id", ondelete="CASCADE"), nullable=False
    )
    book_id: Mapped[str] = mapped_column(
        Text, ForeignKey("books.book.book_id", ondelete="CASCADE"), nullable=False
    )
    page_no: Mapped[int] = mapped_column(Integer, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ChatMessage(Base):
    __tablename__ = "chat_message"
    __table_args__ = {"schema": "users"}

    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    recipient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    message_type: Mapped[str] = mapped_column(Text, nullable=False, server_default="text")
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    book_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    book_title: Mapped[str | None] = mapped_column(Text, nullable=True)
    page_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    selected_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), index=True
    )
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ChatMute(Base):
    """User muted notifications from a specific friend chat."""

    __tablename__ = "chat_mute"
    __table_args__ = (
        UniqueConstraint("user_id", "muted_user_id", name="uq_chat_mute_pair"),
        {"schema": "users"},
    )

    mute_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    muted_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class ActivityHourUser(Base):
    """Unique user presence per UTC hour (used for PKT activity graphs)."""

    __tablename__ = "activity_hour_user"
    __table_args__ = (
        UniqueConstraint("hour_start", "user_id", name="uq_activity_hour_user"),
        {"schema": "users"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    hour_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
