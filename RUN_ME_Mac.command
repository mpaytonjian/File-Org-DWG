#!/bin/bash
# ============================================================
#  DWG File Organization -- Mac launcher (SAFE / READ-ONLY)
#  Double-click this file to scan your Desktop + Documents and
#  produce a report. It does NOT rename, move, or delete anything.
# ============================================================
cd "$(dirname "$0")" || exit 1

echo "============================================================"
echo "  DWG File Organization -- read-only scan"
echo "  This ONLY looks at your files and writes a report."
echo "  Nothing will be renamed, moved, or deleted."
echo "============================================================"
echo

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found."
  echo "Install it from https://www.python.org/downloads/ then run this again."
  echo
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# Read-only scan of Desktop + Documents (top level). Report goes on your Desktop.
python3 scan_inventory.py --out "$HOME/Desktop"

echo
echo "Done. Open the report on your Desktop:"
echo "  DWG_File_Organization_Test_Report_$(date +%Y-%m-%d).md"
echo
echo "Want the deeper scan (into subfolders)? Tell Claude and we'll turn it on."
echo
read -n 1 -s -r -p "Press any key to close..."
