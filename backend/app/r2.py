from __future__ import annotations

from typing import Any

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException, status

from app.config import Settings


class R2Service:
    """Thin Cloudflare R2 client (S3-compatible)."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._client = None

    @property
    def client(self):
        if self._client is None:
            if not self.settings.r2_configured:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=(
                        "R2 is not configured. Copy .env.example to .env and set "
                        "R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME."
                    ),
                )
            self._client = boto3.client(
                "s3",
                endpoint_url=self.settings.r2_endpoint_url,
                aws_access_key_id=self.settings.r2_access_key_id,
                aws_secret_access_key=self.settings.r2_secret_access_key,
                region_name=self.settings.r2_region,
                config=Config(signature_version="s3v4"),
            )
        return self._client

    _BOOK_EXTENSIONS = (".epub", ".pdf", ".html", ".htm", ".txt")

    @staticmethod
    def book_id_from_filename(filename: str) -> str:
        """books/foo.pdf -> book_id foo"""
        name = filename.rsplit("/", 1)[-1]
        if "." in name:
            return name.rsplit(".", 1)[0]
        return name

    def object_key(self, book_id: str, filename: str | None = None) -> str:
        """Preferred path: books/{book_id}/{filename}."""
        name = filename or "book.epub"
        return f"books/{book_id}/{name}"

    def _normalize_object(self, obj: dict[str, Any]) -> dict[str, Any]:
        key = obj["Key"]
        return {
            "key": key,
            "filename": key.rsplit("/", 1)[-1],
            "size": obj.get("Size", 0),
            "last_modified": obj.get("LastModified").isoformat()
            if obj.get("LastModified")
            else None,
        }

    def _list_prefix(self, prefix: str, *, delimiter: str | None = None, max_keys: int = 100) -> dict[str, Any]:
        kwargs: dict[str, Any] = {
            "Bucket": self.settings.r2_bucket_name,
            "Prefix": prefix,
            "MaxKeys": max_keys,
        }
        if delimiter is not None:
            kwargs["Delimiter"] = delimiter
        try:
            return self.client.list_objects_v2(**kwargs)
        except ClientError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"R2 list failed: {exc}",
            ) from exc

    def head_object(self, key: str) -> dict[str, Any]:
        try:
            return self.client.head_object(
                Bucket=self.settings.r2_bucket_name,
                Key=key,
            )
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code in {"404", "NoSuchKey", "NotFound"}:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Object not found in R2: {key}",
                ) from exc
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"R2 head_object failed: {code or str(exc)}",
            ) from exc

    def list_books(self, prefix: str = "books/", max_keys: int = 200) -> list[dict[str, Any]]:
        """
        List books from either layout:
        - Folder: books/{book_id}/file.epub
        - Flat:   books/{book_id}.pdf
        """
        response = self._list_prefix(prefix, delimiter="/", max_keys=max_keys)
        books: list[dict[str, Any]] = []

        # folders: books/anatomy-101/
        for item in response.get("CommonPrefixes", []):
            folder = item["Prefix"].rstrip("/")
            book_id = folder.split("/")[-1]
            books.append(
                {
                    "book_id": book_id,
                    "prefix": item["Prefix"],
                    "layout": "folder",
                }
            )

        # flat files: books/bailey.pdf
        for obj in response.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/") or key == prefix:
                continue
            # only direct children of books/
            relative = key[len(prefix) :] if key.startswith(prefix) else key
            if "/" in relative:
                continue
            books.append(
                {
                    "book_id": self.book_id_from_filename(relative),
                    "key": key,
                    "size": obj.get("Size", 0),
                    "last_modified": obj.get("LastModified").isoformat()
                    if obj.get("LastModified")
                    else None,
                    "layout": "flat",
                }
            )

        seen: set[str] = set()
        unique: list[dict[str, Any]] = []
        for book in books:
            bid = book["book_id"]
            if bid not in seen:
                seen.add(bid)
                unique.append(book)
        return unique

    def list_book_objects(self, book_id: str) -> list[dict[str, Any]]:
        """
        Resolve objects for a book_id from:
        1) books/{book_id}/*          (folder layout)
        2) books/{book_id}.<ext>      (flat layout)
        3) books/{exact-filename}     if book_id includes extension
        """
        # 1) folder layout
        folder_prefix = f"books/{book_id}/"
        folder_response = self._list_prefix(folder_prefix, max_keys=100)
        folder_objects = [
            self._normalize_object(obj)
            for obj in folder_response.get("Contents", [])
            if not obj["Key"].endswith("/")
        ]
        if folder_objects:
            return folder_objects

        # 2) flat: books/{book_id}.pdf (and siblings with same stem)
        flat_matches: list[dict[str, Any]] = []
        books_root = self._list_prefix("books/", delimiter="/", max_keys=200)
        for obj in books_root.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue
            filename = key.rsplit("/", 1)[-1]
            stem = self.book_id_from_filename(filename)
            # match stem, or full filename if client passes it as book_id
            if stem == book_id or filename == book_id:
                flat_matches.append(self._normalize_object(obj))

        if flat_matches:
            return flat_matches

        # 3) direct head for common extensions (faster path / exact key)
        candidates = [f"books/{book_id}"]
        if "." not in book_id:
            candidates.extend(f"books/{book_id}{ext}" for ext in self._BOOK_EXTENSIONS)

        found: list[dict[str, Any]] = []
        for key in candidates:
            try:
                meta = self.head_object(key)
            except HTTPException as exc:
                if exc.status_code == status.HTTP_404_NOT_FOUND:
                    continue
                raise
            found.append(
                {
                    "key": key,
                    "filename": key.rsplit("/", 1)[-1],
                    "size": int(meta.get("ContentLength", 0)),
                    "last_modified": meta.get("LastModified").isoformat()
                    if meta.get("LastModified")
                    else None,
                }
            )

        if found:
            return found

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                f"No objects found for book_id={book_id}. "
                f"Upload as books/{book_id}/file.pdf or books/{book_id}.pdf"
            ),
        )

    def create_presigned_get_url(
        self,
        key: str,
        expires_in: int | None = None,
        response_content_disposition: str | None = None,
    ) -> str:
        """Short-lived URL so Flutter can stream from R2 directly (not via FastAPI)."""
        params: dict[str, Any] = {
            "Bucket": self.settings.r2_bucket_name,
            "Key": key,
        }
        # Encourage in-browser / in-app viewing rather than Save As
        if response_content_disposition:
            params["ResponseContentDisposition"] = response_content_disposition

        try:
            return self.client.generate_presigned_url(
                "get_object",
                Params=params,
                ExpiresIn=expires_in or self.settings.r2_signed_url_expires,
            )
        except ClientError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to sign R2 URL: {exc}",
            ) from exc

    def get_object_bytes(self, key: str, max_bytes: int = 5_000_000) -> tuple[bytes, str]:
        """
        Fetch object through the API for small test files only.
        Do not use this for large production books.
        """
        meta = self.head_object(key)
        size = int(meta.get("ContentLength", 0))
        if size > max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=(
                    f"Object is {size} bytes. Use /books/{{id}}/access for signed URL "
                    f"streaming instead of proxying through the API (limit {max_bytes})."
                ),
            )

        try:
            obj = self.client.get_object(
                Bucket=self.settings.r2_bucket_name,
                Key=key,
            )
        except ClientError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"R2 get_object failed: {exc}",
            ) from exc

        body = obj["Body"].read()
        content_type = obj.get("ContentType") or "application/octet-stream"
        return body, content_type

    def open_object_stream(self, key: str) -> tuple[Any, str, int]:
        """Return (body_stream, content_type, size) for streaming downloads."""
        try:
            obj = self.client.get_object(
                Bucket=self.settings.r2_bucket_name,
                Key=key,
            )
        except ClientError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"R2 get_object failed: {exc}",
            ) from exc

        content_type = obj.get("ContentType") or "application/pdf"
        size = int(obj.get("ContentLength") or 0)
        return obj["Body"], content_type, size

    def ensure_public_read_cors(self) -> None:
        """Allow browser apps to GET presigned URLs from any origin."""
        try:
            self.client.put_bucket_cors(
                Bucket=self.settings.r2_bucket_name,
                CORSConfiguration={
                    "CORSRules": [
                        {
                            "AllowedOrigins": ["*"],
                            "AllowedMethods": ["GET", "HEAD"],
                            "AllowedHeaders": ["*"],
                            "ExposeHeaders": [
                                "ETag",
                                "Content-Length",
                                "Content-Type",
                                "Content-Disposition",
                            ],
                            "MaxAgeSeconds": 86400,
                        }
                    ]
                },
            )
        except ClientError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to set R2 CORS: {exc}",
            ) from exc
