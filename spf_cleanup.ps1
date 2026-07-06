# ============================================================
#  SPF (Southern Perfection Fabrication) -- surgical cleanup
#  Runs LOCALLY on the SPF folder after you bring it to your PC
#  (Egnyte Desktop or a copy). Unlike the Egnyte connector, a
#  local script CAN move/rename -- so this executes the approved
#  cleanup for real.
#
#  SAFETY:
#   * DRY-RUN by default. Add -Apply to actually move.
#   * Touches ONLY the 14 named files below. Nothing else.
#   * Never deletes. Superseded/duplicate files are MOVED into
#     "_Archive (Superseded)" so everything is recoverable.
#   * Writes a CSV log of every move.
# ============================================================
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'

if(-not (Test-Path -LiteralPath $Root)){
  Write-Host "ERROR: folder not found:`n  $Root" -ForegroundColor Red
  exit 1
}
if($Root -notmatch 'Southern Perfection'){
  Write-Host "SAFETY STOP: the path doesn't look like the SPF folder." -ForegroundColor Yellow
  Write-Host "Point -Root at '...\19. Southern Perfection Fabrication'."
  exit 1
}

$ARCHIVE = '_Archive (Superseded)'

# Each op: Src (relative to SPF root), Dest (relative folder), Why.
$ops = @(
  # --- Superseded LOI drafts (final executed lives in '1. LOI & PSA') ---
  @{Src='Legacy\DWG_LOI_Southern Perfection.docx';        Dest=$ARCHIVE; Why='Superseded LOI draft'},
  @{Src='Legacy\DWG_LOI_Southern Perfection.pdf';         Dest=$ARCHIVE; Why='Superseded LOI draft'},
  @{Src='Legacy\DWG_LOI_Southern Perfection V2.docx';     Dest=$ARCHIVE; Why='Superseded LOI draft'},
  @{Src='Legacy\DWG_LOI_Southern Perfection V2 (1).docx'; Dest=$ARCHIVE; Why='Superseded LOI draft (dupe)'},
  @{Src='Legacy\DWG_LOI_Southern Perfection V2.pdf';      Dest=$ARCHIVE; Why='Superseded LOI draft'},
  @{Src='Legacy\DWG_LOI_Southern Perfection V3.docx';     Dest=$ARCHIVE; Why='Superseded LOI draft'},
  @{Src='Legacy\DWG_LOI_Southern Perfection_Final.pdf';   Dest=$ARCHIVE; Why='Superseded LOI draft'},
  # --- Exact duplicates (identical checksum to the kept copy) ---
  @{Src='1. LOI & PSA\CLEAN Lease Agreement (Southern Perfection - triple net) v.2.docx'; Dest=$ARCHIVE; Why='Exact dup; kept copy in 7. Tenant Lease + Insurance'},
  @{Src='7. Tenant Lease + Insurance\Legacy\Premises Pollution Application - DWG Completed 3-30-26 (1).pdf'; Dest=$ARCHIVE; Why='Exact dup of the copy being refiled to 7'},
  @{Src='5. Financials\Southern Perfection Fabrication-_DataBook_vF112625 (1).xlsx'; Dest=$ARCHIVE; Why='Dup of DataBook_vF112625.xlsx'},
  # --- Refile to correct home ---
  @{Src='Legacy\1.30_MeetingNotes.pdf';                              Dest='0. Deal Room'; Why='Refile: management call notes'},
  @{Src='Legacy\southern_perfection_highlights.pptx';                Dest='00. Marketing_MM_SPF\All Other Marketing_MM_SPF'; Why='Refile: marketing deck'},
  @{Src='Legacy\southern_perfection_highlights_final_dual_slides.pptx'; Dest='00. Marketing_MM_SPF\All Other Marketing_MM_SPF'; Why='Refile: marketing deck'},
  @{Src='1. LOI & PSA\Premises Pollution Application - DWG Completed 3-30-26 (1).pdf'; Dest='7. Tenant Lease + Insurance'; Why='Refile: insurance application (misfiled under LOI & PSA)'}
)

function UniqueTarget([string]$dir,[string]$name){
  $t = Join-Path $dir $name
  if(-not (Test-Path -LiteralPath $t)){ return $t }
  $stem = [IO.Path]::GetFileNameWithoutExtension($name)
  $ext  = [IO.Path]::GetExtension($name)
  $i = 2
  while($true){ $c = Join-Path $dir ("$stem-$i$ext"); if(-not (Test-Path -LiteralPath $c)){ return $c }; $i++ }
}

$mode = if($Apply){'APPLY (moving files)'}else{'DRY RUN (no changes)'}
Write-Host ""
Write-Host "=== SPF Cleanup -- $mode ===" -ForegroundColor Cyan
Write-Host "Root: $Root`n"

$log = @()
$done = 0; $missing = 0
foreach($op in $ops){
  $src = Join-Path $Root $op.Src
  $destDir = Join-Path $Root $op.Dest
  $name = Split-Path $op.Src -Leaf

  if(-not (Test-Path -LiteralPath $src)){
    Write-Host ("  MISSING (skip): {0}" -f $op.Src) -ForegroundColor Yellow
    $missing++
    continue
  }
  $target = UniqueTarget $destDir $name

  Write-Host ("  {0}" -f $op.Src)
  Write-Host ("      -> {0}\   [{1}]" -f $op.Dest, $op.Why) -ForegroundColor Gray

  if($Apply){
    if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Move-Item -LiteralPath $src -Destination $target
    $log += [pscustomobject]@{ From=$src; To=$target; Reason=$op.Why }
    $done++
  }
}

Write-Host ""
if($Apply){
  if($log.Count -gt 0){
    $archDir = Join-Path $Root $ARCHIVE
    if(-not (Test-Path -LiteralPath $archDir)){ New-Item -ItemType Directory -Force -Path $archDir | Out-Null }
    $logPath = Join-Path $archDir ("SPF_cleanup_log_" + (Get-Date -Format 'yyyy-MM-dd') + ".csv")
    $log | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8
    Write-Host ("DONE: moved {0} files. Missing/skipped: {1}." -f $done, $missing) -ForegroundColor Green
    Write-Host ("Reversible log: {0}" -f $logPath)
    Write-Host "Nothing was deleted. If Egnyte Desktop is syncing, these moves will sync to Egnyte."
  } else {
    Write-Host "No files moved (all were missing?). Check the Root path." -ForegroundColor Yellow
  }
} else {
  Write-Host ("DRY RUN complete. Would move {0} files; {1} missing/not found." -f ($ops.Count-$missing), $missing)
  Write-Host "Re-run with -Apply to perform the moves."
}
