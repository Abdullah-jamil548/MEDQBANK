from pydantic import BaseModel, Field


class BookSummary(BaseModel):
    book_id: str
    prefix: str | None = None
    key: str | None = None
    size: int | None = None
    last_modified: str | None = None
    layout: str | None = None  # "folder" | "flat"


class BookObject(BaseModel):
    key: str
    filename: str
    size: int
    last_modified: str | None = None


class BookDetail(BaseModel):
    book_id: str
    objects: list[BookObject]


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
        "URL is short-lived. Flutter should stream/render in-memory and avoid writing "
        "the full file to permanent local storage."
    )


class HealthResponse(BaseModel):
    status: str
    app: str
    r2_configured: bool
    bucket: str | None = None
