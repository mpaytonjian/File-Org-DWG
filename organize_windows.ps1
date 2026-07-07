# ============================================================
#  DWG File Organization -- Windows SORTER (NO PYTHON NEEDED)
#  Builds the approved Deal-first structure into a NEW COPY folder
#  on your Desktop. Your ORIGINAL files are never touched.
#  Writes a CSV log of every copy so it is fully reversible.
# ============================================================
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- Real Desktop + Documents (OneDrive-aware) ----
$roots = @()
foreach($f in @('Desktop','MyDocuments')){
    $p = [Environment]::GetFolderPath($f)
    if($p -and (Test-Path $p)){ $roots += $p }
}
$roots = $roots | Select-Object -Unique

$destBase = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DWG Organized (Copy - Safe)'

# ---- Commercial RE / PE taxonomy ----
$rules = @(
 @{N='Offering & Marketing Materials'; K=@('om','bov','teaser','flyer','intro summary','portfolio','one page','one pager','cma','tour package','broker pitch','brokerpitch','for brokers','firm intro','service offering','buyerdeck','buyer deck','deck','holiday insert','cover')},
 @{N='LOIs & Term Sheets'; K=@('loi','term sheet','letter of intent','termsheet')},
 @{N='Offers, PSAs & Contracts'; K=@('offer','purchase','psa','sale leaseback','rfp','executed agreement','option agreement','buy out','buyout','fee agreement')},
 @{N='Underwriting & Financial Models'; K=@('uw','underwriting','analysis','waterfall','gp economics','gp analysis','project cost','income statement','draws','proforma','pro forma','model','cost analysis','economics','interim','worst case','equity and project')},
 @{N='Debt & Financing'; K=@('debt request','debtrequest','loan','refinance','construction','guaranty','financing','quote','submission')},
 @{N='Investor, Fund & Capital'; K=@('capital call','capital_call','investor','investors','fund','fund iii','cam jv','subscription','ppm','distribution','padilla','sbis','shares','fund launch','debt facility')},
 @{N='Due Diligence'; K=@('dd','due diligence','due_diligence','checklist','environmental','ust','hex chrome','soft results','stabilization','stabilized','dd link','dd request','dd checklist','report')},
 @{N='Leasing'; K=@('lease','nnn','rent roll','rentroll','tenant','estoppel','lease or sale')},
 @{N='Closing & Legal'; K=@('closing','settlement statement','settlement','release letter','escrow','title','deed')},
 @{N='Fees & Commissions'; K=@('commission','billing','invoice','referral','prepaid','hard bid')},
 @{N='Wire & Banking (SENSITIVE)'; K=@('wire','wiring','wire instructions','bank copy','routing','account number')},
 @{N='Contacts & CRM'; K=@('contacts','client list','lenders','ria list','vcf')},
 @{N='Firm Admin / Internal'; K=@('overview','notes','timeline','file org','drafts','warmest regards','ordering guide','how to submit')}
)
$personal  = @('trump','biden','newsom','election','vote','litmus','sotu','soto','reunion','comedy','memorial','bday','birthday','hotel','reservation','costa rica','jaco','condominium','camming','legacy','midterm')
$systemExt = @('.lnk','.exe','.msi','.log')
$imageExt  = @('.jpg','.jpeg','.png','.heic','.jfif','.gif','.bmp','.webp','.tif','.tiff')
$videoExt  = @('.mp4','.mov','.m4v','.avi')

# ---- Deals ----
# Canonical names mirror the Egnyte "Active AUM Portfolio" folders so a
# desktop file about a deal lands in a folder named like its Egnyte home.
# More-specific entries are listed first (order matters for matching).
$deals = @(
 # ----- Egnyte Active AUM portfolio (canonical) -----
 @{N='1. AirBagIt - Mesa AZ'; K=@('airbagit','airbag')},
 @{N='2. Austin Iron - TX'; K=@('austin iron')},
 @{N='3. Buckeye - OH'; K=@('buckeye')},
 @{N='4. JAL Mossberg'; K=@('mossberg','jal marketing','jal_','jal ')},
 @{N='5. Lancaster - SC'; K=@('lancaster')},
 @{N='6. M. Roberts Media - TX'; K=@('roberts media','m. roberts','m roberts')},
 @{N='7. Rembrandt - Phoenix'; K=@('rembrandt')},
 @{N='8. G2 Ozark'; K=@('g2 ozark','ozark')},
 @{N='9. T&T Machine - OH'; K=@('t&t machine','t and t machine')},
 @{N='10. Moab'; K=@('moab')},
 @{N='11. Greenbriar Apartments (Dorado)'; K=@('greenbriar apartment')},
 @{N='12. Cloverdale (Dorado)'; K=@('cloverdale')},
 @{N='13. Edgebuilders - WI'; K=@('edgebuilder')},
 @{N='14. Kecy Metals - MI'; K=@('kecy')},
 @{N='15. Butler Weldment SLB'; K=@('butler weldment','butler weldments','project torch')},
 @{N='16. Kalkaska Screw'; K=@('kalkaska')},
 @{N='17. Breese JAL SAB - IL'; K=@('breese')},
 @{N='18. Stryten Energy'; K=@('stryten')},
 @{N='19. Southern Perfection (SPF)'; K=@('southern perfection','spf')},
 @{N='20. 3754 Wasatch (Personal)'; K=@('wasatch')},
 @{N='21. 119 Greenbriar (Personal)'; K=@('119 greenbriar','greenbriar st')},
 # ----- Other deals seen on the desktop (pipeline / legacy / brokerage) -----
 @{N='Hibbert - Mesa AZ'; K=@('hibbert')},
 @{N='Powertex'; K=@('powertex')},
 @{N='ANR'; K=@('anr bov','anr is','anr.')},
 @{N='Goodyear'; K=@('goodyear')},
 @{N='Ventura Blvd'; K=@('ventura')},
 @{N='Bronx'; K=@('bronx')},
 @{N='Broadview Apartments'; K=@('broadview')},
 @{N='Ridgeline'; K=@('ridgeline')},
 @{N='Sterling'; K=@('sterling')},
 @{N='Assa Abloy'; K=@('assa abloy')},
 @{N='Gutterman'; K=@('gutterman')},
 @{N='Sisler Properties'; K=@('sisler')},
 @{N='Stuckys'; K=@('stuckys')},
 @{N='Kinton - 1645 Jackson'; K=@('kinton','1645jackson')},
 @{N='FEV Development Center'; K=@('fev development','auburn hills')},
 @{N='301 E Sample'; K=@('301_e_sample','301 e sample')},
 @{N='Silver Strand'; K=@('silver strand','silver_strand')},
 @{N='323 Beach Ave'; K=@('323beach','323 beach')},
 @{N='13129 Sherry Lane'; K=@('sherry_lane','sherry lane')},
 @{N='1275 Sunset'; K=@('1275sunset','1275 sunset')},
 @{N='4115 Zero Street (Fort Smith)'; K=@('zero street','4115 zero')}
)

$subfolder = @{
 'Offering & Marketing Materials'='01 Offering & Marketing';
 'LOIs & Term Sheets'='02 LOIs & Term Sheets';
 'Offers, PSAs & Contracts'='03 Offers & Contracts';
 'Underwriting & Financial Models'='04 Underwriting';
 'Debt & Financing'='05 Debt & Financing';
 'Investor, Fund & Capital'='06 Investor & Capital';
 'Due Diligence'='07 Due Diligence';
 'Leasing'='08 Leasing';
 'Closing & Legal'='09 Closing & Legal';
 'Fees & Commissions'='10 Fees & Commissions';
 'Wire & Banking (SENSITIVE)'='11 Wire & Banking (SENSITIVE)';
 'Firm Admin / Internal'='12 Admin';
 'Photos & Media'='13 Media';
 'Contacts & CRM'='14 Contacts';
 'Uncategorized -- needs review'='00 Needs Review'
}
$firmBucket = @{
 'Investor, Fund & Capital'='Firm\Fund & Investor Relations';
 'Offering & Marketing Materials'='Firm\Marketing';
 'Fees & Commissions'='Firm\Finance & Commissions';
 'Wire & Banking (SENSITIVE)'='Firm\Finance & Commissions\Wire (SENSITIVE)';
 'Contacts & CRM'='Firm\Contacts';
 'Firm Admin / Internal'='Firm\Admin';
 'Debt & Financing'='Firm\Debt & Financing';
 'Underwriting & Financial Models'='Firm\Underwriting';
 'Due Diligence'='Firm\Due Diligence';
 'Offers, PSAs & Contracts'='Firm\Contracts';
 'Leasing'='Firm\Leasing';
 'Closing & Legal'='Firm\Closing & Legal';
 'LOIs & Term Sheets'='Firm\LOIs & Term Sheets';
 'Photos & Media'='Firm\Media';
 'Uncategorized -- needs review'='Firm\00 Needs Review'
}

function Test-Keyword([string]$key,[string]$name){
    $k = [regex]::Escape($key.Trim())
    return [regex]::IsMatch($name, "(?<![a-z0-9])$k(?![a-z0-9])")
}

function Get-Cat([string]$name,[string]$ext){
    $nl = $name.ToLower()
    if($systemExt -contains $ext){ return 'System & Installers (ignore)' }
    if($ext -eq '.url'){ return 'Bookmarks / Web Links (ignore)' }
    foreach($p in $personal){ if(Test-Keyword $p $nl){ return 'Personal / Non-Business' } }
    $scores = @()
    foreach($r in $rules){
        $hits = @($r.K | Where-Object { Test-Keyword $_ $nl })
        if($hits.Count -gt 0){ $scores += [pscustomobject]@{ N=$hits.Count; Cat=$r.N } }
    }
    if($scores.Count -gt 0){ return ($scores | Sort-Object N -Descending)[0].Cat }
    if(($imageExt -contains $ext) -or ($videoExt -contains $ext)){ return 'Photos & Media' }
    return 'Uncategorized -- needs review'
}

function Get-Dest([string]$name,[string]$ext){
    $cat = Get-Cat $name $ext
    $nl  = $name.ToLower()
    if($cat -like 'System*' -or $cat -like 'Bookmarks*'){ return @('System - Ignore',$cat) }
    if($cat -like 'Personal*'){ return @('Personal',$cat) }
    $deal = $null
    foreach($d in $deals){ foreach($k in $d.K){ if($nl.Contains($k)){ $deal=$d.N; break } }; if($deal){ break } }
    if($deal){
        $sf = $subfolder[$cat]; if(-not $sf){ $sf='00 Needs Review' }
        return @("Deals\$deal\$sf",$cat)
    }
    $fb = $firmBucket[$cat]; if(-not $fb){ $fb='Firm\00 Needs Review' }
    return @($fb,$cat)
}

# ---- Do the copy ----
Write-Host ""
Write-Host "Building your organized COPY (originals stay put)..."
Write-Host "Destination: $destBase"
Write-Host ""

$log = @()
foreach($root in $roots){
    Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | ForEach-Object {
        $f = $_
        if($f.Name.StartsWith('.')){ return }
        $res = Get-Dest $f.Name $f.Extension.ToLower()
        $destDir = Join-Path $destBase $res[0]
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        $target = Join-Path $destDir $f.Name
        $i = 2
        while(Test-Path -LiteralPath $target){
            $target = Join-Path $destDir ([IO.Path]::GetFileNameWithoutExtension($f.Name) + "-$i" + $f.Extension)
            $i++
        }
        Copy-Item -LiteralPath $f.FullName -Destination $target
        $log += [pscustomobject]@{ Original=$f.FullName; Copy=$target; Category=$res[1]; Folder=$res[0] }
    }
}

$logPath = Join-Path $destBase ("DWG_organize_log_" + (Get-Date -Format 'yyyy-MM-dd') + ".csv")
$log | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8

Write-Host "============================================================"
Write-Host "  DONE -- copied $($log.Count) files into your organized folder."
Write-Host ""
Write-Host "  Open it here:"
Write-Host "  $destBase"
Write-Host ""
Write-Host "  Reversible log of every copy:"
Write-Host "  $logPath"
Write-Host ""
Write-Host "  Your ORIGINAL files were NOT changed."
Write-Host "============================================================"

Write-Host ""
Write-Host "Top folders created:"
$log | Group-Object { ($_.Folder -split '\\')[0] } | Sort-Object Count -Descending |
    ForEach-Object { "{0,4}  {1}" -f $_.Count, $_.Name } | Write-Host
