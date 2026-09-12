#!/usr/bin/env bash
# Session Breakout Gold - Mac / Linux o'rnatuvchi
# Mac da MT5 Wine ostida ishlaydi, papka yo'li boshqacha.
set -u

SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
say()  { printf '  [OK]   %s\n' "$1"; }
err()  { printf '  [XATO] %s\n' "$1"; }
warn() { printf '  [!]    %s\n' "$1"; }
head() { printf '\n%s\n  %s\n%s\n' "$(printf '=%.0s' {1..62})" "$1" "$(printf '=%.0s' {1..62})"; }

head "SESSION BREAKOUT GOLD - O'RNATISH"

head "1/3  Loyiha fayllari"
[ -d "$SRC/MQL5/Experts" ] || { err "MQL5/Experts topilmadi: $SRC"; exit 1; }
say "Manba: $SRC"
say "$(ls "$SRC/MQL5/Experts"/*.mq5 2>/dev/null | wc -l) ta .mq5 fayl"

head "2/3  MetaTrader 5 papkasi"
TARGETS=()
for base in \
  "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/users/$USER/AppData/Roaming/MetaQuotes/Terminal" \
  "$HOME/.wine/drive_c/users/$USER/AppData/Roaming/MetaQuotes/Terminal" \
  "$HOME/.mt5/drive_c/users/$USER/AppData/Roaming/MetaQuotes/Terminal"
do
  [ -d "$base" ] || continue
  while IFS= read -r d; do
    [ "$(basename "$d")" = "Common" ] && continue
    [ -d "$d/MQL5" ] && TARGETS+=("$d/MQL5")
  done < <(find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  err "MT5 papkasi topilmadi."
  echo "  MT5 -> File -> Open Data Folder yo'lini toping va shunday ishga tushiring:"
  echo "    MT5DIR=\"/yo'l/Terminal/XXXX/MQL5\" ./install_mac_linux.sh"
  [ -n "${MT5DIR:-}" ] && TARGETS+=("$MT5DIR") || exit 1
fi
for t in "${TARGETS[@]}"; do say "$t"; done

head "3/3  Fayllarni ko'chirish"
for t in "${TARGETS[@]}"; do
  mkdir -p "$t/Experts/SessionBreakout" "$t/Scripts/SessionBreakout"
  for f in "$SRC/MQL5/Experts"/*.mq5; do
    n=$(basename "$f")
    if [ "$n" = "ExportBars.mq5" ]; then
      cp -f "$f" "$t/Scripts/SessionBreakout/" && say "Scripts/SessionBreakout/$n"
    else
      cp -f "$f" "$t/Experts/SessionBreakout/" && say "Experts/SessionBreakout/$n"
    fi
  done
  cp -f "$SRC/MQL5/Experts"/*.md "$t/Experts/SessionBreakout/" 2>/dev/null || true
done

head "Python muhiti"
if command -v python3 >/dev/null; then
  cd "$SRC/python"
  python3 -m venv .venv 2>/dev/null
  .venv/bin/python -m pip install --quiet --upgrade pip
  .venv/bin/python -m pip install --quiet -r requirements.txt
  say "venv + kutubxonalar tayyor"
  .venv/bin/python run.py --synth 100
else
  warn "python3 topilmadi - o'tkazib yuborildi"
fi

head "TAYYOR"
cat << 'TXT'
  KEYINGI QADAMLAR:
   1. MT5 ni QAYTA ISHGA TUSHIRING
   2. MetaEditor (F4) -> Experts\SessionBreakout -> har birini F7 bilan kompilyatsiya
   3. Scripts\SessionBreakout\ExportBars.mq5 ni ham F7
   4. Tools -> Options -> Charts -> Max bars in chart = Unlimited
   5. XAUUSD M15 chart -> HOME -> tarix yuklansin
   6. Navigator -> Scripts -> ExportBars ni chartga tashlang
   7. MQL5\Files\XAUUSD_PERIOD_M15.csv ni va Journal dagi
      "BROKER MA'LUMOTLARI" blokini menga yuboring
TXT
