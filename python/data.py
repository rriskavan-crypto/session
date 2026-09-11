"""Ma'lumot yuklash: MT5 CSV eksporti + sintetik generator (engine testi uchun)."""
from __future__ import annotations
import numpy as np
import pandas as pd
import re

REQ = ["open", "high", "low", "close"]


def load_mt5_csv(path: str, tz_shift_hours: int = 0) -> pd.DataFrame:
    """
    MT5 dan eksport qilingan CSV ni o'qiydi. Qo'llab-quvvatlanadigan formatlar:
      * Standart MT5 eksporti (tab bilan):
          <DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>
      * ExportBars.mq5 skripti chiqarganini (vergul bilan):
          datetime,open,high,low,close,tick_volume,spread
    tz_shift_hours — server vaqtini siljitish (kerak bo'lsa).
    """
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        head = f.readline()

    sep = "\t" if head.count("\t") >= 3 else ","
    df = pd.read_csv(path, sep=sep, encoding="utf-8-sig", engine="python")
    df.columns = [re.sub(r"[<>]", "", str(c)).strip().lower() for c in df.columns]

    # --- vaqt ustunini yig'ish ---------------------------------------
    if "date" in df.columns and "time" in df.columns:
        ts = pd.to_datetime(df["date"].astype(str).str.replace(".", "-", regex=False)
                            + " " + df["time"].astype(str),
                            format="mixed", errors="coerce")
    else:
        tcol = next((c for c in ("datetime", "time", "date", "timestamp")
                     if c in df.columns), None)
        if tcol is None:
            raise ValueError(f"Vaqt ustuni topilmadi. Ustunlar: {list(df.columns)}")
        ts = pd.to_datetime(df[tcol].astype(str).str.replace(".", "-", regex=False),
                            format="mixed", errors="coerce")

    df["ts"] = ts
    df = df.dropna(subset=["ts"])

    missing = [c for c in REQ if c not in df.columns]
    if missing:
        raise ValueError(f"Ustunlar yetishmayapti: {missing}. Bor: {list(df.columns)}")

    out = df.set_index("ts")[REQ].astype(float).sort_index()
    out = out[~out.index.duplicated(keep="first")]
    if tz_shift_hours:
        out.index = out.index + pd.Timedelta(hours=tz_shift_hours)
    return out


def describe(df: pd.DataFrame) -> str:
    step = df.index.to_series().diff().dropna().mode()
    tf = step.iloc[0] if len(step) else pd.Timedelta(0)
    days = df.index.normalize().nunique()
    return (f"{len(df):,} bar | {df.index[0]:%Y-%m-%d} .. {df.index[-1]:%Y-%m-%d} "
            f"| {days} kun | TF ~{int(tf.total_seconds()//60)}m "
            f"| narx {df['low'].min():.2f}-{df['high'].max():.2f}")


# ────────────────────────────────────────────────────────────────────
#  Sintetik ma'lumot — FAQAT engine ni tekshirish uchun.
#  Haqiqiy strategiya natijasini BILDIRMAYDI.
# ────────────────────────────────────────────────────────────────────


def synth(days: int = 400, tf_min: int = 15, seed: int = 7,
          start_price: float = 2000.0) -> pd.DataFrame:
    """
    Oltinga o'xshash M15 barlar: Osiyo sessiyasi tinch, London/NY faol.
    Kunlarning bir qismida breakout davom etadi, bir qismida qaytadi.
    """
    rng = np.random.default_rng(seed)
    per_day = 24 * 60 // tf_min
    idx, rows = [], []
    px = start_price
    t0 = pd.Timestamp("2023-01-02 00:00")

    for d in range(days):
        day = t0 + pd.Timedelta(days=d)
        if day.dayofweek >= 5:          # dam olish kunlari yo'q
            continue

        # kun rejimi: 45% trend davom etadi, 55% whipsaw
        trend_day = rng.random() < 0.45
        drift_dir = rng.choice([-1, 1])
        day_vol = rng.lognormal(mean=np.log(0.55), sigma=0.45)   # $/bar

        for b in range(per_day):
            ts = day + pd.Timedelta(minutes=b * tf_min)
            h = ts.hour
            # sessiya volatilligi
            if 0 <= h < 7:      k, drift = 0.45, 0.0                    # Osiyo
            elif 7 <= h < 12:   k, drift = 1.60, (0.10 if trend_day else 0.0)  # London
            elif 12 <= h < 17:  k, drift = 1.30, (0.06 if trend_day else 0.0)  # NY oldi
            elif 17 <= h < 21:  k, drift = 1.00, 0.0                    # NY
            else:               k, drift = 0.35, 0.0

            sig = day_vol * k
            step = rng.normal(drift * drift_dir * sig, sig)
            o = px
            c = o + step
            wick = abs(rng.normal(0, sig * 0.55))
            hi = max(o, c) + wick * rng.random()
            lo = min(o, c) - wick * rng.random()
            rows.append((o, hi, lo, c))
            idx.append(ts)
            px = c

    return pd.DataFrame(rows, columns=REQ, index=pd.DatetimeIndex(idx))
