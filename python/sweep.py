"""Parametrlarni ommaviy sinash — o'nlab konfiguratsiyani bir zumda solishtiradi."""
from __future__ import annotations
import sys, os, itertools, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pandas as pd
from dataclasses import replace
from sbgold import Params, Session, Backtest, metrics
from data import load_mt5_csv, synth, describe


def run_one(df, p: Params, balance: float) -> dict:
    return metrics(Backtest(df, p).run(), balance)


def grid(df, base: Params, variants: dict, balance=5000.0) -> pd.DataFrame:
    """variants: {'nom': {maydon: qiymat, ...}, ...}"""
    rows = []
    for name, over in variants.items():
        p = replace(base, **over)
        m = run_one(df, p, balance)
        m["config"] = name
        rows.append(m)
    cols = ["config", "trades", "win_pct", "pf", "net", "net_pct",
            "max_dd_pct", "expectancy_r", "max_losses"]
    return pd.DataFrame(rows)[cols].sort_values("pf", ascending=False)


def show(t: pd.DataFrame, title: str = ""):
    if title:
        print(f"\n{'═' * 92}\n  {title}\n{'═' * 92}")
    print(f"{'konfiguratsiya':<30}{'savdo':>7}{'win%':>7}{'PF':>7}"
          f"{'net':>11}{'net%':>8}{'DD%':>7}{'E[R]':>8}{'maxL':>6}")
    print("─" * 92)
    for _, r in t.iterrows():
        print(f"{r['config']:<30}{r['trades']:>7}{r['win_pct']:>7.1f}"
              f"{r['pf']:>7.2f}{r['net']:>11.2f}{r['net_pct']:>+8.1f}"
              f"{r['max_dd_pct']:>7.1f}{r['expectancy_r']:>+8.3f}{r['max_losses']:>6}")


def standard_suite(df, balance=5000.0, spread=0.30, commission=0.0):
    """Biz muhokama qilgan barcha g'oyalarni ketma-ket sinaydi."""
    base = Params(spread=spread, commission_per_lot=commission)

    S1 = Session("S1", 0, 7, 8, 11, True)
    S2 = Session("S2", 8, 13, 14, 17, True)
    S3 = Session("S3", 14, 18, 19, 22, True)
    off = lambda s: replace(s, enabled=False)

    # ── A) baza va sessiyalar ──────────────────────────────────────
    v = {
        "BAZA (asl, S1)":            {},
        "S2 alohida":                {"sessions": [off(S1), S2, off(S3)]},
        "S3 alohida":                {"sessions": [off(S1), off(S2), S3]},
        "S1+S2":                     {"sessions": [S1, S2, off(S3)]},
        "S1+S2+S3":                  {"sessions": [S1, S2, S3]},
    }
    show(grid(df, base, v, balance), "A) BAZA va KO'P SESSIYA")

    # ── B) SL geometriyasi ─────────────────────────────────────────
    v = {"BAZA (SL = 1.0 x range)": {}}
    for f in (0.30, 0.40, 0.50, 0.60, 0.75, 1.00, 1.25):
        v[f"SL = {f:.2f} x range"] = {"sl_mode": "range_fraction",
                                      "sl_range_frac": f}
    v["SL = range LEVEL (v3.x)"] = {"sl_mode": "range_level"}
    show(grid(df, base, v, balance), "B) SL GEOMETRIYASI")

    # ── C) RR ──────────────────────────────────────────────────────
    v = {}
    for rr in (1.0, 1.25, 1.5, 2.0, 2.5, 3.0):
        v[f"RR {rr:.2f} (SL asl)"] = {"rr": rr}
    show(grid(df, base, v, balance), "C) RISK/REWARD (asl SL bilan)")

    # ── D) kirish rejimi ───────────────────────────────────────────
    v = {"MARKET (asl)": {}}
    for o in (0.05, 0.10, 0.20, 0.40):
        v[f"PENDING offset {o:.2f}"] = {"entry_mode": "pending",
                                        "pending_offset": o}
    show(grid(df, base, v, balance), "D) KIRISH REJIMI")

    # ── E) TP rejimi ───────────────────────────────────────────────
    v = {"TP = RR 2.0 (asl)": {}}
    for k in (0.50, 0.75, 1.00, 1.50, 2.00):
        v[f"TP = level + {k:.2f} x range"] = {"tp_mode": "range_mult",
                                              "tp_range_mult": k}
    show(grid(df, base, v, balance), "E) TP REJIMI")

    # ── F) filtrlar (bitta-bittadan) ───────────────────────────────
    v = {
        "BAZA (filtrsiz)":        {},
        "Kuniga max 1 savdo":     {"max_trades_per_day": 1},
        "Kuniga max 2 savdo":     {"max_trades_per_day": 2},
        "Range ATR filtri":       {"use_range_filter": True},
        "Min penetratsiya 5%":    {"min_break_pct": 5.0},
        "Min bar tanasi 35%":     {"min_body_pct": 35.0},
        "Kech kirish max 30%":    {"max_entry_dist_pct": 30.0},
        "BE @ +1.0R":             {"use_be": True, "be_trigger_r": 1.0},
        "BE @ +1.5R":             {"use_be": True, "be_trigger_r": 1.5},
        "Trailing @ +1.5R":       {"use_trail": True},
        "Vaqt chiqishi 22:00":    {"use_time_exit": True, "force_close_hour": 22},
        "Dushanbasiz":            {"weekdays": (1, 2, 3, 4)},
        "Jumasiz":                {"weekdays": (0, 1, 2, 3)},
    }
    show(grid(df, base, v, balance), "F) FILTRLAR (har biri ALOHIDA)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv")
    ap.add_argument("--synth", type=int, default=0)
    ap.add_argument("--tz", type=int, default=0)
    ap.add_argument("--balance", type=float, default=5000.0)
    ap.add_argument("--spread", type=float, default=0.30)
    ap.add_argument("--commission", type=float, default=0.0)
    a = ap.parse_args()

    if a.csv:
        df = load_mt5_csv(a.csv, a.tz); src = os.path.basename(a.csv)
    elif a.synth:
        df = synth(days=a.synth); src = f"SINTETIK {a.synth} kun (engine testi)"
    else:
        ap.error("--csv yoki --synth kerak")

    print(f"Manba: {src}\nData : {describe(df)}")
    standard_suite(df, a.balance, a.spread, a.commission)
