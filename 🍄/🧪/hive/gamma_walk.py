#!/usr/bin/env python3
"""gamma-walk — what does decay MEAN? Walk γ on real play tapes and let the
forecasts decide.

The hypothesis under test (the filtering frame): γ is the model's prior on
the world's own decorrelation time. If that's decay's meaning, then the
prequentially-optimal γ* for each signal should match that signal's true
rate of change — fast-moving wallet lines want large γ, slow stock wants
γ≈0, and the SPREAD of γ* across signals is the game's tempo signature.

Method (the ladder-walk discipline, re-pointed at decay):
  For each real observation series (wallet lines from the fleet's seat
  tapes): hold a scalar belief b ∈ [-1,1]. On each observation, weak-update
  b ← (1-α)b + α·z at fixed α; BETWEEN observations decay b ← b·exp(-γ·Δt).
  Before each observation, score |denorm(b) - actual| — prequential MAE.
  Sweep γ. Baselines: persistence (hold last value) and γ=0 (never decay).
  Also one adaptive rule (γ learned online from innovation vs hold time).

Honest expectations: persistence is hard to beat on stationary series
(umwelt's own ledger); the interesting output is the per-signal γ* SPREAD
and where decay genuinely earns — not a victory lap.

Usage:  gamma_walk.py [--alpha 0.5] [--min-points 12]
Writes: gamma_walk_results.json beside this file; prints the table.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEATS = Path("/tmp/sw_player_seats")
GAMMAS = [0.0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2, 1e-1]
TURN_S = 20.0  # nominal seconds per seat turn (the tape exporter's clock)


def wallet_series() -> dict[str, list[tuple[float, float]]]:
    """Every wallet line from every surviving seat tape: series[key] =
    [(t_seconds, value), ...] — key = seat/emoji so regimes don't mix."""
    series: dict[str, list[tuple[float, float]]] = {}
    for results in sorted(SEATS.glob("*/godot/app_userdata/*/rig/results.jsonl")):
        seat = results.relative_to(SEATS).parts[0]
        for line in results.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("action") != "resource_snapshot" or not row.get("ok"):
                continue
            wallet = row.get("resources", row.get("snapshot", {}))
            if isinstance(wallet, dict) and "resources" in wallet:
                wallet = wallet["resources"]
            if not isinstance(wallet, dict):
                continue
            t = float(row.get("turn", 0)) * TURN_S
            for emoji, v in wallet.items():
                series.setdefault(f"{seat}/{emoji}", []).append((t, float(v)))
    return series


def prequential(points: list[tuple[float, float]], gamma: float, alpha: float,
                lo: float, hi: float, adaptive: bool = False) -> float:
    """MAE of the decayed-belief forecast over one series."""
    def norm(v: float) -> float:
        return 2.0 * (v - lo) / max(hi - lo, 1e-9) - 1.0

    def denorm(z: float) -> float:
        return lo + (z + 1.0) * 0.5 * (hi - lo)

    b = 0.0  # blank: maximum uncertainty (the midpoint once denormed)
    g = gamma
    t_prev = points[0][0]
    err = 0.0
    n = 0
    for t, v in points:
        dt = max(0.0, t - t_prev)
        b *= math.exp(-g * dt)
        err += abs(denorm(b) - v)
        n += 1
        innovation = abs(norm(v) - b)
        if adaptive and dt > 0:
            # decay's meaning, learned online: if held belief was WRONG after
            # the gap, the world moved faster than γ assumed — raise it; if
            # the hold was right, the world is slower — relax γ.
            target = innovation / max(dt, 1e-9)
            g += 0.2 * (min(target, 0.1) - g)
        b = (1.0 - alpha) * b + alpha * norm(v)
        t_prev = t
    return err / max(n, 1)


def calibration(points: list[tuple[float, float]], gamma: float, alpha: float,
                lo: float, hi: float) -> float | None:
    """Decay as an UNCERTAINTY model: belief magnitude |b| decays between
    observations; staleness (1-|b|) should predict the size of the coming
    error. Returns the Pearson correlation between (1-|b|) before each
    observation and the actual |persistence error| at it — the honest test
    of 'decay means confidence', scored against the value-forecast that
    actually wins (persistence)."""
    def norm(v: float) -> float:
        return 2.0 * (v - lo) / max(hi - lo, 1e-9) - 1.0

    b = 0.0
    t_prev = points[0][0]
    last_v = None
    xs: list[float] = []
    ys: list[float] = []
    for t, v in points:
        dt = max(0.0, t - t_prev)
        b *= math.exp(-gamma * dt)
        if last_v is not None:
            xs.append(1.0 - abs(b))                  # staleness before seeing v
            ys.append(abs(v - last_v))               # how wrong holding was
        b = (1.0 - alpha) * b + alpha * norm(v)
        last_v = v
        t_prev = t
    n = len(xs)
    if n < 8:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    vx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    vy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if vx < 1e-12 or vy < 1e-12:
        return None
    return cov / (vx * vy)


def persistence(points: list[tuple[float, float]]) -> float:
    last = None
    err = 0.0
    n = 0
    for _t, v in points:
        if last is not None:
            err += abs(last - v)
            n += 1
        last = v
    return err / max(n, 1)


def volatility(points: list[tuple[float, float]]) -> float:
    """Empirical decorrelation proxy: mean |Δv| per second, normalized."""
    lo = min(v for _t, v in points)
    hi = max(v for _t, v in points)
    span = max(hi - lo, 1e-9)
    total = 0.0
    dt_total = 0.0
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        total += abs(v1 - v0) / span
        dt_total += max(t1 - t0, 1e-9)
    return total / max(dt_total, 1e-9)


def main() -> int:
    alpha = 0.5
    min_points = 12
    if "--alpha" in sys.argv:
        alpha = float(sys.argv[sys.argv.index("--alpha") + 1])
    if "--min-points" in sys.argv:
        min_points = int(sys.argv[sys.argv.index("--min-points") + 1])

    rows = []
    for key, points in sorted(wallet_series().items()):
        points.sort()
        if len(points) < min_points:
            continue
        values = [v for _t, v in points]
        lo, hi = min(values), max(values)
        if hi - lo < 1e-9:
            continue  # flat: nothing to forecast, nothing to learn
        scores = {g: prequential(points, g, alpha, lo, hi) for g in GAMMAS}
        adaptive_score = prequential(points, 0.0, alpha, lo, hi, adaptive=True)
        best_gamma = min(scores, key=lambda g: scores[g])
        calib = {g: calibration(points, g, alpha, lo, hi) for g in GAMMAS}
        calib_clean = {g: c for g, c in calib.items() if c is not None}
        calib_star = max(calib_clean, key=lambda g: calib_clean[g]) if calib_clean else None
        rows.append({
            "series": key, "n": len(points), "volatility_per_s": volatility(points),
            "persistence_mae": persistence(points),
            "gamma_star": best_gamma, "gamma_star_mae": scores[best_gamma],
            "gamma0_mae": scores[0.0], "adaptive_mae": adaptive_score,
            "calib_gamma_star": calib_star,
            "calib_at_star": calib_clean.get(calib_star),
            "calib_at_zero": calib.get(0.0),
            "scores": {("%.0e" % g): s for g, s in scores.items()},
        })

    decay_wins = sum(1 for r in rows if r["gamma_star"] > 0.0
                     and r["gamma_star_mae"] < r["gamma0_mae"] - 1e-9)
    beats_persistence = sum(1 for r in rows
                            if r["gamma_star_mae"] < r["persistence_mae"] - 1e-9)
    adaptive_beats_fixed = sum(1 for r in rows
                               if r["adaptive_mae"] < r["gamma_star_mae"] + 1e-9)
    # The hypothesis: γ* tracks volatility. Rank correlation, no scipy.
    ranked = sorted(rows, key=lambda r: r["volatility_per_s"])
    n = len(ranked)
    corr = None
    if n >= 8:
        vol_rank = {r["series"]: i for i, r in enumerate(ranked)}
        gam_rank = {r["series"]: i for i, r in enumerate(
            sorted(rows, key=lambda r: r["gamma_star"]))}
        d2 = sum((vol_rank[r["series"]] - gam_rank[r["series"]]) ** 2 for r in rows)
        corr = 1.0 - 6.0 * d2 / (n * (n * n - 1))

    out = {"alpha": alpha, "series_scored": n, "decay_beats_no_decay": decay_wins,
           "beats_persistence": beats_persistence,
           "adaptive_at_least_matches_best_fixed": adaptive_beats_fixed,
           "spearman_gamma_star_vs_volatility": corr, "rows": rows}
    (HERE / "gamma_walk_results.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    print(f"gamma-walk over {n} live wallet series (α={alpha}):")
    print(f"  decay (γ*>0) beats never-decay on {decay_wins}/{n}")
    print(f"  best fixed γ beats PERSISTENCE on {beats_persistence}/{n} "
          f"(persistence is the honest bar)")
    print(f"  online-adaptive γ ≥ best fixed γ on {adaptive_beats_fixed}/{n}")
    if corr is not None:
        print(f"  Spearman(γ*, volatility) = {corr:+.2f}  "
              f"(the 'decay = volatility prior' hypothesis)")
    print("\n  slowest vs fastest signals (γ* spread = the game's tempo signature):")
    for r in ranked[:3] + ranked[-3:]:
        print(f"    {r['series']:24s} vol={r['volatility_per_s']:.2e}/s  "
              f"γ*={r['gamma_star']:.0e}  mae γ*/pers = "
              f"{r['gamma_star_mae']:.2f}/{r['persistence_mae']:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
