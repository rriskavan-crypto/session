<#
    Session Breakout Gold - Windows o'rnatuvchi

    Nima qiladi:
      1. MetaTrader 5 ma'lumot papkasini (papkalarini) avtomatik topadi
      2. EA fayllarini  MQL5\Experts\SessionBreakout\  ga ko'chiradi
      3. ExportBars.mq5 ni MQL5\Scripts\SessionBreakout\ ga ko'chiradi
      4. Python backtest muhitini tayyorlaydi (ixtiyoriy)

    ISHLATISH (PowerShell da, oddiy foydalanuvchi huquqi yetadi):

      powershell -ExecutionPolicy Bypass -File install_windows.ps1

    Parametrlar:
      -Source <yo'l>   Loyiha papkasi (bo'sh bo'lsa GitHub dan klon qiladi)
      -MT5Path <yo'l>  MT5 ma'lumot papkasi (avtomatik topilmasa)
      -SkipPython      Python qismini o'tkazib yuborish
#>

param(
    [string]$Source   = "",
    [string]$MT5Path  = "",
    [switch]$SkipPython
)

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/rriskavan-crypto/session.git"

function Say([string]$m, [string]$tag = "") {
    if ($tag -eq "ok")   { Write-Host "  [OK]   $m" -ForegroundColor Green;  return }
    if ($tag -eq "err")  { Write-Host "  [XATO] $m" -ForegroundColor Red;    return }
    if ($tag -eq "warn") { Write-Host "  [!]    $m" -ForegroundColor Yellow; return }
    Write-Host "  $m"
}
function Head([string]$m) {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor Cyan
    Write-Host "  $m" -ForegroundColor Cyan
    Write-Host ("=" * 62) -ForegroundColor Cyan
}

Head "SESSION BREAKOUT GOLD - O'RNATISH"

# ---------------------------------------------------------------- 1
Head "1/4  Loyiha fayllarini topish"

if ($Source -eq "") {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $maybe = Split-Path -Parent $here
    if (Test-Path (Join-Path $maybe "MQL5\Experts")) {
        $Source = $maybe
        Say "Loyiha shu yerdan topildi: $Source" "ok"
    }
}

if ($Source -eq "") {
    $Source = Join-Path $env:USERPROFILE "SessionBreakoutGold"
    if (Test-Path (Join-Path $Source "MQL5\Experts")) {
        Say "Avval yuklangan nusxa ishlatiladi: $Source" "ok"
    }
    else {
        Say "GitHub dan yuklanmoqda..."
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) {
            Say "git topilmadi." "err"
            Write-Host ""
            Write-Host "  Ikki yo'ldan birini tanlang:" -ForegroundColor Yellow
            Write-Host "    a) git ni o'rnating: https://git-scm.com/download/win"
            Write-Host "    b) GitHub dan ZIP yuklab oling, biror papkaga chiqaring va"
            Write-Host "       shu skriptni -Source parametri bilan qayta ishga tushiring:"
            Write-Host "       powershell -ExecutionPolicy Bypass -File install_windows.ps1 -Source C:\yo\lingiz"
            exit 1
        }
        try {
            & git clone --depth 1 $RepoUrl $Source 2>&1 | Out-Null
            Say "Yuklandi: $Source" "ok"
        }
        catch {
            Say "Klon qilinmadi (repo yopiq bo'lsa GitHub login so'raydi)." "err"
            Write-Host "  ZIP ni qo'lda yuklab, -Source bilan qayta urinib ko'ring."
            exit 1
        }
    }
}

$SrcExperts = Join-Path $Source "MQL5\Experts"
if (-not (Test-Path $SrcExperts)) {
    Say "MQL5\Experts topilmadi: $SrcExperts" "err"
    exit 1
}
$mq5 = Get-ChildItem $SrcExperts -Filter *.mq5
Say ("Topilgan .mq5 fayllar: " + $mq5.Count) "ok"

# ---------------------------------------------------------------- 2
Head "2/4  MetaTrader 5 papkasini topish"

$targets = @()
if ($MT5Path -ne "") {
    $p = $MT5Path
    if (Test-Path (Join-Path $p "MQL5")) { $p = Join-Path $p "MQL5" }
    if (Test-Path $p) { $targets += $p } else { Say "Ko'rsatilgan yo'l yo'q: $MT5Path" "err"; exit 1 }
}
else {
    $root = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path $root) {
        Get-ChildItem $root -Directory | ForEach-Object {
            if ($_.Name -ne "Common") {
                $m = Join-Path $_.FullName "MQL5"
                if (Test-Path $m) { $targets += $m }
            }
        }
    }
}

if ($targets.Count -eq 0) {
    Say "MT5 papkasi topilmadi." "err"
    Write-Host ""
    Write-Host "  MT5 ni oching -> File -> Open Data Folder" -ForegroundColor Yellow
    Write-Host "  Ochilgan papka yo'lini nusxalang va shunday ishga tushiring:"
    Write-Host "    powershell -ExecutionPolicy Bypass -File install_windows.ps1 -MT5Path `"C:\...\Terminal\XXXX`""
    exit 1
}
foreach ($t in $targets) { Say $t "ok" }

# ---------------------------------------------------------------- 3
Head "3/4  Fayllarni ko'chirish"

$expertFiles = $mq5 | Where-Object { $_.Name -ne "ExportBars.mq5" }
$scriptFiles = $mq5 | Where-Object { $_.Name -eq "ExportBars.mq5" }

foreach ($t in $targets) {
    Write-Host ""
    Say "-> $t"
    $dstE = Join-Path $t "Experts\SessionBreakout"
    $dstS = Join-Path $t "Scripts\SessionBreakout"
    New-Item -ItemType Directory -Force -Path $dstE | Out-Null
    New-Item -ItemType Directory -Force -Path $dstS | Out-Null

    foreach ($f in $expertFiles) {
        Copy-Item $f.FullName -Destination $dstE -Force
        Say ("Experts\SessionBreakout\" + $f.Name) "ok"
    }
    foreach ($f in $scriptFiles) {
        Copy-Item $f.FullName -Destination $dstS -Force
        Say ("Scripts\SessionBreakout\" + $f.Name + "   (skript - Experts EMAS)") "ok"
    }
    Get-ChildItem $SrcExperts -Filter *.md | ForEach-Object {
        Copy-Item $_.FullName -Destination $dstE -Force
    }
}

# ---------------------------------------------------------------- 4
Head "4/4  Python backtest muhiti"

if ($SkipPython) {
    Say "O'tkazib yuborildi (-SkipPython)" "warn"
}
else {
    $pyDir = Join-Path $Source "python"
    if (-not (Test-Path $pyDir)) {
        Say "python papkasi yo'q - o'tkazib yuborildi" "warn"
    }
    else {
        $py = $null
        foreach ($c in @("py", "python", "python3")) {
            $cmd = Get-Command $c -ErrorAction SilentlyContinue
            if ($cmd) { $py = $c; break }
        }
        if (-not $py) {
            Say "Python topilmadi." "warn"
            Write-Host "  O'rnating: https://www.python.org/downloads/  (Add to PATH ni belgilang)"
        }
        else {
            $v = & $py -V 2>&1
            Say "$py topildi ($v)" "ok"
            $venv = Join-Path $pyDir ".venv"
            & $py -m venv $venv 2>&1 | Out-Null
            $vpy = Join-Path $venv "Scripts\python.exe"
            if (Test-Path $vpy) {
                & $vpy -m pip install --quiet --upgrade pip 2>&1 | Out-Null
                & $vpy -m pip install --quiet -r (Join-Path $pyDir "requirements.txt") 2>&1 | Out-Null
                Say "venv + kutubxonalar tayyor" "ok"
                Say "Tekshiruv ishga tushmoqda..."
                & $vpy (Join-Path $pyDir "run.py") --synth 100
            }
            else { Say "venv yaratilmadi" "err" }
        }
    }
}

# ---------------------------------------------------------------- END
Head "TAYYOR"
Write-Host ""
Write-Host "  KEYINGI QADAMLAR:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. MT5 ni QAYTA ISHGA TUSHIRING (yangi fayllar ko'rinishi uchun)"
Write-Host "  2. MetaEditor (F4) -> Navigator -> Experts\SessionBreakout"
Write-Host "     Har bir .mq5 ni oching va F7 bosing (kompilyatsiya)"
Write-Host "  3. Scripts\SessionBreakout\ExportBars.mq5 ni ham F7 bilan kompilyatsiya qiling"
Write-Host "  4. Tools -> Options -> Charts -> Max bars in chart = Unlimited"
Write-Host "  5. XAUUSD M15 chartini oching, HOME bosing, tarix yuklansin"
Write-Host "  6. Navigator -> Scripts -> ExportBars ni chartga tashlang"
Write-Host "  7. Hosil bo'lgan CSV ni menga yuboring:"
Write-Host "     File -> Open Data Folder -> MQL5\Files\XAUUSD_PERIOD_M15.csv" -ForegroundColor Cyan
Write-Host ""
Write-Host "     Va Journal dagi 'BROKER MA'LUMOTLARI' blokini ham." -ForegroundColor Cyan
Write-Host ""
