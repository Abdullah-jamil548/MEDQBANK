from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.router import router

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description=(
        "Single-router book API for testing Cloudflare R2 delivery. "
        "Use POST /api/v1/books/{book_id}/access for presigned URLs."
    ),
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "app": settings.app_name,
        "docs": "/docs",
        "health": "/api/v1/health",
        "books": "/api/v1/books",
        "hint": "Configure R2 in .env then open /docs to try get-book flow",
    }
