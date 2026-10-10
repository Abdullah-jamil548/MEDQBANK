"""Classify past-paper PDFs as option MCQs vs question-answer (SEQ/UQ).

Values stored on books.book.paper_format:
  - mcq_options  — A/B/C/D/E (or similar) choice questions
  - qa           — short/essay / define / key-style Q&A without choice options
  - mixed        — compilation with both (shown under both sections in the app)
"""
from __future__ import annotations

import re

PAPER_FORMAT_MCQ = "mcq_options"
PAPER_FORMAT_QA = "qa"
PAPER_FORMAT_MIXED = "mixed"

# Filename / title overrides when heuristics would mis-label
_OVERRIDES: dict[str, str] = {
    # Confirmed option-MCQ sources
    "embryology past papers mcqs": PAPER_FORMAT_MCQ,
    "anatomy topic wise past papers": PAPER_FORMAT_MCQ,
    "general anatomy (key to uhs)": PAPER_FORMAT_MCQ,
    "histology (key to uhs)": PAPER_FORMAT_MCQ,
    "lower limb past papers": PAPER_FORMAT_MCQ,
    # Clean SEQ / university short questions (not A–E)
    "biochemistry-1st year topical past papers": PAPER_FORMAT_QA,
    "histo topical past papers": PAPER_FORMAT_QA,
}


def _norm(text: str) -> str:
    s = text.lower().strip()
    s = re.sub(r"[_\-]+", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s


def infer_paper_format(*parts: str | None) -> str:
    blob = _norm(" ".join(p for p in parts if p))
    if not blob:
        return PAPER_FORMAT_QA

    for key, value in _OVERRIDES.items():
        if key in blob:
            return value

    # Strong option-MCQ signals
    if re.search(r"\bmcqs?\b|\bbcqs?\b|topic\s*wise|past\s*solved\s*mcqs?", blob):
        return PAPER_FORMAT_MCQ

    # SEQ / UQ / short-answer signals
    if re.search(
        r"\btopical\b|\bseq\b|short\s*essay|university\s*questions|"
        r"\buqs?\b|define|enumerate|draw and label",
        blob,
    ):
        return PAPER_FORMAT_QA

    # Large key / compiled books: mostly solved UQs, sometimes MCQ chapters
    if re.search(r"key\s*to\s*uhs|compiled\s*by|amna\s*iqbal|block-?\d|chapter-?\d\s*book", blob):
        return PAPER_FORMAT_MIXED

    return PAPER_FORMAT_QA
