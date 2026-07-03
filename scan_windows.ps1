# ============================================================
#  DWG File Organization -- Windows scanner (NO PYTHON NEEDED)
#  READ-ONLY. Looks at Desktop + Documents, writes ONE report.
#  Does NOT rename, move, or delete anything.
#  Correctly finds OneDrive-redirected Desktop/Documents.
# ============================================================
param([switch]$Recursive)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- Find the REAL Desktop + Documents (handles OneDrive) ----
$roots = @()
foreach ($f in @('Desktop','MyDocuments')) {
    $p = [Environment]::GetFolderPath($f)
    if ($p -and (Test-Path $p)) { $roots += $p }
}
$roots = $roots | Select-Object -Unique
if ($roots.Count -eq 0) { Write-Host "Could not locate Desktop/Documents."; exit 1 }

# ---- Category rules (real-estate) ----
$rules = @(
  @{ Name='Purchase & Sale Agreements'; Dest='Real Estate/01 Purchase Agreements'; Keys=@('purchase','sale agreement','psa','contract','offer','counter','ratified','addendum','amendment') },
  @{ Name='Listing Documents';          Dest='Real Estate/02 Listings';            Keys=@('listing','mls','just listed','coming soon') },
  @{ Name='Disclosures';                Dest='Real Estate/03 Disclosures';         Keys=@('disclosure','tds','spds','lead','lead-based','seller disclosure','natural hazard','nhd') },
  @{ Name='Inspections';                Dest='Real Estate/04 Inspections';         Keys=@('inspection','inspect','pest','termite','roof','sewer','hvac') },
  @{ Name='Appraisals & Valuations';    Dest='Real Estate/05 Appraisals';          Keys=@('appraisal','appraised','bpo','cma','comparative market','valuation') },
  @{ Name='Closing & Settlement';       Dest='Real Estate/06 Closing';             Keys=@('closing','settlement','hud','closing disclosure','alta','escrow','final walk') },
  @{ Name='Title & Deed';               Dest='Real Estate/07 Title & Deed';        Keys=@('title','deed','grant deed','warranty deed','preliminary title','prelim','vesting') },
  @{ Name='Loan & Financing';           Dest='Real Estate/08 Financing';           Keys=@('mortgage','loan','pre-approval','preapproval','pre-qual','prequal','lender','financing','promissory','underwriting') },
  @{ Name='Leases & Rentals';           Dest='Real Estate/09 Leases';              Keys=@('lease','rental','tenant','rent roll','occupancy') },
  @{ Name='Commissions & Financials';   Dest='Real Estate/10 Financials';          Keys=@('commission','invoice','receipt','statement','1099','referral','payout','ledger') },
  @{ Name='Insurance';                  Dest='Real Estate/11 Insurance';           Keys=@('insurance','policy','homeowners','hazard','flood') },
  @{ Name='Taxes & Assessments';        Dest='Real Estate/12 Taxes';               Keys=@('tax','assessment','w9','w-9','1098','property tax') },
  @{ Name='Marketing Material';         Dest='Real Estate/13 Marketing';           Keys=@('flyer','brochure','postcard','marketing','open house','advert','social','campaign') },
  @{ Name='Photos & Media';             Dest='Real Estate/14 Photos & Media';      Keys=@('photo','image','drone','headshot','virtual tour','floor plan','floorplan') },
  @{ Name='Correspondence';             Dest='Real Estate/15 Correspondence';      Keys=@('email','letter','correspondence','memo','note','thread') }
)

$imageExt = @('.jpg','.jpeg','.png','.heic','.heif','.tif','.tiff','.gif','.bmp','.webp')
$videoExt = @('.mp4','.mov','.m4v','.avi','.mkv')
$sensitive = @('ssn','social security','passport','driver','license','bank','routing','account number','wire','wiring','voided check','credit card','w-9','w9')
$generic   = @('untitled','document','new doc','scan','img_','image_','dsc_','photo_','screenshot','doc1','final','copy','unknown','temp','test')
$noise     = @('final','finalfinal','copy','copy2','new','updated','version','ver','draft','v1','v2','v3','latest')

function Test-Keyword([string]$key,[string]$name){
    $k = [regex]::Escape($key.Trim())
    return [regex]::IsMatch($name, "(?<![a-z0-9])$k(?![a-z0-9])")
}

function Get-Category([string]$nameLower,[string]$ext){
    $scores = @()
    foreach($r in $rules){
        $hits = @($r.Keys | Where-Object { Test-Keyword $_ $nameLower })
        if($hits.Count -gt 0){ $scores += [pscustomobject]@{ N=$hits.Count; Cat=$r.Name; Dest=$r.Dest } }
    }
    if($scores.Count -gt 0){
        $scores = $scores | Sort-Object N -Descending
        $top = $scores[0]
        $tie = ($scores.Count -gt 1) -and ($scores[1].N -eq $top.N)
        $conf = if($tie){'Low'} elseif($top.N -ge 2 -or $scores.Count -eq 1){'High'} else {'Medium'}
        return @($top.Cat,$top.Dest,$conf)
    }
    if($imageExt -contains $ext -or $videoExt -contains $ext){
        return @('Photos & Media','Real Estate/14 Photos & Media','Low')
    }
    return @('Uncategorized -- needs review','Real Estate/00 Needs Review','Low')
}

function Get-CleanDescriptor([string]$stem){
    $s = $stem.ToLower()
    $s = [regex]::Replace($s,'[_\s]+','-')
    $s = [regex]::Replace($s,'[^a-z0-9\-]','')
    $tokens = $s.Split('-') | Where-Object { $_ -and ($noise -notcontains $_) }
    $s = ($tokens -join '-')
    $s = [regex]::Replace($s,'-{2,}','-').Trim('-')
    if(-not $s){ $s = 'untitled' }
    return $s
}

function Test-NameClean([string]$name){
    $stem = [IO.Path]::GetFileNameWithoutExtension($name)
    if($name -match '\s'){ return $false }
    if($name -match '[^A-Za-z0-9_.\-]'){ return $false }
    if($stem -match '(?i)\(\d+\)|copy|final|untitled|^img[_-]?\d+|^dsc|^scan'){ return $false }
    return $true
}

$md = New-Object System.Collections.Generic.List[string]
$records = @()

foreach($root in $roots){
    $items = if($Recursive){ Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue }
             else          { Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue }
    foreach($f in $items){
        if($f.Name.StartsWith('.')){ continue }
        $name = $f.Name
        $nameLower = $name.ToLower()
        $ext = $f.Extension.ToLower()
        $cat,$dest,$conf = Get-Category $nameLower $ext
        $clean = Test-NameClean $name
        $catSlug = ([regex]::Replace($cat.ToLower().Split('--')[0],'[^a-z0-9]+','-')).Trim('-')
        $desc = Get-CleanDescriptor ([IO.Path]::GetFileNameWithoutExtension($name))
        $dateStr = $f.LastWriteTime.ToString('yyyy-MM-dd')
        $suggested = if($clean){ $name } else { "${catSlug}__${desc}__${dateStr}${ext}" }

        $reasons = @()
        if($sensitive | Where-Object { $nameLower.Contains($_) }){ $reasons += 'Possible sensitive/personal info -- verify before moving' }
        if($cat.StartsWith('Uncategorized')){ $reasons += 'Could not determine category from the name' }
        elseif($conf -eq 'Low'){ $reasons += 'Low confidence / ambiguous category' }
        if($generic | Where-Object { $nameLower.Contains($_) }){ $reasons += "Very generic name -- can't tell what it is" }

        $records += [pscustomobject]@{
            Name=$name; Type=$f.Extension.TrimStart('.').ToUpper(); Path=$f.FullName;
            Modified=$f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); Category=$cat;
            Clean=$(if($clean){'Clean'}else{'Needs correction'}); Suggested=$suggested;
            Dest=$dest; Confidence=$conf; Review=$reasons
        }
    }
}

$records = $records | Sort-Object { $_.Path.ToLower() }
function E([string]$t){ return ($t -replace '\|','\|') }
$today = Get-Date -Format 'yyyy-MM-dd'
$needsReview = @($records | Where-Object { $_.Review.Count -gt 0 })
$needsFix = @($records | Where-Object { $_.Clean -ne 'Clean' }).Count

$md.Add("# DWG File Organization -- Test Report ($today)")
$md.Add("")
$md.Add("> **This is a READ-ONLY test.** Nothing on your computer was renamed, moved, or deleted. Every 'Suggested' value below is a *proposal* for your review only.")
$md.Add("")
$md.Add("## Scope of this scan"); $md.Add("")
foreach($r in $roots){ $md.Add("- ``$r``") }
$md.Add("")
$md.Add("- **Depth:** " + $(if($Recursive){'Recursive (into subfolders)'}else{'Top level only'}))
$md.Add("- **Files analyzed:** " + $records.Count)
$md.Add("")
$md.Add("## Summary"); $md.Add("")
$md.Add("- **Names that look clean already:** " + ($records.Count - $needsFix))
$md.Add("- **Names suggested for correction:** " + $needsFix)
$md.Add("- **Flagged for human review:** " + $needsReview.Count)
$md.Add("")
$md.Add("### Files by likely category"); $md.Add("")
$md.Add("| Category | Count |"); $md.Add("| --- | ---: |")
$records | Group-Object Category | Sort-Object Count -Descending | ForEach-Object { $md.Add("| $(E $_.Name) | $($_.Count) |") }
$md.Add("")
$md.Add("## Files that need your eyes first"); $md.Add("")
if($needsReview.Count -eq 0){ $md.Add("_None flagged. Still, skim the full table below._") }
else{
    $md.Add("These were not confidently categorized, look sensitive, or have generic names. **Do not auto-rename these.**"); $md.Add("")
    $md.Add("| File | Why it needs review | Full path |"); $md.Add("| --- | --- | --- |")
    foreach($r in $needsReview){ $md.Add("| $(E $r.Name) | $(E ($r.Review -join '; ')) | ``$(E $r.Path)`` |") }
}
$md.Add("")
$md.Add("## Full inventory"); $md.Add("")
$md.Add("| # | Current name | Type | Modified | Likely category | Name status | Suggested clean name | Suggested destination | Confidence | Review? |")
$md.Add("| ---: | --- | --- | --- | --- | --- | --- | --- | --- | :---: |")
$i = 0
foreach($r in $records){
    $i++; $flag = if($r.Review.Count -gt 0){'yes'}else{''}
    $md.Add("| $i | $(E $r.Name) | $(E $r.Type) | $($r.Modified) | $(E $r.Category) | $($r.Clean) | $(E $r.Suggested) | $(E $r.Dest) | $($r.Confidence) | $flag |")
}
$md.Add("")
$md.Add("---"); $md.Add(""); $md.Add("_Generated by scan_windows.ps1 in read-only mode. No files were changed._")

$outPath = Join-Path $here "DWG_File_Organization_Test_Report_$today.md"
$md -join "`r`n" | Out-File -LiteralPath $outPath -Encoding utf8

Write-Host ""
Write-Host "============================================================"
Write-Host "  DONE -- analyzed $($records.Count) files (READ-ONLY)."
Write-Host "  Report saved to:"
Write-Host "  $outPath"
Write-Host "============================================================"
