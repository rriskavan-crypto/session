"""
Session Breakout Gold — Python backtest engine.

MT5 EA mantiqini aynan takrorlaydi, lekin sekundlarda ishlaydi va
parametrlarni ommaviy sinash (sweep) imkonini beradi.

Barlar BID deb hisoblanadi (MT5 dagidek):
  BUY  kirish  -> ask = open + spread
  BUY  SL/TP   -> bid bo'yicha  (low <= sl,  high >= tp)
  SELL kirish  -> bid = open
  SELL SL/TP   -> ask bo'yicha  (high+spread >= sl,  low+spread <= tp)
"""
from __future__ import annotations

from dataclasses import dataclass, field, replace
import numpy as np
import pandas as pd

# ────────────────────────────────────────────────────────────────────
#  Parametrlar
# ────────────────────────────────────────────────────────────────────


@dataclass
class Session:
    name: str
    range_start: int
    range_end: int
    trade_start: int
    trade_end: int
    enabled: bool = True


@dataclass
class Params:
    # --- sessiyalar --------------------------------------------------
    sessions: list = field(default_factory=lambda: [
        Session("S1", 0, 7, 8, 11, True),
        Session("S2", 8, 13, 14, 17, False),
        Session("S3", 14, 18, 19, 22, False),
    ])

    # --- kirish ------------------------------------------------------
    entry_mode: str = "market"        # 'market' | 'pending'
    pending_offset: float = 0.10      # narx birligida

    # --- SL ----------------------------------------------------------
    sl_mode: str = "range_from_entry"  # asl formula
    #              'range_fraction' | 'range_level' | 'atr'
    sl_range_frac: float = 0.50
    sl_atr_mult: float = 1.00
    sl_buffer: float = 0.50           # narx birligida (50 punkt @ 2 digit)

    # --- TP ----------------------------------------------------------
    tp_mode: str = "rr"               # 'rr' | 'range_mult' | 'atr'
    rr: float = 2.0
    tp_range_mult: float = 1.00
    tp_atr_mult: float = 2.00

    # --- filtrlar (0 / False = o'chiq, asl koddagidek) ---------------
    max_entry_dist_pct: float = 0.0
    min_break_pct: float = 0.0
    min_body_pct: float = 0.0
    use_range_filter: bool = False
    min_range_atr: float = 0.30
    max_range_atr: float = 2.00
    max_trades_per_session: int = 0    # 0 = cheksiz
    max_trades_per_day: int = 0
    max_concurrent: int = 1
    weekdays: tuple = (0, 1, 2, 3, 4)  # Mon..Fri

    # --- pozitsiya boshqaruvi (o'chiq) -------------------------------
    use_be: bool = False
    be_trigger_r: float = 1.5
    be_lock_r: float = 0.15
    use_trail: bool = False
    trail_start_r: float = 1.5
    trail_dist_r: float = 0.75
    use_time_exit: bool = False
    force_close_hour: int = 23
    close_friday: bool = False
    friday_close_hour: int = 20

    # --- xarajatlar / kontrakt ---------------------------------------
    lot: float = 0.10
    contract_size: float = 100.0       # XAUUSD: 1 lot = 100 unsiya
    spread: float = 0.30               # narx birligida
    commission_per_lot: float = 0.0    # ikki tomonlama, 1 lot uchun
    max_spread: float = 3.50           # asl: 350 punkt @ 2 digit
    pessimistic: bool = True           # bir barda SL va TP bo'lsa -> SL


# ────────────────────────────────────────────────────────────────────
#  Yordamchilar
# ────────────────────────────────────────────────────────────────────


def true_range(df: pd.DataFrame) -> pd.Series:
    pc = df["close"].shift(1)
    return pd.concat([
        df["high"] - df["low"],
        (df["high"] - pc).abs(),
        (df["low"] - pc).abs(),
    ], axis=1).max(axis=1)


def daily_atr(df: pd.DataFrame, period: int = 20) -> pd.Series:
    """Kunlik ATR, sana bo'yicha indekslangan (oldingi kunlar asosida)."""
    d = df.resample("1D").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}
    ).dropna()
    atr = true_range(d).rolling(period).mean().shift(1)   # repaint yo'q
    atr.index = atr.index.date
    return atr


def bar_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    return true_range(df).rolling(period).mean().shift(1)


def _session_day(idx: pd.DatetimeIndex, start: int, end: int) -> np.ndarray:
    """Oyna yarim tunni kesib o'tsa, range OXIRIDAGI kunga tegishli."""
    days = idx.normalize()
    if end > start:
        return days.date
    nxt = days + pd.Timedelta(days=1)
    return np.where(idx.hour >= start, nxt.date, days.date)


def _in_window(hour: np.ndarray, start: int, end: int) -> np.ndarray:
    if start == end:
        return np.zeros_like(hour, dtype=bool)
    if start < end:
        return (hour >= start) & (hour < end)
    return (hour >= start) | (hour < end)


def build_ranges(df: pd.DataFrame, s: Session) -> pd.DataFrame:
    """Har kun uchun sessiya range'ini oldindan hisoblash."""
    mask = _in_window(df.index.hour.values, s.range_start, s.range_end)
    if not mask.any():
        return pd.DataFrame(columns=["high", "low", "width", "bars"])
    sub = df[mask]
    key = _session_day(sub.index, s.range_start, s.range_end)
    g = sub.groupby(key)
    out = pd.DataFrame({
        "high": g["high"].max(),
        "low": g["low"].min(),
        "bars": g["close"].size(),
    })
    out["width"] = out["high"] - out["low"]
    return out[out["width"] > 0]


# ────────────────────────────────────────────────────────────────────
#  Savdo
# ────────────────────────────────────────────────────────────────────


@dataclass
class Trade:
    session: str
    side: int            # +1 buy, -1 sell
    t_in: pd.Timestamp
    price_in: float
    sl: float
    tp: float
    init_sl: float
    risk: float
    range_width: float
    t_out: pd.Timestamp = None
    price_out: float = None
    reason: str = ""
    pnl: float = 0.0
    r: float = 0.0


class Backtest:
    def __init__(self, df: pd.DataFrame, p: Params):
        self.df = df
        self.p = p
        self.d_atr = daily_atr(df)
        self.b_atr = bar_atr(df)
        self.ranges = {s.name: build_ranges(df, s)
                       for s in p.sessions if s.enabled}

    # ---- SL / TP rejimlari -----------------------------------------
    def _sl(self, s_name, side, entry, rng_hi, rng_lo, width, atr):
        p = self.p
        buf = p.sl_buffer
        if p.sl_mode == "range_from_entry":          # ASL
            d = width + buf
            return entry - d if side > 0 else entry + d
        if p.sl_mode == "range_fraction":
            d = width * p.sl_range_frac + buf
            return entry - d if side > 0 else entry + d
        if p.sl_mode == "range_level":
            return (rng_lo - buf) if side > 0 else (rng_hi + buf + p.spread)
        if p.sl_mode == "atr":
            a = atr if atr and atr > 0 else width
            d = a * p.sl_atr_mult + buf
            return entry - d if side > 0 else entry + d
        raise ValueError(p.sl_mode)

    def _tp(self, side, entry, risk, rng_hi, rng_lo, width, atr):
        p = self.p
        if p.tp_mode == "rr":
            return entry + risk * p.rr if side > 0 else entry - risk * p.rr
        if p.tp_mode == "range_mult":
            lvl = rng_hi if side > 0 else rng_lo
            d = width * p.tp_range_mult
            return lvl + d if side > 0 else lvl - d
        if p.tp_mode == "atr":
            a = atr if atr and atr > 0 else width
            d = a * p.tp_atr_mult
            return entry + d if side > 0 else entry - d
        raise ValueError(p.tp_mode)

    # ---- asosiy sikl -------------------------------------------------
    def run(self) -> pd.DataFrame:
        p = self.p
        df = self.df
        o = df["open"].values
        h = df["high"].values
        l = df["low"].values
        c = df["close"].values
        idx = df.index
        hour = idx.hour.values
        dow = idx.dayofweek.values
        dates = idx.date
        batr = self.b_atr.values

        sessions = [s for s in p.sessions if s.enabled]
        rng = self.ranges

        open_tr: list[Trade] = []
        done: list[Trade] = []
        pend: dict = {}            # session -> (day, buy_px, sell_px)
        cnt_sess: dict = {}
        cnt_day = {}

        money = p.lot * p.contract_size
        comm = p.commission_per_lot * p.lot

        for i in range(1, len(df)):
            ts, hh, dd, day = idx[i], hour[i], dow[i], dates[i]

            # ═══ 1) ochiq pozitsiyalarni boshqarish ═══════════════════
            still = []
            for t in open_tr:
                exit_px = exit_why = None

                if t.side > 0:
                    hit_sl = l[i] <= t.sl
                    hit_tp = h[i] >= t.tp
                else:
                    hit_sl = (h[i] + p.spread) >= t.sl
                    hit_tp = (l[i] + p.spread) <= t.tp

                if hit_sl and hit_tp:
                    exit_px, exit_why = ((t.sl, "SL") if p.pessimistic
                                         else (t.tp, "TP"))
                elif hit_sl:
                    exit_px, exit_why = t.sl, "SL"
                elif hit_tp:
                    exit_px, exit_why = t.tp, "TP"

                # vaqt bo'yicha chiqish
                if exit_px is None:
                    tex = (p.use_time_exit and hh >= p.force_close_hour)
                    fri = (p.close_friday and dd == 4
                           and hh >= p.friday_close_hour)
                    if tex or fri:
                        exit_px = c[i] if t.side > 0 else c[i] + p.spread
                        exit_why = "TIME"

                if exit_px is not None:
                    t.t_out, t.price_out, t.reason = ts, exit_px, exit_why
                    t.pnl = (exit_px - t.price_in) * t.side * money - comm
                    t.r = t.pnl / (t.risk * money) if t.risk > 0 else 0.0
                    done.append(t)
                    continue

                # BE / trailing (bar yopilish narxi bo'yicha)
                if p.use_be or p.use_trail:
                    cp = c[i] if t.side > 0 else c[i] + p.spread
                    rnow = (cp - t.price_in) * t.side / t.risk
                    new = t.sl
                    if p.use_be and rnow >= p.be_trigger_r:
                        be = t.price_in + t.side * t.risk * p.be_lock_r
                        new = max(new, be) if t.side > 0 else min(new, be)
                    if p.use_trail and rnow >= p.trail_start_r:
                        tr = cp - t.side * t.risk * p.trail_dist_r
                        new = max(new, tr) if t.side > 0 else min(new, tr)
                    t.sl = new
                still.append(t)
            open_tr = still

            # ═══ 2) kirish ═══════════════════════════════════════════
            if dd not in p.weekdays:
                continue
            if p.max_concurrent and len(open_tr) >= p.max_concurrent:
                continue
            if p.max_trades_per_day and cnt_day.get(day, 0) >= p.max_trades_per_day:
                continue

            for s in sessions:
                r = rng[s.name]
                if day not in r.index:
                    continue
                if not _in_window(np.array([hh]), s.trade_start, s.trade_end)[0]:
                    continue
                if any(t.session == s.name for t in open_tr):
                    continue

                k = (s.name, day)
                if p.max_trades_per_session and cnt_sess.get(k, 0) >= p.max_trades_per_session:
                    continue

                row = r.loc[day]
                hi, lo, w = row["high"], row["low"], row["width"]

                # range kengligi filtri
                if p.use_range_filter:
                    a = self.d_atr.get(day, np.nan)
                    if a == a and a > 0:
                        if w < a * p.min_range_atr or w > a * p.max_range_atr:
                            continue

                atr_now = batr[i] if batr[i] == batr[i] else 0.0
                side = entry = None

                # ── PENDING STOP ─────────────────────────────────────
                if p.entry_mode == "pending":
                    if pend.get(s.name, (None,))[0] != day:
                        pend[s.name] = (day, hi + p.pending_offset,
                                        lo - p.pending_offset)
                    _, bpx, spx = pend[s.name]
                    # buy stop: ask = high + spread
                    if (h[i] + p.spread) >= bpx:
                        side, entry = 1, max(bpx, o[i] + p.spread)
                    elif l[i] <= spx:
                        side, entry = -1, min(spx, o[i])

                # ── MARKET (ASL) ─────────────────────────────────────
                else:
                    prev_up = c[i - 1] > hi
                    prev_dn = c[i - 1] < lo
                    if not (prev_up or prev_dn):
                        continue
                    side = 1 if prev_up else -1

                    if p.min_break_pct > 0:
                        pen = (c[i - 1] - hi) if side > 0 else (lo - c[i - 1])
                        if pen < w * p.min_break_pct / 100.0:
                            continue
                    if p.min_body_pct > 0:
                        br = h[i - 1] - l[i - 1]
                        if br > 0:
                            body = abs(c[i - 1] - o[i - 1]) / br * 100.0
                            if body < p.min_body_pct:
                                continue
                            if (c[i - 1] > o[i - 1]) != (side > 0):
                                continue
                    entry = o[i] + p.spread if side > 0 else o[i]

                if side is None:
                    continue

                if p.max_entry_dist_pct > 0:
                    dist = (entry - hi) if side > 0 else (lo - entry)
                    if dist > w * p.max_entry_dist_pct / 100.0:
                        continue
                if p.spread > p.max_spread:
                    continue

                sl = self._sl(s.name, side, entry, hi, lo, w, atr_now)
                risk = abs(entry - sl)
                if risk <= 0:
                    continue
                tp = self._tp(side, entry, risk, hi, lo, w, atr_now)
                if (side > 0 and tp <= entry) or (side < 0 and tp >= entry):
                    continue

                open_tr.append(Trade(s.name, side, ts, entry, sl, tp, sl,
                                     risk, w))
                cnt_sess[k] = cnt_sess.get(k, 0) + 1
                cnt_day[day] = cnt_day.get(day, 0) + 1
                if p.max_concurrent and len(open_tr) >= p.max_concurrent:
                    break

        # oxirida ochiq qolganlarni yopamiz
        for t in open_tr:
            t.t_out = idx[-1]
            t.price_out = c[-1] if t.side > 0 else c[-1] + p.spread
            t.reason = "EOD"
            t.pnl = (t.price_out - t.price_in) * t.side * money - comm
            t.r = t.pnl / (t.risk * money) if t.risk > 0 else 0.0
            done.append(t)

        done.sort(key=lambda x: x.t_in)
        return pd.DataFrame([vars(t) for t in done])


# ────────────────────────────────────────────────────────────────────
#  Metrikalar
# ────────────────────────────────────────────────────────────────────


def metrics(tr: pd.DataFrame, balance: float = 5000.0) -> dict:
    if tr is None or len(tr) == 0:
        return {"trades": 0, "win_pct": 0.0, "pf": 0.0, "net": 0.0,
                "max_dd_pct": 0.0, "expectancy_r": 0.0, "avg_r": 0.0,
                "max_losses": 0, "net_pct": 0.0}

    pnl = tr["pnl"].to_numpy()
    wins, losses = pnl[pnl > 0], pnl[pnl <= 0]
    gp, gl = wins.sum(), -losses.sum()

    eq = balance + np.cumsum(pnl)
    peak = np.maximum.accumulate(np.concatenate([[balance], eq]))
    dd = (peak - np.concatenate([[balance], eq])) / peak * 100.0

    streak = mx = 0
    for x in pnl:
        streak = streak + 1 if x <= 0 else 0
        mx = max(mx, streak)

    return {
        "trades": int(len(tr)),
        "win_pct": round(len(wins) / len(pnl) * 100.0, 1),
        "pf": round(gp / gl, 2) if gl > 0 else float("inf"),
        "net": round(pnl.sum(), 2),
        "net_pct": round(pnl.sum() / balance * 100.0, 1),
        "max_dd_pct": round(dd.max(), 1),
        "expectancy_r": round(tr["r"].mean(), 3),
        "avg_r": round(tr["r"].mean(), 3),
        "avg_win": round(wins.mean(), 2) if len(wins) else 0.0,
        "avg_loss": round(losses.mean(), 2) if len(losses) else 0.0,
        "max_losses": int(mx),
    }


def summary_line(name: str, m: dict) -> str:
    return (f"{name:<28} trades={m['trades']:>4}  win={m['win_pct']:>5.1f}%  "
            f"PF={m['pf']:>5.2f}  net={m['net']:>9.2f} ({m['net_pct']:>+6.1f}%)  "
            f"DD={m['max_dd_pct']:>5.1f}%  E[R]={m['expectancy_r']:>+6.3f}")
