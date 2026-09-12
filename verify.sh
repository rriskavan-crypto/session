#!/usr/bin/env bash
# Hamma narsa joyidami — to'liq tekshiruv
set -u
cd "$(dirname "$0")"
PY=python/.venv/bin/python
ok=0; bad=0
line() { printf '%s\n' "────────────────────────────────────────────────────────────"; }

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SESSION BREAKOUT GOLD — O'RNATISH TEKSHIRUVI            ║"
echo "╚══════════════════════════════════════════════════════════╝"

echo; echo "[1] Python muhiti"; line
if [ -x "$PY" ]; then
  echo "  venv ............ OK  ($($PY -V 2>&1))"
  for m in numpy pandas matplotlib; do
    v=$($PY -c "import $m;print($m.__version__)" 2>/dev/null) \
      && { echo "  $m$(printf '%*s' $((15-${#m})) '') OK  ($v)"; ok=$((ok+1)); } \
      || { echo "  $m ............ XATO"; bad=$((bad+1)); }
  done
else
  echo "  venv ............ YO'Q"; bad=$((bad+1))
fi

echo; echo "[2] Python modullari"; line
for f in sbgold data run sweep; do
  $PY -c "import sys;sys.path.insert(0,'python');import $f" 2>/dev/null \
    && { echo "  $f.py$(printf '%*s' $((12-${#f})) '') import OK"; ok=$((ok+1)); } \
    || { echo "  $f.py — IMPORT XATOSI"; bad=$((bad+1)); }
done

echo; echo "[3] MQL5 fayllari (qavs balansi)"; line
$PY - << 'PYEOF'
import glob, os
def scan(p):
    s=open(p,encoding='utf-8',errors='replace').read()
    i=0;n=len(s);dp=db=0;S=C1=CM=False
    while i<n:
        c=s[i]; x=s[i+1] if i+1<n else ''
        if c=='\n': C1=False; i+=1; continue
        if C1: i+=1; continue
        if CM:
            if c=='*' and x=='/': CM=False; i+=2; continue
            i+=1; continue
        if S:
            if c=='\\': i+=2; continue
            if c=='"': S=False
            i+=1; continue
        if c=='/' and x=='/': C1=True; i+=2; continue
        if c=='/' and x=='*': CM=True; i+=2; continue
        if c=='"': S=True; i+=1; continue
        dp += (c=='(') - (c==')')
        db += (c=='{') - (c=='}')
        i+=1
    return dp,db
for f in sorted(glob.glob("MQL5/Experts/*.mq5")):
    dp,db=scan(f); n=sum(1 for _ in open(f,errors='replace'))
    st="OK " if dp==0 and db==0 else "XATO"
    print(f"  {os.path.basename(f):<34} {n:>5} qator  {st}")
PYEOF

echo; echo "[4] Engine ishlash testi (sintetik)"; line
out=$($PY python/run.py --synth 120 2>&1)
echo "$out" | grep -E "NATIJA|SL |TP " | sed 's/^/  /'
echo "$out" | grep -q "NATIJA" && ok=$((ok+1)) || bad=$((bad+1))

echo; echo "[5] Engine to'g'riligi (SL=-1.00R, TP=+2.00R bo'lishi shart)"; line
$PY - << 'PYEOF'
import sys; sys.path.insert(0,'python')
from sbgold import Params, Backtest
from data import synth
tr = Backtest(synth(days=150), Params()).run()
okk=True
for r,exp in (("SL",-1.00),("TP",2.00)):
    g=tr[tr.reason==r]
    if len(g)==0: print(f"  {r}: savdo yo'q"); continue
    m=g["r"].mean(); good=abs(m-exp)<0.02
    okk &= good
    print(f"  {r} chiqishlari: {len(g):>4} ta, o'rtacha R = {m:+.3f}  "
          f"(kutilgan {exp:+.2f})  {'OK' if good else 'XATO'}")
print("  ─> Engine matematikasi", "TO'G'RI" if okk else "XATO")
PYEOF

echo; line
echo "  Muvaffaqiyatli: $ok    Xato: $bad"
[ "$bad" -eq 0 ] && echo "  ✅ HAMMA NARSA JOYIDA" || echo "  ❌ XATOLAR BOR"
line
