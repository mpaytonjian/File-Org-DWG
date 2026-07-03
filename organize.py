#!/usr/bin/env python3
"""
DWG File Organization -- the SORTER (Phase 3/4).

This actually renames files and files them into category folders. It is built
to be safe:

  * DRY-RUN BY DEFAULT. Running it with no flags only PRINTS the plan
    (old path -> new path). It changes nothing until you add --apply.
  * WORKS ON A COPY by default when you use --copy-to, so your originals are
    never touched.
  * EVERY move is written to an undo log (a CSV), so any action is reversible.
  * Files flagged "needs human review" are moved into a single
    "00 Needs Review" folder with their ORIGINAL name kept, never auto-renamed.

It reuses the exact same categorization logic as scan_inventory.py, so the plan
matches the report.

USAGE
    # 1) See the plan only (nothing changes):
    python3 organize.py --demo ./demo --recursive

    # 2) Do it SAFELY into a brand-new copy folder (originals untouched):
    python3 organize.py --demo ./demo --recursive --copy-to ./demo_sorted --apply

    # 3) On your real files, preview first:
    python3 organize.py --recursive
    # then, only when happy, sort a COPY:
    python3 organize.py --recursive --copy-to ~/Desktop/Sorted_Test --apply
"""

from __future__ import annotations

import argparse
import csv
import datetime as _dt
import shutil
import sys
from pathlib import Path

# Reuse the report-side brain so plan == report.
from scan_inventory import (
    analyze_file, gather_files, home_root, ALLOWED_ROOT_NAMES,
)


def unique_target(target: Path) -> Path:
    """If target exists, add -2, -3, ... so we never overwrite anything."""
    if not target.exists():
        return target
    stem, suffix, parent = target.stem, target.suffix, target.parent
    i = 2
    while True:
        cand = parent / f"{stem}-{i}{suffix}"
        if not cand.exists():
            return cand
        i += 1


def plan_moves(records, out_base: Path):
    """Return list of (src, dst, action_note)."""
    moves = []
    for r in records:
        src = Path(r["path"])
        if r["review"]:
            # Never auto-rename review items; keep original name, quarantine.
            dst_dir = out_base / "Real Estate" / "00 Needs Review"
            dst_name = src.name
            note = "review -- kept original name"
        else:
            dst_dir = out_base / r["dest"]
            dst_name = r["suggested"]
            note = f"{r['category']} ({r['confidence']} confidence)"
        dst = unique_target(dst_dir / dst_name)
        moves.append((src, dst, note))
    return moves


def main(argv=None):
    p = argparse.ArgumentParser(description="Sort real-estate documents (safe).")
    p.add_argument("--roots", nargs="*", default=["desktop", "documents"])
    p.add_argument("--recursive", action="store_true")
    p.add_argument("--demo", default=None,
                   help="Sort a demo folder (containing Desktop/ and Documents/).")
    p.add_argument("--copy-to", default=None,
                   help="Sort into a COPY at this path; originals untouched. "
                        "Strongly recommended for the first real run.")
    p.add_argument("--apply", action="store_true",
                   help="Actually perform the moves. Without this it's a dry run.")
    args = p.parse_args(argv)

    # ---- gather the same file set the scanner would ----
    all_files, scanned = [], []
    if args.demo:
        base = Path(args.demo).expanduser().resolve()
        for name in ("Desktop", "Documents"):
            root = base / name
            if root.exists():
                scanned.append(root)
                all_files.extend(gather_files(root, args.recursive))
    else:
        name_map = {"desktop": "Desktop", "documents": "Documents"}
        for key in {r.lower() for r in args.roots}:
            folder = name_map.get(key)
            if not folder:
                continue
            root = home_root(folder)
            if root.name not in ALLOWED_ROOT_NAMES:
                continue
            if root.exists():
                scanned.append(root)
                all_files.extend(gather_files(root, args.recursive))

    if not all_files:
        print("[!] No files found to sort.", file=sys.stderr)
        return 1

    records = [analyze_file(f) for f in sorted(all_files, key=lambda x: str(x).lower())]

    # ---- decide where sorted files go ----
    copying = args.copy_to is not None
    out_base = (Path(args.copy_to).expanduser().resolve() if copying
                else scanned[0].parent / "Real Estate Organized")

    moves = plan_moves(records, out_base)

    mode = ("APPLY" if args.apply else "DRY RUN (no changes)")
    action = ("COPY" if copying else "MOVE")
    print(f"\n=== DWG Organizer -- {mode} / files will be {action}D ===")
    print(f"Destination base: {out_base}\n")

    for src, dst, note in moves:
        rel_dst = dst.relative_to(out_base)
        print(f"  {src.name}")
        print(f"      -> {rel_dst}   [{note}]")

    if not args.apply:
        print(f"\n[DRY RUN] {len(moves)} files would be {action.lower()}d. "
              f"Nothing was changed.")
        print("Re-run with --apply (and ideally --copy-to) to do it for real.")
        return 0

    # ---- perform ----
    log_rows = []
    for src, dst, note in moves:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if copying:
            shutil.copy2(src, dst)
        else:
            shutil.move(str(src), str(dst))
        log_rows.append({"original": str(src), "new": str(dst), "note": note,
                         "action": action})

    today = _dt.date.today().isoformat()
    log_path = out_base / f"DWG_organize_log_{today}.csv"
    with log_path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["action", "original", "new", "note"])
        w.writeheader()
        w.writerows(log_rows)

    print(f"\n[OK] {action}D {len(moves)} files into: {out_base}")
    print(f"[OK] Undo log (every move, reversible): {log_path}")
    if copying:
        print("[OK] Your originals were NOT touched -- this was a copy.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
