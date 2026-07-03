#!/bin/bash
# ============================================================
#  DWG File Organization -- Mac launcher (SAFE / READ-ONLY)
#  Double-click this file to scan your Desktop + Documents and
#  produce a report. It does NOT rename, move, or delete anything.
#  The report is saved RIGHT HERE, next to this file.
# ============================================================
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"

echo "============================================================"
echo "  DWG File Organization -- read-only scan"
echo "  This ONLY looks at your files and writes a report."
echo "  Nothing will be renamed, moved, or deleted."
echo "============================================================"
echo
echo "Working folder: $HERE"
echo

if ! command -v python3 >/dev/null 2>&1; then
  echo "------------------------------------------------------------"
  echo "  PROBLEM: Python 3 is not installed on this Mac."
  echo "  That is why no report appeared."
  echo
  echo "  Fix: install it from https://www.python.org/downloads/"
  echo "  then run this file again."
  echo "------------------------------------------------------------"
  echo
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# Save the report right next to this launcher (never a hidden Desktop).
python3 scan_inventory.py --out "$HERE"

echo
echo "============================================================"
echo "  DONE. The report was saved in THIS folder:"
echo "  $HERE"
echo
echo "  Look for a file starting with:"
echo "  DWG_File_Organization_Test_Report_"
echo "============================================================"
echo
echo "Want the deeper scan (into subfolders)? Tell Claude."
echo
read -n 1 -s -r -p "Press any key to close..."
