"""Scanned-PDF chapter maps (printed TOC → PDF page).

Native PDF outlines are used by the reader when present. These fallbacks
cover CamScanner / image-only library books with no embedded outline.
"""

from __future__ import annotations


def _ch(title: str, printed: int, offset: int, pages: int) -> dict:
    pdf = printed + offset
    if pdf < 1:
        pdf = 1
    if pdf > pages:
        pdf = pages
    return {"title": title, "page": pdf, "printed": printed}


def _toc(contents_pdf: int | None, offset: int, pages: int, items: list[tuple[str, int]]) -> list[dict]:
    out: list[dict] = []
    if contents_pdf:
        out.append({"title": "Contents", "page": contents_pdf, "printed": None})
    out.extend(_ch(title, printed, offset, pages) for title, printed in items)
    return out


SCANNED_OUTLINES: dict[str, list[dict]] = {
    "excel-community-medicine-13th-edition": _toc(
        6,
        6,
        489,
        [
            ("01. Basic Definitions", 1),
            ("02. Concepts of Health & Disease", 13),
            ("03. Epidemiology", 23),
            ("04. Communicable Diseases", 53),
            ("05. Non-communicable Diseases", 115),
            ("06. Immunology", 129),
            ("07. Screening & Sampling", 143),
            ("08. Biostatistics", 151),
            ("09. Demography", 165),
            ("10. Primary Healthcare", 177),
            ("11. Environment & Health", 187),
            ("12. Hospital Waste Management", 221),
            ("13. Occupational Health", 227),
            ("14. Reproductive Health", 239),
            ("15. Family Planning", 259),
            ("16. Nutrition", 271),
            ("17. Radiations", 299),
            ("18. Communication in Health Education", 303),
            ("19. IMNCI", 313),
            ("20. Disaster Management", 321),
            ("21. School Health Services", 329),
            ("22. Social & Behavioral Services", 335),
            ("23. Community Mental Health", 339),
            ("24. Medical Parasitology", 349),
            ("25. Miscellaneous", 355),
            ("Appendix 1. Multiple Choice Questions", 367),
            ("Appendix 2. Comprehensive MCQs Tests", 423),
            ("Appendix 3. UHS Data", 449),
            ("Appendix 4. OSPEs 2016", 453),
            ("Appendix 5. OSPEs 2017", 461),
            ("Appendix 6. OSPEs 2018", 471),
            ("Appendix 7. OSPEs 2019", 481),
            ("Appendix 8. Index", 487),
        ],
    ),
    "firdous-physiology-20th-edition": _toc(
        3,
        4,
        300,
        [
            ("01. Introduction, Cell & Genetics", 1),
            ("02. Membrane Physiology, Nerve & Muscle", 12),
            ("03. Heart", 26),
            ("04. Circulation", 40),
            ("05. Body Fluids", 70),
            ("06. Kidney", 76),
            ("07. Blood", 99),
            ("08. Respiration", 128),
            ("09. Central Nervous System", 146),
            ("10. Autonomic Nervous System", 177),
            ("11. Special Senses", 180),
            ("12. Skin, Sweat Glands & Body Temperature", 197),
            ("13. Gastro-intestinal Tract", 202),
            ("14. Endocrinology", 225),
            ("15. Reproduction", 257),
            ("16. Vitamins", 273),
        ],
    ),
    "firdous-histology-10th-edition": _toc(
        2,
        2,
        137,
        [
            ("01. The Cell", 3),
            ("02. Epithelium", 13),
            ("03. Glands", 19),
            ("04. Some Major Glands", 23),
            ("05. Supporting / Connective Tissue", 29),
            ("06. Connective Tissue Proper", 35),
            ("07. Skeletal Tissue (Cartilage & Bone)", 39),
            ("08. Blood", 45),
            ("09. Muscular Tissue", 49),
            ("10. Nervous Tissue", 55),
            ("11. Central Nervous System", 67),
            ("12. Circulatory System", 71),
            ("13. Lymphoid Tissue", 77),
            ("14. Digestive Tract (Oral Cavity)", 83),
            ("15. Digestive Tract (Tubular Structures)", 87),
            ("16. Female Reproductive System", 95),
            ("17. Male Reproductive System", 99),
            ("18. Urinary System", 103),
            ("19. Respiratory System", 109),
            ("20. Endocrine System", 113),
            ("21. Eye", 121),
            ("22. Ear", 125),
            ("23. Skin", 129),
            ("24. Review Recall", 133),
        ],
    ),
    "general-anatomy-by-laiq-hussain-5th-edition": _toc(
        4,
        5,
        146,
        [
            ("01. Introduction", 1),
            ("02. Anatomical Nomenclature", 9),
            ("03. Bones and Cartilages", 27),
            ("04. Joints", 49),
            ("05. Muscles", 65),
            ("06. Circulatory System", 83),
            ("07. Integumentary System", 101),
            ("08. Nervous System", 107),
            ("09. Imaging and Other Ways of Exploring the Body", 123),
            ("Index", 133),
        ],
    ),
    "medical-histology-by-laiq-hussain": _toc(
        3,
        3,
        252,
        [
            ("01. Introduction", 1),
            ("02. The Cell", 7),
            ("03. Epithelium", 33),
            ("04. Glands", 43),
            ("05. Connective Tissue", 47),
            ("06. Connective Tissue Proper", 55),
            ("07. Cartilage", 59),
            ("08. Bone", 65),
            ("09. Blood", 73),
            ("10. Muscle Tissue", 85),
            ("11. Nervous Tissue", 95),
            ("12. Cerebrum, Cerebellum and Spinal Cord", 109),
            ("13. Circulatory System", 115),
            ("14. Immune System and Lymphoid Organs", 125),
            ("15. Integumentary System", 141),
            ("16. Endocrine System", 151),
            ("17. Respiratory System", 161),
            ("18. Digestive Tract", 169),
            ("19. Organs Associated with the Digestive Tract", 191),
            ("20. Urinary System", 205),
            ("21. Male Reproductive System", 219),
            ("22. Female Reproductive System", 231),
            ("23. Eye", 243),
            ("24. Ear", 255),
            ("Index", 261),
        ],
    ),
    "shahbaz-s-medical-histology": _toc(
        8,
        9,
        83,
        [
            ("01. Introduction / Microscopy", 1),
            ("02. The Cell", 4),
            ("03. Epithelium", 11),
            ("04. Glands", 16),
            ("05. Connective Tissue", 19),
            ("06. Connective Tissue Proper", 25),
            ("07. Cartilage", 27),
            ("08. Bone", 29),
            ("09. Blood", 32),
            ("10. Muscular Tissue", 36),
            ("11. Nervous Tissue", 41),
            ("12. Cerebrum, Cerebellum and Spinal Cord", 48),
            ("13. Circulatory System", 51),
            ("14. Immune System and Lymphoid Organs", 55),
            ("15. Integumentary System", 64),
            ("16. Endocrine System", 70),
            ("17. Respiratory System", 76),
        ],
    ),
    "mushtaq-biochemistry-vol-1": _toc(
        5,
        12,
        491,
        [
            ("01. Biochemical Aspects of the Cell and its Components", 1),
            ("02. Physicochemical Principles", 15),
            ("03. Carbohydrates: General Aspects", 58),
            ("04. Amino Acids and Proteins", 89),
            ("05. Lipids: General Aspects", 121),
            ("06. Enzymes", 139),
            ("07. High-Energy Compounds", 176),
            ("08. Mitochondria and Oxidative Phosphorylation", 180),
            ("09. Bioenergetics and Redox Potentials", 198),
            ("10. Biochemistry of the Gastrointestinal Tract", 202),
            ("11. Carbohydrate Metabolism", 255),
            ("12. Lipid Metabolism", 292),
            ("13. Protein and Amino Acid Metabolism", 346),
            ("14. Nucleic Acids I: Purines, Pyrimidines, Nucleosides", 386),
            ("15. Nucleic Acids II: General Properties and Biosynthesis", 408),
            ("16. Nucleic Acids III: Transcription and Translation", 424),
            ("17. Nucleic Acids IV: Biochemical and Medical Genetics", 445),
            ("18. Mixed Function Oxidases / Xenobiotic Metabolism", 467),
            ("19. Methods Used to Study Cell Biochemistry", 472),
        ],
    ),
    "nims-physiology": [
        {"title": "Blood", "page": 1, "printed": 2},
        {"title": "Red Blood Cells, Anemia and Polycythemia", "page": 2, "printed": 3},
        {"title": "Hemoglobin", "page": 9, "printed": 10},
        {"title": "Leukocytes (WBC)", "page": 27, "printed": 34},
        {"title": "Macrophage System", "page": 28, "printed": 35},
        {"title": "Immunity & Allergy", "page": 42, "printed": 50},
        {"title": "Blood Groups", "page": 61, "printed": 70},
        {"title": "Haemostasis & Blood Coagulation", "page": 71, "printed": 82},
    ],
}


def outline_for_book(book_id: str | None, stored: list | dict | None = None) -> list[dict]:
    if isinstance(stored, list) and stored:
        return stored
    if not book_id:
        return []
    return list(SCANNED_OUTLINES.get(book_id) or [])


def seed_book_outlines() -> None:
    from app.db import SessionLocal
    from app.models import Book

    if SessionLocal is None:
        return
    db = SessionLocal()
    try:
        for book_id, outline in SCANNED_OUTLINES.items():
            row = db.get(Book, book_id)
            if row is None:
                continue
            row.outline = outline
        db.commit()
    finally:
        db.close()
