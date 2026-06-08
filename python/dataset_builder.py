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
    *,
    write_outputs: bool = True,
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

    if not write_outputs:
        return df

    output.mkdir(parents=True, exist_ok=True)

    csv_path = output / "tradingai_dataset.csv"
    df.to_csv(csv_path, index=False)
    print(f"  wrote {csv_path}")

    parquet_path = output / "tradingai_dataset.parquet"
    df.to_parquet(parquet_path, index=False)
    print(f"  wrote {parquet_path}")

    return df


def merge_datasets(existing_df: pd.DataFrame, new_df: pd.DataFrame) -> tuple[pd.DataFrame, int, int]:
    """Merge new trades into existing dataset.

    Dedupe key: position_ticket
    Prefer newest values from new_df.
    """
    if existing_df is None or existing_df.empty:
        merged = new_df
        return merged, len(new_df), 0

    if new_df is None or new_df.empty:
        return existing_df, 0, len(existing_df)

    if "position_ticket" not in existing_df.columns or "position_ticket" not in new_df.columns:
        raise ValueError("Both existing_df and new_df must contain 'position_ticket' column")

    existing_df = existing_df.copy()
    new_df = new_df.copy()

    # Identify duplicates against existing.
    existing_keys = set(existing_df["position_ticket"].tolist())
    duplicate_count = sum(1 for k in new_df["position_ticket"].tolist() if k in existing_keys)
    new_unique_count = len(new_df) - duplicate_count

    merged = pd.concat([existing_df, new_df], ignore_index=True)

    # Keep last occurrence per position_ticket (so new_df wins).
    merged = merged.drop_duplicates(subset=["position_ticket"], keep="last")

    # Return: total merged rows, unique new rows added, duplicate rows updated.
    merged_count = len(merged)
    return merged, new_unique_count, duplicate_count


def main() -> int:

    parser = argparse.ArgumentParser(description="Build AI-ready dataset from MT5 TradingAI data.")
    parser.add_argument("--data-dir", type=Path, default=Path("data"), help="Path to JSONL log directory")
    parser.add_argument("--screenshots-dir", type=Path, default=Path("screenshots"), help="Path to screenshots directory")
    parser.add_argument("--output", type=Path, default=Path("dataset"), help="Output directory for dataset files")
    parser.add_argument("--hours-before", type=float, default=1.0, help="Hours of pre-entry context to include")
    parser.add_argument("--hours-after", type=float, default=1.0, help="Hours of post-exit context to include")
    parser.add_argument("--missing-ok", action="store_true", help="Don't warn about missing screenshots")

    # Default to incremental.
    parser.add_argument("--incremental", action="store_true", help="Merge new trades into existing dataset (default)")
    parser.add_argument("--no-incremental", action="store_true", help="Rebuild dataset from scratch and overwrite")

    args = parser.parse_args()
    incremental = bool(args.incremental) and not bool(args.no_incremental)
    # If user didn't pass either flag, default incremental=true.
    if not args.incremental and not args.no_incremental:
        incremental = True

    output_dir = args.output
    parquet_path = output_dir / "tradingai_dataset.parquet"
    csv_path = output_dir / "tradingai_dataset.csv"

    if not incremental:
        # Full rebuild.
        build_dataset(
            data_dir=args.data_dir,
            screenshots_dir=args.screenshots_dir,
            output=output_dir,
            hours_before=args.hours_before,
            hours_after=args.hours_after,
            missing_ok=args.missing_ok,
            write_outputs=True,
        )
        return 0

    # Incremental mode:
    # 1) Build new_df in-memory without overwriting existing outputs.
    new_df = build_dataset(
        data_dir=args.data_dir,
        screenshots_dir=args.screenshots_dir,
        output=output_dir,
        hours_before=args.hours_before,
        hours_after=args.hours_after,
        missing_ok=args.missing_ok,
        write_outputs=False,
    )

    # 2) Load existing dataset (prefer parquet).
    existing_df: Optional[pd.DataFrame] = None
    if parquet_path.exists():
        print(f"incremental: loading existing parquet from {parquet_path} ...")
        existing_df = pd.read_parquet(parquet_path)
    elif csv_path.exists():
        print(f"incremental: loading existing csv from {csv_path} ...")
        existing_df = pd.read_csv(csv_path)

        # CSV parsing yields entry/exit time as strings; parse back to datetime for downstream consistency.
        for col in ("entry_time", "exit_time"):
            if col in existing_df.columns:
                existing_df[col] = pd.to_datetime(existing_df[col], errors="coerce")
    else:
        print("incremental: no existing dataset found; writing newly built dataset")
        output_dir.mkdir(parents=True, exist_ok=True)
        new_df.to_csv(csv_path, index=False)
        new_df.to_parquet(parquet_path, index=False)
        print(f"  wrote {csv_path}")
        print(f"  wrote {parquet_path}")
        return 0

    # 3) Merge new rows on position_ticket; newest values in new_df win.
    merged_df, new_unique_count, duplicate_count = merge_datasets(existing_df, new_df)

    print("incremental: merge summary")
    print(f"  existing rows: {len(existing_df)}")
    print(f"  new rows built: {len(new_df)}")
    print(f"  duplicates updated: {duplicate_count}")
    print(f"  unique new rows added: {new_unique_count}")
    print(f"  merged total rows: {len(merged_df)}")

    # 4) Write merged back to final outputs.
    output_dir.mkdir(parents=True, exist_ok=True)
    merged_df.to_csv(csv_path, index=False)
    print(f"  wrote {csv_path}")

    merged_df.to_parquet(parquet_path, index=False)
    print(f"  wrote {parquet_path}")

    return 0



if __name__ == "__main__":
    raise SystemExit(main())
