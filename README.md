# DWG File Organization — Local Test

A **read-only** experiment for organizing real-estate documents. This first
phase only **looks** at your files and writes a report. It does **not** rename,
move, or delete anything. Nothing is touched until you review the report and
explicitly approve a next step.

---

## Why the report in this repo was generated from *fake* files

This project was set up inside a cloud container (Claude Code on the web), which
**cannot see your actual Desktop or Documents** — those live on your PC, not in
the cloud. That is a good thing for a safety test: there was zero chance of
touching a real file.

So the report under `reports/` was produced from the **dummy files in `demo/`**,
purely to show you the exact format. To inventory your *real* files, you run the
same script on your own computer (instructions below).

---

## What the scanner records for every file

| Field | Meaning |
| --- | --- |
| Current name | The filename as it is today |
| Type | Document / Spreadsheet / Image / etc. |
| Full path | Exactly where it lives |
| Last modified | Date/time from the file system |
| Likely category | Best-guess real-estate category from the name |
| Name status | *Clean* or *Needs correction* |
| Suggested clean name | A proposed tidy name (advisory only) |
| Suggested destination | Where it *would* go if you approve later |
| Confidence | High / Medium / Low |
| Review? | `yes` = a human should look before any action |

It reads only the **filename, size, and modified date** — never the contents of
your documents.

---

## Run it on your own PC (read-only, safe)

You need Python 3 (Mac usually has it; on Windows install from python.org and
tick "Add Python to PATH").

1. Download `scan_inventory.py` from this repo to your computer.
2. Open a terminal:
   - **Mac:** Terminal app
   - **Windows:** Command Prompt or PowerShell
3. Run one of:

```bash
# Gentle first run — only files sitting directly in Desktop and Documents:
python3 scan_inventory.py

# When you're ready for the deep scan (into every subfolder):
python3 scan_inventory.py --recursive

# Only one folder:
python3 scan_inventory.py --roots desktop

# Put the report on your Desktop instead of the current folder:
python3 scan_inventory.py --out ~/Desktop
```

> On Windows, if `python3` isn't found, use `python` instead.

It writes `DWG_File_Organization_Test_Report_YYYY-MM-DD.md`. Open it in any
markdown viewer, or just a text editor. **Read it. Nothing has changed on disk.**

---

## Try the demo first (recommended, to learn the format)

This repo ships a `demo/` folder of harmless fake files. Point the scanner at it
to see a full report without touching anything real:

```bash
python3 scan_inventory.py --demo ./demo --recursive --out ./reports/recursive
```

A pre-generated copy already lives in [`reports/`](reports/).

---

## The safety guarantees, concretely

- The script contains **no** `rename`, `move`, `copy`, or `delete` calls. There
  is nothing in it that can alter a file. (You can read it top to bottom — it's
  short and commented.)
- It refuses to scan anything except folders named **Desktop** and **Documents**.
- The only file it ever writes is the report itself, wherever you point `--out`.

---

## The phased plan (nothing past Phase 1 happens without your OK)

1. **Phase 1 — Inventory (this).** Scan Desktop + Documents, produce the report.
   Read-only. ✅ You are here.
2. **Phase 2 — Review together.** You read the report, correct any wrong
   categories, and decide the naming convention + folder structure you actually
   want. Nothing on disk changes.
3. **Phase 3 — Dry-run a rename/move plan.** A separate script would print
   *exactly* what it intends to do (old path → new path) as a preview, still
   changing nothing.
4. **Phase 4 — Apply, on a copy first.** Only after you approve the dry run, and
   only on a copy of a small test batch — never the live Ignite/business folders
   until the test batch is verified.

Your Ignite folder and any live business folder are **out of scope** and will
not be touched unless you explicitly say so.
