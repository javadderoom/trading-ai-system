#!/usr/bin/env python3
"""Mirror MT5 screenshot files into the repo screenshots folder.

Expected source layout from the EA:
    TradingAI/screenshots/<symbol>/<timeframe>/<file>.png

Expected repo layout:
    screenshots/<symbol>/<timeframe>/<file>.png
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import time
from pathlib import Path


def is_png(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() == ".png"


def sync_once(source_root: Path, dest_root: Path, delete_source_after_copy: bool) -> int:
    copied = 0

    if not source_root.exists():
        print(f"source folder not found: {source_root}")
        return 0

    for src in source_root.rglob("*.png"):
        if not is_png(src):
            continue

        rel_path = src.relative_to(source_root)
        dest = dest_root / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)

        if dest.exists():
            src_stat = src.stat()
            dest_stat = dest.stat()
            if src_stat.st_size == dest_stat.st_size and int(src_stat.st_mtime) == int(dest_stat.st_mtime):
                continue

        shutil.copy2(src, dest)
        if delete_source_after_copy:
            src.unlink()
        copied += 1
        action = "moved" if delete_source_after_copy else "copied"
        print(f"{action} {rel_path.as_posix()}")

    return copied


def build_default_source() -> Path:
    env_source = os.environ.get("TRADINGAI_MT5_SCREENSHOT_ROOT")
    if env_source:
        return Path(env_source)

    # Default assumes this script lives in <repo>/python/
    repo_root = Path(__file__).resolve().parents[1]
    return repo_root / "mt5" / "MQL5" / "Files" / "TradingAI" / "screenshots"


def prompt_for_source(default_source: Path) -> Path:
    raw_value = input(f"MT5 screenshot source [{default_source}]: ").strip()
    if not raw_value:
        return default_source

    return Path(raw_value).expanduser()


def build_default_dest() -> Path:
    repo_root = Path(__file__).resolve().parents[1]
    return repo_root / "screenshots"


def build_default_config_path() -> Path:
    return Path(__file__).resolve().with_name("tradingai_sync_config.json")


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        return {}

    with config_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    parser = argparse.ArgumentParser(description="Mirror MT5 TradingAI screenshots into the repo.")
    parser.add_argument("--config", type=Path, default=build_default_config_path(), help="Config JSON file")
    parser.add_argument("--source", type=Path, default=None, help="MT5 screenshot root folder")
    parser.add_argument("--dest", type=Path, default=None, help="Repo screenshots folder")
    parser.add_argument("--watch", action="store_true", help="Keep watching and syncing")
    parser.add_argument("--interval", type=float, default=None, help="Watch interval in seconds")
    args = parser.parse_args()

    config = load_config(args.config)

    source_root = args.source
    if source_root is None and "source_root" in config:
        source_root = Path(config["source_root"]).expanduser()
    if source_root is None:
        source_root = prompt_for_source(build_default_source())

    dest_root = args.dest
    if dest_root is None and "dest_root" in config:
        dest_root = Path(config["dest_root"]).expanduser()
    if dest_root is None:
        dest_root = build_default_dest()

    interval = args.interval
    if interval is None and "watch_interval" in config:
        interval = float(config["watch_interval"])
    if interval is None:
        interval = 5.0

    delete_source_after_copy = bool(config.get("delete_source_after_copy", True))

    dest_root.mkdir(parents=True, exist_ok=True)

    if not args.watch:
        copied = sync_once(source_root, dest_root, delete_source_after_copy)
        print(f"done, processed {copied} file(s)")
        return 0

    print(f"watching {source_root} -> {dest_root}")
    try:
        while True:
            copied = sync_once(source_root, dest_root, delete_source_after_copy)
            if copied:
                print(f"synced {copied} file(s)")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("stopped")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
