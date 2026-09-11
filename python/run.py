"""Backtest CLI — bitta konfiguratsiyani ishga tushiradi."""
from __future__ import annotations
import argparse, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pandas as pd
from sbgold import Params, Session, Backtest, metrics, summary_line
from data import load_mt5_csv, synth, describe


def make_params(a) -> Params:
    p = Params()
    p.sessions = [
        Session("S1", a.s1[0], a.s1[1], a.s1[2], a.s1[3], not a.no_s1),
        Session("S2", a.s2[0], a.s2[1], a.s2[2], a.s2[3], a.s2_on),
        Session("S3", a.s3[0], a.s3[1], a.s3[2], a.s3[3], a.s3_on),
    ]
    p.entry_mode = a.entry
    p.pending_offset = a.pending_offset
    p.sl_mode = a.sl_mode
    p.sl_range_frac = a.sl_frac
    p.sl_atr_mult = a.sl_atr
    p.sl_buffer = a.buffer
    p.tp_mode = a.tp_mode
    p.rr = a.rr
    p.tp_range_mult = a.tp_mult
    p.lot = a.lot
    p.spread = a.spread
    p.commission_per_lot = a.commission
    p.max_trades_per_day = a.max_day
    p.max_trades_per_session = a.max_sess
    p.use_be = a.be
    p.be_trigger_r = a.be_trigger
    p.use_trail = a.trail
    p.use_time_exit = a.time_exit
    p.force_close_hour = a.close_hour
    return p


def main():
    ap = argparse.ArgumentParser(description="Session Breakout Gold backtest")
    ap.add_argument("--csv", help="MT5 dan eksport qilingan CSV")
    ap.add_argument("--synth", type=int, default=0, help="sintetik kunlar soni")
    ap.add_argument("--tz", type=int, default=0, help="server vaqti siljishi (soat)")
    ap.add_argument("--balance", type=float, default=5000.0)

    ap.add_argument("--entry", default="market", choices=["market", "pending"])
    ap.add_argument("--pending-offset", type=float, default=0.10)
    ap.add_argument("--sl-mode", default="range_from_entry",
                    choices=["range_from_entry", "range_fraction",
                             "range_level", "atr"])
    ap.add_argument("--sl-frac", type=float, default=0.50)
    ap.add_argument("--sl-atr", type=float, default=1.00)
    ap.add_argument("--buffer", type=float, default=0.50)
    ap.add_argument("--tp-mode", default="rr", choices=["rr", "range_mult", "atr"])
    ap.add_argument("--rr", type=float, default=2.0)
    ap.add_argument("--tp-mult", type=float, default=1.00)

    ap.add_argument("--lot", type=float, default=0.10)
    ap.add_argument("--spread", type=float, default=0.30)
    ap.add_argument("--commission", type=float, default=0.0)

    ap.add_argument("--s1", type=int, nargs=4, default=[0, 7, 8, 11])
    ap.add_argument("--s2", type=int, nargs=4, default=[8, 13, 14, 17])
    ap.add_argument("--s3", type=int, nargs=4, default=[14, 18, 19, 22])
    ap.add_argument("--no-s1", action="store_true")
    ap.add_argument("--s2-on", action="store_true")
    ap.add_argument("--s3-on", action="store_true")

    ap.add_argument("--max-day", type=int, default=0)
    ap.add_argument("--max-sess", type=int, default=0)
    ap.add_argument("--be", action="store_true")
    ap.add_argument("--be-trigger", type=float, default=1.5)
    ap.add_argument("--trail", action="store_true")
    ap.add_argument("--time-exit", action="store_true")
    ap.add_argument("--close-hour", type=int, default=23)
    ap.add_argument("--save", help="savdolarni CSV ga saqlash")
    a = ap.parse_args()

    if a.csv:
        df = load_mt5_csv(a.csv, a.tz)
        src = os.path.basename(a.csv)
    elif a.synth:
        df = synth(days=a.synth)
        src = f"SINTETIK ({a.synth} kun) — faqat engine testi!"
    else:
        ap.error("--csv yoki --synth kerak")

    print(f"Manba : {src}")
    print(f"Data  : {describe(df)}\n")

    p = make_params(a)
    tr = Backtest(df, p).run()
    m = metrics(tr, a.balance)

    print(summary_line("NATIJA", m))
    if len(tr):
        print(f"\n  o'rt. yutuq {m['avg_win']:>8.2f}   o'rt. zarar {m['avg_loss']:>8.2f}"
              f"   ketma-ket max zarar {m['max_losses']}")
        print("\n  Chiqish sabablari:")
        for k, v in tr["reason"].value_counts().items():
            sub = tr[tr.reason == k]
            print(f"    {k:<6} {v:>4} ta   o'rt. R {sub['r'].mean():+.2f}   "
                  f"jami {sub['pnl'].sum():>9.2f}")
        if tr["session"].nunique() > 1:
            print("\n  Sessiya bo'yicha:")
            for s, g in tr.groupby("session"):
                print("    " + summary_line(s, metrics(g, a.balance)))
    if a.save and len(tr):
        tr.to_csv(a.save, index=False)
        print(f"\n  Savdolar saqlandi: {a.save}")


if __name__ == "__main__":
    main()
