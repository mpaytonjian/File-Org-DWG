#!/usr/bin/env python3
"""
Commercial RE / private-equity classifier v2.

Re-reads the REAL scan report the user produced, and re-classifies every file
with a taxonomy built for DWG Capital Partners' actual documents (OM, BOV, LOI,
term sheet, underwriting, debt request, capital call, DD, wire, etc.) instead of
the residential-agent categories used in v1.

Read-only: it only reads the report text and prints/writes a corrected report.
"""

from __future__ import annotations
import re, sys, datetime as _dt
from pathlib import Path

# (Category, [keywords])  -- checked with whole-word matching, scored.
RULES = [
 ("Offering & Marketing Materials",
  ["om","bov","teaser","flyer","intro summary","portfolio","one page","one pager",
   "cma","tour package","broker pitch","brokerpitch","for brokers","firm intro",
   "service offering","buyerdeck","buyer deck","deck","holiday insert","cover"]),
 ("LOIs & Term Sheets",
  ["loi","term sheet","letter of intent","termsheet"]),
 ("Offers, PSAs & Contracts",
  ["offer","purchase","psa","sale leaseback","rfp","executed agreement",
   "option agreement","buy out","buyout","fee agreement"]),
 ("Underwriting & Financial Models",
  ["uw","underwriting","analysis","waterfall","gp economics","gp analysis",
   "project cost","income statement","draws","proforma","pro forma","model",
   "cost analysis","economics","interim","worst case","equity and project"]),
 ("Debt & Financing",
  ["debt request","debtrequest","loan","refinance","construction","guaranty",
   "financing","quote","submission"]),
 ("Investor, Fund & Capital",
  ["capital call","capital_call","investor","investors","fund","fund iii",
   " jv","+ cam jv","cam jv","subscription","ppm","distribution","padilla",
   "sbis","shares","fund launch","debt facility"]),
 ("Due Diligence",
  ["dd","due diligence","due_diligence","checklist","environmental","ust",
   "hex chrome","soft results","stabilization","stabilized","dd link",
   "dd request","dd checklist","report"]),
 ("Leasing",
  ["lease","nnn","rent roll","rentroll","tenant","estoppel","lease or sale"]),
 ("Closing & Legal",
  ["closing","settlement statement","settlement","release letter","escrow",
   "title","deed"]),
 ("Fees & Commissions",
  ["commission","billing","invoice","referral","prepaid","hard bid"]),
 ("Wire & Banking (SENSITIVE)",
  ["wire","wiring","wire instructions","bank copy","routing","account number"]),
 ("Contacts & CRM",
  ["contacts","client list","lenders","ria list","vcf"]),
 ("Firm Admin / Internal",
  ["overview","notes","timeline","file org","drafts","warmest regards",
   "ordering guide","how to submit"]),
]

PERSONAL = ["trump","biden","newsom","election","vote","litmus","sotu","soto",
            "reunion","comedy","memorial","bday","birthday","hotel","reservation",
            "costa rica","jaco","condominium","camming","legacy","midterm"]

# File EXTENSIONS that are almost always not business documents to organize.
SYSTEM_EXT = {".lnk",".exe",".msi",".url",".log"}
IMAGE_EXT = {".jpg",".jpeg",".png",".heic",".jfif",".gif",".bmp",".webp",".tif",".tiff"}
VIDEO_EXT = {".mp4",".mov",".m4v",".avi"}
SENSITIVE = ["wire","bank","routing","ssn","guaranty","account number"]

def whole(k, s):
    return re.search(r"(?<![a-z0-9])"+re.escape(k.strip())+r"(?![a-z0-9])", s) is not None

def classify(name, ext):
    nl = name.lower()
    # 1) system / junk by extension
    if ext in SYSTEM_EXT and ext != ".url":
        return "System & Installers (ignore)", "Low"
    if ext == ".url":
        return "Bookmarks / Web Links (ignore)", "Low"
    # 2) personal / non-business
    if any(whole(k, nl) for k in PERSONAL):
        return "Personal / Non-Business", "Medium"
    # 3) business categories, scored
    scores = []
    for cat, keys in RULES:
        hits = [k for k in keys if whole(k, nl)]
        if hits:
            scores.append((len(hits), cat))
    if scores:
        scores.sort(reverse=True)
        top = scores[0]
        tie = len(scores) > 1 and scores[1][0] == top[0]
        conf = "Low" if tie else ("High" if top[0] >= 2 else "Medium")
        return top[1], conf
    # 4) media fallback
    if ext in IMAGE_EXT or ext in VIDEO_EXT:
        return "Photos & Media", "Low"
    return "Uncategorized -- needs review", "Low"

def main():
    src = Path(sys.argv[1])
    text = src.read_text(encoding="utf-8", errors="replace")
    rows = []
    for line in text.splitlines():
        m = re.match(r"\|\s*\d+\s*\|\s*(.+?)\s*\|\s*([A-Za-z0-9]*)\s*\|\s*([\d\-: ]+?)\s*\|", line)
        if m:
            name = m.group(1).replace("\\|", "|")
            modified = m.group(3).strip()
            ext = ("." + m.group(2).lower()) if m.group(2) else Path(name).suffix.lower()
            rows.append((name, ext, modified))

    results = [(n, e, mod, *classify(n, e)) for (n, e, mod) in rows]

    # tally
    counts = {}
    for _, _, _, cat, _ in results:
        counts[cat] = counts.get(cat, 0) + 1

    print(f"Parsed {len(rows)} files from {src.name}\n")
    print("=== NEW category distribution (commercial RE/PE taxonomy) ===")
    for cat, n in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
        print(f"  {n:3d}  {cat}")

    # write corrected report
    today = "2026-07-02"
    out = Path("reports") / f"DWG_CORRECTED_Commercial_Report_{today}.md"
    L = []
    L.append(f"# DWG File Organization -- CORRECTED Report (commercial RE/PE) ({today})")
    L.append("")
    L.append("> Re-classified with a taxonomy built for DWG Capital Partners' real "
             "documents. Read-only -- nothing on your computer changed.")
    L.append("")
    L.append("## New category distribution")
    L.append("")
    L.append("| Category | Count |")
    L.append("| --- | ---: |")
    for cat, n in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
        L.append(f"| {cat} | {n} |")
    L.append("")
    L.append("## Full re-classification")
    L.append("")
    L.append("| # | File | Type | Modified | NEW category | Confidence |")
    L.append("| ---: | --- | --- | --- | --- | --- |")
    for i, (n, e, mod, cat, conf) in enumerate(results, 1):
        safe = n.replace("|", "\\|")
        typ = e.lstrip(".").upper()
        L.append(f"| {i} | {safe} | {typ} | {mod} | {cat} | {conf} |")
    out.write_text("\n".join(L), encoding="utf-8")
    print(f"\nCorrected report written: {out}")

if __name__ == "__main__":
    main()
