#!/usr/bin/env python3
"""
DWG File Organization -- READ-ONLY inventory scanner.

WHAT THIS DOES
    Scans ONLY your Desktop and Documents folders, looks at each file, and
    writes a single markdown report describing what it found and what it
    *would* suggest doing. It proposes; it never disposes.

WHAT THIS DOES NOT DO (by design -- there is no code in here that can)
    - It does NOT rename any file.
    - It does NOT move, copy, or delete any file.
    - It does NOT open or read the *contents* of your documents.
      (It only reads the filename, size, and last-modified date -- the same
       information Finder/Explorer shows you.)
    - It refuses to scan anything outside Desktop and Documents.

The only thing it ever writes is the report file itself, and you choose
where that goes with --out (default: your current folder).

USAGE
    python3 scan_inventory.py                 # scan Desktop + Documents, top level only
    python3 scan_inventory.py --recursive     # also look inside subfolders
    python3 scan_inventory.py --roots desktop # scan only Desktop
    python3 scan_inventory.py --demo ./demo   # scan the bundled fake files (for learning)
    python3 scan_inventory.py --out ~/Desktop # choose where the report is written

This is stdlib-only. Any Python 3.8+ will run it, nothing to install.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# SAFETY RAILS
# ---------------------------------------------------------------------------
# The scanner will refuse to look anywhere that is not one of these folders
# (or a subfolder of them). This is the guardrail that keeps the experiment
# contained to Desktop + Documents.
ALLOWED_ROOT_NAMES = {"Desktop", "Documents"}


def home_root(name: str) -> Path:
    """Return ~/Desktop or ~/Documents for the current user, cross-platform."""
    return Path.home() / name


# ---------------------------------------------------------------------------
# CATEGORY RULES  (real-estate focused)
# ---------------------------------------------------------------------------
# Each rule = (Category name, Suggested destination subfolder, [keywords]).
# Keywords are matched against the lowercased filename. Order matters only for
# display; scoring below handles overlaps.
CATEGORY_RULES = [
    ("Purchase & Sale Agreements", "Real Estate/01 Purchase Agreements",
     ["purchase", "sale agreement", "psa", "contract", "offer", "counter",
      "ratified", "addendum", "amendment"]),
    ("Listing Documents", "Real Estate/02 Listings",
     ["listing", "listing agreement", "mls", "just listed", "coming soon"]),
    ("Disclosures", "Real Estate/03 Disclosures",
     ["disclosure", "tds", "spds", "lead", "lead-based", "seller disclosure",
      "natural hazard", "nhd"]),
    ("Inspections", "Real Estate/04 Inspections",
     ["inspection", "inspect", "pest", "termite", "roof", "sewer", "hvac"]),
    ("Appraisals & Valuations", "Real Estate/05 Appraisals",
     ["appraisal", "appraised", "bpo", "cma", "comparative market", "valuation"]),
    ("Closing & Settlement", "Real Estate/06 Closing",
     ["closing", "settlement", "hud", "hud-1", "closing disclosure", "alta",
      "escrow", "final walk"]),
    ("Title & Deed", "Real Estate/07 Title & Deed",
     ["title", "deed", "grant deed", "warranty deed", "preliminary title",
      "prelim", "vesting"]),
    ("Loan & Financing", "Real Estate/08 Financing",
     ["mortgage", "loan", "pre-approval", "preapproval", "pre-qual", "prequal",
      "lender", "financing", "promissory", "underwriting"]),
    ("Leases & Rentals", "Real Estate/09 Leases",
     ["lease", "rental", "tenant", "rent roll", "occupancy"]),
    ("Commissions & Financials", "Real Estate/10 Financials",
     ["commission", "invoice", "receipt", "statement", "1099", "referral",
      "payout", "ledger"]),
    ("Insurance", "Real Estate/11 Insurance",
     ["insurance", "policy", "homeowners", "hazard", "flood", "warranty plan"]),
    ("Taxes & Assessments", "Real Estate/12 Taxes",
     ["tax", "assessment", "w9", "w-9", "1098", "property tax"]),
    ("Marketing Material", "Real Estate/13 Marketing",
     ["flyer", "brochure", "postcard", "marketing", "open house", "ad",
      "advert", "social", "campaign"]),
    ("Photos & Media", "Real Estate/14 Photos & Media",
     ["photo", "image", "drone", "headshot", "virtual tour", "floor plan",
      "floorplan"]),
    ("Correspondence", "Real Estate/15 Correspondence",
     ["email", "letter", "correspondence", "memo", "note", "thread"]),
]

# Extension-based hints (used when the filename has no strong keyword).
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".tif", ".tiff",
              ".gif", ".bmp", ".webp"}
VIDEO_EXTS = {".mp4", ".mov", ".m4v", ".avi", ".mkv"}
DOC_EXTS = {".pdf", ".doc", ".docx", ".rtf", ".txt", ".pages"}
SHEET_EXTS = {".xls", ".xlsx", ".csv", ".numbers"}
SLIDE_EXTS = {".ppt", ".pptx", ".key"}

FILE_TYPE_LABELS = {
    **{e: "Image" for e in IMAGE_EXTS},
    **{e: "Video" for e in VIDEO_EXTS},
    **{e: "Document" for e in DOC_EXTS},
    **{e: "Spreadsheet" for e in SHEET_EXTS},
    **{e: "Presentation" for e in SLIDE_EXTS},
    ".zip": "Archive", ".rar": "Archive", ".7z": "Archive",
}

# Filenames that almost certainly need a human to look at them.
SENSITIVE_HINTS = ["ssn", "social security", "passport", "driver", "license",
                   "dl ", "bank", "routing", "account number", "wire",
                   "wiring", "voided check", "credit card", "w-9", "w9"]

GENERIC_HINTS = ["untitled", "document", "new doc", "scan", "img_", "image_",
                 "dsc_", "photo_", "screenshot", "doc1", "final", "copy",
                 "unknown", "temp", "test"]

NOISE_WORDS = ["final", "finalfinal", "copy", "copy2", "new", "updated",
               "version", "ver", "draft", "v1", "v2", "v3", "latest", "use this"]

# ---------------------------------------------------------------------------
# ANALYSIS
# ---------------------------------------------------------------------------


def _keyword_hit(keyword: str, name_lower: str) -> bool:
    """Whole-word(ish) match so 'title' does NOT match inside 'untitled'.

    Boundaries are 'not a letter or digit', which lets multi-word keywords
    like 'sale agreement' and hyphenated ones like 'lead-based' still match.
    """
    k = keyword.strip()
    if not k:
        return False
    pattern = r"(?<![a-z0-9])" + re.escape(k) + r"(?![a-z0-9])"
    return re.search(pattern, name_lower) is not None


def categorize(name_lower: str, ext: str):
    """Return (category, destination, confidence, matched_keywords)."""
    scores = []
    for cat, dest, keywords in CATEGORY_RULES:
        hits = [k.strip() for k in keywords if _keyword_hit(k, name_lower)]
        if hits:
            scores.append((len(hits), cat, dest, hits))

    if scores:
        scores.sort(reverse=True)
        top = scores[0]
        # Confidence: strong if a clear single winner or several keyword hits.
        strong = top[0] >= 2 or (len(scores) == 1)
        tie = len(scores) > 1 and scores[1][0] == top[0]
        if tie:
            confidence = "Low"          # ambiguous between categories
        elif strong:
            confidence = "High"
        else:
            confidence = "Medium"
        return top[1], top[2], confidence, top[3]

    # No keyword hit -> fall back to file type.
    if ext in IMAGE_EXTS or ext in VIDEO_EXTS:
        return ("Photos & Media", "Real Estate/14 Photos & Media",
                "Low", ["(by file type)"])

    return ("Uncategorized -- needs review", "Real Estate/00 Needs Review",
            "Low", [])


def clean_descriptor(stem: str) -> str:
    """Turn a messy filename stem into a tidy hyphenated descriptor."""
    s = stem.lower()
    s = re.sub(r"[_\s]+", "-", s)              # spaces/underscores -> hyphen
    s = re.sub(r"[^a-z0-9\-]", "", s)          # drop other punctuation
    tokens = [t for t in s.split("-") if t and t not in NOISE_WORDS]
    s = "-".join(tokens)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or "untitled"


def name_is_clean(name: str) -> bool:
    """Heuristic: does the CURRENT name already look tidy?"""
    stem = Path(name).stem
    if " " in name:
        return False
    if re.search(r"[^A-Za-z0-9_.\-]", name):    # special chars
        return False
    if re.search(r"\(\d+\)|copy|final|untitled|^img[_-]?\d+|^dsc|^scan",
                 stem, re.IGNORECASE):
        return False
    if name != name.strip():
        return False
    return True


def suggest_clean_name(name: str, category: str, mtime: _dt.datetime) -> str:
    ext = Path(name).suffix.lower()
    cat_slug = re.sub(r"[^a-z0-9]+", "-",
                      category.lower().split("--")[0]).strip("-")
    desc = clean_descriptor(Path(name).stem)
    datestr = mtime.strftime("%Y-%m-%d")
    return f"{cat_slug}__{desc}__{datestr}{ext}"


def review_reasons(name_lower: str, category: str, confidence: str,
                   matched) -> list:
    reasons = []
    if any(h in name_lower for h in SENSITIVE_HINTS):
        reasons.append("Possible sensitive/personal info -- verify before moving")
    if category.startswith("Uncategorized"):
        reasons.append("Could not determine category from the name")
    if confidence == "Low" and not category.startswith("Uncategorized"):
        reasons.append("Low confidence / ambiguous category")
    if any(g in name_lower for g in GENERIC_HINTS):
        reasons.append("Very generic name -- can't tell what it is")
    if matched and matched == ["(by file type)"]:
        reasons.append("Guessed only from file extension, not the name")
    return reasons


def analyze_file(path: Path) -> dict:
    stat = path.stat()
    mtime = _dt.datetime.fromtimestamp(stat.st_mtime)
    name = path.name
    name_lower = name.lower()
    ext = path.suffix.lower()

    category, dest, confidence, matched = categorize(name_lower, ext)
    clean = name_is_clean(name)
    suggested = suggest_clean_name(name, category, mtime)
    reasons = review_reasons(name_lower, category, confidence, matched)

    return {
        "name": name,
        "type": FILE_TYPE_LABELS.get(ext, ext.lstrip(".").upper() or "File"),
        "path": str(path),
        "modified": mtime.strftime("%Y-%m-%d %H:%M"),
        "category": category,
        "clean": "Clean" if clean else "Needs correction",
        "suggested": suggested if not clean else name,
        "dest": dest,
        "confidence": confidence,
        "review": reasons,
        "size_kb": round(stat.st_size / 1024, 1),
    }


# ---------------------------------------------------------------------------
# SCANNING
# ---------------------------------------------------------------------------


def gather_files(root: Path, recursive: bool) -> list:
    if not root.exists():
        return []
    it = root.rglob("*") if recursive else root.glob("*")
    files = []
    for p in it:
        try:
            if p.is_file() and not p.name.startswith("."):
                files.append(p)
        except (OSError, PermissionError):
            continue
    return files


# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------


def md_escape(text: str) -> str:
    return str(text).replace("|", "\\|")


def build_report(records: list, scanned_roots: list, recursive: bool) -> str:
    today = _dt.date.today().isoformat()
    lines = []
    a = lines.append

    a(f"# DWG File Organization -- Test Report ({today})")
    a("")
    a("> **This is a READ-ONLY test.** Nothing on your computer was renamed, "
      "moved, or deleted. Every 'Suggested' value below is a *proposal* for "
      "your review only.")
    a("")
    a("## Scope of this scan")
    a("")
    for r in scanned_roots:
        a(f"- `{r}`")
    a("")
    a(f"- **Depth:** {'Recursive (into subfolders)' if recursive else 'Top level only'}")
    a(f"- **Files analyzed:** {len(records)}")
    a("")

    # ---- Summary ----------------------------------------------------------
    by_cat = {}
    by_conf = {"High": 0, "Medium": 0, "Low": 0}
    needs_fix = 0
    needs_review = [r for r in records if r["review"]]
    for r in records:
        by_cat[r["category"]] = by_cat.get(r["category"], 0) + 1
        by_conf[r["confidence"]] = by_conf.get(r["confidence"], 0) + 1
        if r["clean"] != "Clean":
            needs_fix += 1

    a("## Summary")
    a("")
    a(f"- **Names that look clean already:** {len(records) - needs_fix}")
    a(f"- **Names suggested for correction:** {needs_fix}")
    a(f"- **Flagged for human review:** {len(needs_review)}")
    a(f"- **Confidence:** {by_conf['High']} High / "
      f"{by_conf['Medium']} Medium / {by_conf['Low']} Low")
    a("")
    a("### Files by likely category")
    a("")
    a("| Category | Count |")
    a("| --- | ---: |")
    for cat, n in sorted(by_cat.items(), key=lambda x: (-x[1], x[0])):
        a(f"| {md_escape(cat)} | {n} |")
    a("")

    # ---- Human review section (surfaced first, on purpose) ---------------
    a("## Files that need your eyes first")
    a("")
    if not needs_review:
        a("_None flagged. Still, skim the full table below before approving "
          "any changes._")
    else:
        a("These were not confidently categorized, look sensitive, or have "
          "names too generic to judge automatically. **Do not auto-rename "
          "these.**")
        a("")
        a("| File | Why it needs review | Full path |")
        a("| --- | --- | --- |")
        for r in needs_review:
            why = "; ".join(r["review"])
            a(f"| {md_escape(r['name'])} | {md_escape(why)} | "
              f"`{md_escape(r['path'])}` |")
    a("")

    # ---- Full inventory ---------------------------------------------------
    a("## Full inventory")
    a("")
    a("| # | Current name | Type | Modified | Likely category | Name status | "
      "Suggested clean name | Suggested destination | Confidence | Review? |")
    a("| ---: | --- | --- | --- | --- | --- | --- | --- | --- | :---: |")
    for i, r in enumerate(records, 1):
        flag = "yes" if r["review"] else ""
        a("| {n} | {name} | {type} | {mod} | {cat} | {clean} | {sug} | "
          "{dest} | {conf} | {flag} |".format(
              n=i,
              name=md_escape(r["name"]),
              type=md_escape(r["type"]),
              mod=r["modified"],
              cat=md_escape(r["category"]),
              clean=r["clean"],
              sug=md_escape(r["suggested"]),
              dest=md_escape(r["dest"]),
              conf=r["confidence"],
              flag=flag,
          ))
    a("")

    # ---- Legend -----------------------------------------------------------
    a("## How to read this report")
    a("")
    a("- **Name status** -- *Clean* = the current name is already tidy; "
      "*Needs correction* = has spaces, version noise (\"final\", \"copy\"), "
      "or odd characters.")
    a("- **Suggested clean name** -- a proposed convention: "
      "`category__short-description__YYYY-MM-DD.ext`. Advisory only.")
    a("- **Suggested destination** -- the folder this file would go to *if* "
      "you approve an organizing pass later.")
    a("- **Confidence** -- *High* = clear keyword match; *Medium* = weak "
      "match; *Low* = guessed or ambiguous. Treat Low as \"check me.\"")
    a("- **Review?** -- `yes` means a human should confirm before any action.")
    a("")
    a("---")
    a("")
    a("_Generated by `scan_inventory.py` in read-only mode. "
      "No files were changed._")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------


def main(argv=None):
    p = argparse.ArgumentParser(
        description="READ-ONLY inventory scanner for Desktop + Documents.")
    p.add_argument("--roots", nargs="*", default=["desktop", "documents"],
                   help="Which roots to scan: desktop documents (default both).")
    p.add_argument("--recursive", action="store_true",
                   help="Also scan inside subfolders (default: top level only).")
    p.add_argument("--out", default=".",
                   help="Folder to write the report into (default: current).")
    p.add_argument("--demo", default=None,
                   help="Scan a demo folder instead of the real Desktop/Documents. "
                        "Point it at a folder containing Desktop/ and Documents/.")
    args = p.parse_args(argv)

    scanned_roots = []
    all_files = []

    if args.demo:
        base = Path(args.demo).expanduser().resolve()
        for name in ("Desktop", "Documents"):
            root = base / name
            if root.exists():
                scanned_roots.append(str(root))
                all_files.extend(gather_files(root, args.recursive))
        if not scanned_roots:
            print(f"[!] No Desktop/ or Documents/ found under {base}",
                  file=sys.stderr)
            return 1
    else:
        wanted = {r.lower() for r in args.roots}
        name_map = {"desktop": "Desktop", "documents": "Documents"}
        for key, folder in name_map.items():
            if key in wanted:
                root = home_root(folder)
                # SAFETY: only ever the two named folders.
                if root.name not in ALLOWED_ROOT_NAMES:
                    continue
                scanned_roots.append(str(root))
                if root.exists():
                    all_files.extend(gather_files(root, args.recursive))
                else:
                    print(f"[i] Not found (skipping): {root}", file=sys.stderr)

    records = [analyze_file(f) for f in sorted(all_files, key=lambda x: str(x).lower())]

    report = build_report(records, scanned_roots, args.recursive)

    today = _dt.date.today().isoformat()
    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"DWG_File_Organization_Test_Report_{today}.md"
    out_path.write_text(report, encoding="utf-8")

    print(f"[OK] Analyzed {len(records)} files (READ-ONLY -- nothing changed).")
    print(f"[OK] Report written to: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
