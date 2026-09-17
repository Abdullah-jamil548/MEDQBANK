from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.config import Settings, get_settings
from app.r2 import R2Service
from app.schemas import (
    BookAccessRequest,
    BookAccessResponse,
    BookDetail,
    BookObject,
    BookSummary,
    HealthResponse,
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

    # Prefer common book formats
    preferred = (".epub", ".pdf", ".html", ".htm")
    for ext in preferred:
        for obj in objects:
            if obj["filename"].lower().endswith(ext):
                return obj
    return objects[0]


@router.get("/health", response_model=HealthResponse, tags=["system"])
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    return HealthResponse(
        status="ok",
        app=settings.app_name,
        r2_configured=settings.r2_configured,
        bucket=settings.r2_bucket_name if settings.r2_configured else None,
    )


@router.get("/books", response_model=list[BookSummary], tags=["books"])
def list_books(r2: R2Service = Depends(get_r2)) -> list[BookSummary]:
    """List books discovered under R2 prefix books/."""
    items = r2.list_books()
    return [BookSummary(**item) for item in items]


@router.get("/books/{book_id}", response_model=BookDetail, tags=["books"])
def get_book(book_id: str, r2: R2Service = Depends(get_r2)) -> BookDetail:
    """
    Return metadata + object list for a book (no file bytes).

    Supports:
    - books/{book_id}/file.pdf
    - books/{book_id}.pdf  (flat upload)
    """
    objects = r2.list_book_objects(book_id)
    return BookDetail(
        book_id=book_id,
        objects=[BookObject(**obj) for obj in objects],
    )


@router.post(
    "/books/{book_id}/access",
    response_model=BookAccessResponse,
    tags=["books"],
)
def get_book_access(
    book_id: str,
    body: BookAccessRequest | None = None,
    r2: R2Service = Depends(get_r2),
    settings: Settings = Depends(get_settings),
) -> BookAccessResponse:
    """
    Main integration path for Flutter:
    1) API checks the object exists in R2
    2) API returns a short-lived presigned URL
    3) Client streams from Cloudflare R2 directly (not through FastAPI)
    """
    body = body or BookAccessRequest()
    objects = r2.list_book_objects(book_id)
    chosen = _pick_object(objects, body.filename)

    # Verify object exists / refresh size
    meta = r2.head_object(chosen["key"])
    size = int(meta.get("ContentLength", chosen.get("size", 0)))
    expires_in = body.expires_in or settings.r2_signed_url_expires

    # inline = hint to open/view rather than attachment/download
    disposition = f'inline; filename="{chosen["filename"]}"'
    url = r2.create_presigned_get_url(
        key=chosen["key"],
        expires_in=expires_in,
        response_content_disposition=disposition,
    )

    return BookAccessResponse(
        book_id=book_id,
        key=chosen["key"],
        filename=chosen["filename"],
        size=size,
        content_type_hint=_guess_content_type(chosen["filename"]),
        expires_in=expires_in,
        url=url,
    )


@router.get("/books/{book_id}/content", tags=["books"])
def get_book_content_proxy(
    book_id: str,
    filename: str | None = Query(default=None),
    r2: R2Service = Depends(get_r2),
):
    """
    Test-only proxy: streams small files through FastAPI.
    For real apps / large books use POST /books/{book_id}/access instead.
    """
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
