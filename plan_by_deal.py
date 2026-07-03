#!/usr/bin/env python3
"""
Build a BY-DEAL organization plan (preview only) from the user's real scan.

Structure:
  Deals/<Deal name>/<NN Document-type>/file
  Firm/<bucket>/file            (firm-wide, not tied to one asset)
  Personal/file
  System - Ignore/file

Read-only: reads the scan report, prints/writes a plan. No files are moved.
"""
from __future__ import annotations
import re, sys
from pathlib import Path
from classify_commercial import classify   # reuse v2 taxonomy

# --- Deals curated from the actual filenames (most specific first) ---
DEALS = [
 ("Hibbert (Mesa AZ)", ["hibbert"]),
 ("Moab", ["moab"]),
 ("Stryten", ["stryten"]),
 ("Butler Weldments (Project Torch)", ["butler weldments","project torch"]),
 ("Powertex", ["powertex"]),
 ("Cloverdale", ["cloverdale"]),
 ("ANR", ["anr bov","anr is","anr."]),
 ("Goodyear", ["goodyear"]),
 ("Ventura Blvd", ["ventura"]),
 ("Bronx", ["bronx"]),
 ("Broadview Apartments", ["broadview"]),
 ("Ridgeline", ["ridgeline"]),
 ("Kecy Metals", ["kecy"]),
 ("Sterling", ["sterling"]),
 ("Assa Abloy", ["assa abloy"]),
 ("Austin Iron", ["austin iron"]),
 ("Gutterman", ["gutterman"]),
 ("Sisler Properties", ["sisler"]),
 ("Stuckys", ["stuckys"]),
 ("Kinton / 1645 Jackson", ["kinton","1645jackson"]),
 ("FEV Development Center", ["fev development","auburn hills"]),
 ("301 E Sample", ["301_e_sample","301 e sample"]),
 ("Silver Strand", ["silver strand","silver_strand"]),
 ("323 Beach Ave", ["323beach","323 beach"]),
 ("13129 Sherry Lane", ["sherry_lane","sherry lane"]),
 ("1275 Sunset", ["1275sunset","1275 sunset"]),
 ("119 Greenbriar", ["greenbriar"]),
 ("4115 Zero Street (Fort Smith)", ["zero street","4115 zero"]),
]

SUBFOLDER = {
 "Offering & Marketing Materials": "01 Offering & Marketing",
 "LOIs & Term Sheets":             "02 LOIs & Term Sheets",
 "Offers, PSAs & Contracts":       "03 Offers & Contracts",
 "Underwriting & Financial Models":"04 Underwriting",
 "Debt & Financing":               "05 Debt & Financing",
 "Investor, Fund & Capital":       "06 Investor & Capital",
 "Due Diligence":                  "07 Due Diligence",
 "Leasing":                        "08 Leasing",
 "Closing & Legal":                "09 Closing & Legal",
 "Fees & Commissions":             "10 Fees & Commissions",
 "Wire & Banking (SENSITIVE)":     "11 Wire & Banking (SENSITIVE)",
 "Firm Admin / Internal":          "12 Admin",
 "Photos & Media":                 "13 Media",
 "Contacts & CRM":                 "14 Contacts",
 "Uncategorized -- needs review":  "00 Needs Review",
}

# Firm-wide destination when a file has no single deal.
FIRM_BUCKET = {
 "Investor, Fund & Capital":       "Firm/Fund & Investor Relations",
 "Offering & Marketing Materials": "Firm/Marketing",
 "Fees & Commissions":             "Firm/Finance & Commissions",
 "Wire & Banking (SENSITIVE)":     "Firm/Finance & Commissions/Wire (SENSITIVE)",
 "Contacts & CRM":                 "Firm/Contacts",
 "Firm Admin / Internal":          "Firm/Admin",
 "Debt & Financing":               "Firm/Debt & Financing",
 "Underwriting & Financial Models":"Firm/Underwriting",
 "Due Diligence":                  "Firm/Due Diligence",
 "Offers, PSAs & Contracts":       "Firm/Contracts",
 "Leasing":                        "Firm/Leasing",
 "Closing & Legal":                "Firm/Closing & Legal",
 "LOIs & Term Sheets":             "Firm/LOIs & Term Sheets",
 "Photos & Media":                 "Firm/Media",
 "Uncategorized -- needs review":  "Firm/00 Needs Review",
}

def find_deal(name_lower):
    for deal, keys in DEALS:
        if any(k in name_lower for k in keys):
            return deal
    return None

def destination(name, ext):
    cat, conf = classify(name, ext)
    nl = name.lower()
    if cat.startswith("System") or cat.startswith("Bookmarks"):
        return "System - Ignore", cat, conf
    if cat.startswith("Personal"):
        return "Personal", cat, conf
    deal = find_deal(nl)
    if deal:
        return f"Deals/{deal}/{SUBFOLDER.get(cat,'00 Needs Review')}", cat, conf
    return FIRM_BUCKET.get(cat, "Firm/00 Needs Review"), cat, conf

def main():
    src = Path(sys.argv[1])
    text = src.read_text(encoding="utf-8", errors="replace")
    rows = []
    for line in text.splitlines():
        m = re.match(r"\|\s*\d+\s*\|\s*(.+?)\s*\|\s*([A-Za-z0-9]*)\s*\|\s*([\d\-: ]+?)\s*\|", line)
        if m:
            name = m.group(1).replace("\\|", "|")
            ext = ("." + m.group(2).lower()) if m.group(2) else Path(name).suffix.lower()
            rows.append((name, ext, m.group(3).strip()))

    plan = []
    folder_counts = {}
    for name, ext, mod in rows:
        dest, cat, conf = destination(name, ext)
        plan.append((name, ext, mod, dest, cat, conf))
        folder_counts[dest] = folder_counts.get(dest, 0) + 1

    print(f"Planned {len(rows)} files into {len(folder_counts)} folders.\n")
    print("=== FOLDER TREE (file counts) ===")
    for folder in sorted(folder_counts):
        print(f"  {folder_counts[folder]:3d}  {folder}")

    L = ["# DWG File Organization -- BY-DEAL PLAN (preview, 2026-07-02)", "",
         "> Preview only. Nothing has been moved. This shows where each file "
         "*would* go under a Deal-first structure.", "",
         "## Folder tree (with file counts)", "",
         "| Folder | Files |", "| --- | ---: |"]
    for folder in sorted(folder_counts):
        L.append(f"| {folder} | {folder_counts[folder]} |")
    L += ["", "## Every file and where it would go", "",
          "| # | File | NEW location | Category | Confidence |",
          "| ---: | --- | --- | --- | --- |"]
    for i, (name, ext, mod, dest, cat, conf) in enumerate(plan, 1):
        safe = name.replace("|", "\\|")
        L.append(f"| {i} | {safe} | {dest}/ | {cat} | {conf} |")
    out = Path("reports") / "DWG_BY_DEAL_PLAN_2026-07-02.md"
    out.write_text("\n".join(L), encoding="utf-8")
    print(f"\nPlan written: {out}")

if __name__ == "__main__":
    main()
