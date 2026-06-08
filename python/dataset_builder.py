#!/usr/bin/env python3
"""Build a structured AI-ready dataset from MT5 TradingAI logs and screenshots.

Usage:
    python dataset_builder.py --data-dir ../data --screenshots-dir ../screenshots --output ../dataset
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Optional

import pandas as pd

from models import TrainingSample
from parser import load_time_events, load_trade_events, parse_trades
from linker import build_training_sample


def samples_to_dataframe(samples: list[TrainingSample]) -> pd.DataFrame:
    rows = []
    for s in samples:
        t = s.trade
        rows.append({
            "position_ticket": t.position_ticket,
            "symbol": t.symbol,
            "deal_type": t.deal_type,
            "entry_time": t.entry_time,
            "exit_time": t.exit_time,
            "entry_price": t.entry_price,
            "exit_price": t.exit_price,
            "volume": t.volume,
            "profit": t.profit,
            "sl": t.sl,
            "tp": t.tp,
            "rr": t.rr,
            "win_loss": t.win_loss,
            "duration_minutes": t.duration_minutes,
            "entry_screenshots": "|".join(t.entry_screenshots),
            "exit_screenshots": "|".join(t.exit_screenshots),
            "entry_deal_tickets": "|".join(str(d) for d in t.entry_deal_tickets),
            "exit_deal_tickets": "|".join(str(d) for d in t.exit_deal_tickets),
            "pre_entry_snapshots": len(s.pre_entry_snapshots),
            "post_exit_snapshots": len(s.post_exit_snapshots),
        })
    return pd.DataFrame(rows)


def build_dataset(
    data_dir: Path,
    screenshots_dir: Path,
    output: Path,
    hours_before: float = 1.0,
    hours_after: float = 1.0,
    missing_ok: bool = False,
) -> pd.DataFrame:
    print(f"loading time events from {data_dir} ...")
    time_events = load_time_events(data_dir)
    print(f"  found {len(time_events)} time event(s)")

    print(f"loading trade events from {data_dir} ...")
    trade_events = load_trade_events(data_dir)
    print(f"  found {len(trade_events)} trade event(s)")

    print("parsing trades ...")
    records = parse_trades(trade_events)
    print(f"  built {len(records)} trade record(s)")

    print("linking screenshots and context ...")
    samples: list[TrainingSample] = []
    missing_screenshots = 0
    for record in records:
        sample = build_training_sample(record, time_events, screenshots_dir, hours_before, hours_after)

        if not missing_ok:
            if record.entry_screenshots and not sample.trade.entry_screenshots:
                missing_screenshots += 1
            if record.exit_screenshots and not sample.trade.exit_screenshots:
                missing_screenshots += 1

        samples.append(sample)

    if missing_screenshots:
        print(f"  warning: {missing_screenshots} screenshot(s) missing")

    df = samples_to_dataframe(samples)
    print(f"  built {len(df)} training sample(s)")

    output.mkdir(parents=True, exist_ok=True)

    csv_path = output / "tradingai_dataset.csv"
    df.to_csv(csv_path, index=False)
    print(f"  wrote {csv_path}")

    parquet_path = output / "tradingai_dataset.parquet"
    df.to_parquet(parquet_path, index=False)
    print(f"  wrote {parquet_path}")

    return df


def main() -> int:
    parser = argparse.ArgumentParser(description="Build AI-ready dataset from MT5 TradingAI data.")
    parser.add_argument("--data-dir", type=Path, default=Path("data"), help="Path to JSONL log directory")
    parser.add_argument("--screenshots-dir", type=Path, default=Path("screenshots"), help="Path to screenshots directory")
    parser.add_argument("--output", type=Path, default=Path("dataset"), help="Output directory for dataset files")
    parser.add_argument("--hours-before", type=float, default=1.0, help="Hours of pre-entry context to include")
    parser.add_argument("--hours-after", type=float, default=1.0, help="Hours of post-exit context to include")
    parser.add_argument("--missing-ok", action="store_true", help="Don't warn about missing screenshots")
    args = parser.parse_args()

    build_dataset(
        data_dir=args.data_dir,
        screenshots_dir=args.screenshots_dir,
        output=args.output,
        hours_before=args.hours_before,
        hours_after=args.hours_after,
        missing_ok=args.missing_ok,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
