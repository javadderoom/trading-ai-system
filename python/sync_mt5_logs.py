#!/usr/bin/env python3
"""Mirror MT5 TradingAI data (screenshots + JSONL logs) into the repo.

Source layout from the EA:
    TradingAI/
      screenshots/<symbol>/<timeframe>/<file>.png
      time_events_YYYYMMDD.jsonl
      trade_events_YYYYMMDD.jsonl

Repo layout:
    screenshots/<symbol>/<timeframe>/<file>.png
    data/time_events_YYYYMMDD.jsonl
    data/trade_events_YYYYMMDD.jsonl
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def sync_file(src: Path, dest: Path, delete_source: bool) -> bool:
    if dest.exists():
        src_stat = src.stat()
        dest_stat = dest.stat()
        if src_stat.st_size == dest_stat.st_size and int(src_stat.st_mtime) == int(dest_stat.st_mtime):
            return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    if delete_source:
        src.unlink()
    return True


def sync_pngs(source_root: Path, dest_root: Path, delete_source: bool) -> int:
    screenshots_source = source_root / "screenshots"
    if not screenshots_source.exists():
        return 0
    copied = 0
    for src in sorted(screenshots_source.rglob("*.png")):
        if not src.is_file():
            continue
        rel = src.relative_to(screenshots_source)
        dest = dest_root / "screenshots" / rel
        if sync_file(src, dest, delete_source):
            action = "moved" if delete_source else "copied"
            print(f"{action} screenshots/{rel.as_posix()}")
            copied += 1
    return copied


def sync_jsonls(source_root: Path, dest_root: Path, delete_source: bool) -> int:
    copied = 0
    for pattern in ("time_events_*.jsonl", "trade_events_*.jsonl"):
        for src in sorted(source_root.glob(pattern)):
            if not src.is_file():
                continue
            dest = dest_root / "data" / src.name
            if sync_file(src, dest, delete_source):
                action = "moved" if delete_source else "copied"
                print(f"{action} data/{src.name}")
                copied += 1
    return copied


def sync_all(source_root: Path, dest_root: Path, delete_source: bool) -> int:
    total = 0
    total += sync_pngs(source_root, dest_root, delete_source)
    total += sync_jsonls(source_root, dest_root, delete_source)
    return total


def build_default_source() -> Path:
    env = os.environ.get("TRADINGAI_MT5_ROOT")
    if env:
        return Path(env)
    return REPO_ROOT / "mt5" / "MQL5" / "Files" / "TradingAI"


def prompt_for_source(default: Path) -> Path:
    raw = input(f"MT5 TradingAI root folder [{default}]: ").strip()
    return Path(raw).expanduser() if raw else default


def build_default_config_path() -> Path:
    return Path(__file__).resolve().with_name("tradingai_sync_config.json")


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        return {}
    with config_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    parser = argparse.ArgumentParser(description="Mirror MT5 TradingAI data into the repo.")
    parser.add_argument("--config", type=Path, default=build_default_config_path(), help="Config JSON file")
    parser.add_argument("--source", type=Path, default=None, help="MT5 TradingAI root folder")
    parser.add_argument("--dest", type=Path, default=None, help="Repo root folder (default: repo root)")
    parser.add_argument("--watch", action="store_true", help="Keep watching and syncing")
    parser.add_argument("--interval", type=float, default=None, help="Watch interval in seconds")
    args = parser.parse_args()

    config = load_config(args.config)

    # source: TradingAI folder in MT5
    source_root = args.source
    if source_root is None:
        source_root = config.get("mt5_root") or config.get("source_root")
        if source_root:
            source_root = Path(source_root).expanduser()
    if source_root is None:
        source_root = prompt_for_source(build_default_source())

    # dest: repo root
    dest_root = args.dest
    if dest_root is None:
        dest_root = config.get("dest_root")
        if dest_root:
            dest_root = Path(dest_root).expanduser()
    if dest_root is None:
        dest_root = REPO_ROOT

    interval = args.interval
    if interval is None and "watch_interval" in config:
        interval = float(config["watch_interval"])
    if interval is None:
        interval = 5.0

    delete_source = bool(config.get("delete_source_after_copy", True))

    if not args.watch:
        total = sync_all(source_root, dest_root, delete_source)
        print(f"done, processed {total} file(s)")
        return 0

    print(f"watching {source_root} -> {dest_root}")
    try:
        while True:
            total = sync_all(source_root, dest_root, delete_source)
            if total:
                print(f"synced {total} file(s)")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("stopped")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
