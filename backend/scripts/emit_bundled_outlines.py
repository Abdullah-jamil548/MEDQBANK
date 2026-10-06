from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.book_outlines import SCANNED_OUTLINES


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


lines = [
    "/// Scanned PDFs with no embedded outline. Keep in sync with backend/app/book_outlines.py.",
    "/// Each row is [title, pdfPage, printedPage|null].",
    "const Map<String, List<List<Object?>>> kBundledOutlineRaw = {",
]
for bid, items in SCANNED_OUTLINES.items():
    lines.append(f"  '{bid}': [")
    for it in items:
        title = dart_escape(it["title"])
        page = it["page"]
        printed = it.get("printed")
        printed_lit = "null" if printed is None else str(printed)
        lines.append(f"    ['{title}', {page}, {printed_lit}],")
    lines.append("  ],")
lines.append("};")
lines.append("")

out = Path(__file__).resolve().parents[2] / "lib" / "domain" / "entities" / "bundled_book_outlines.dart"
out.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {out} books={len(SCANNED_OUTLINES)}")

