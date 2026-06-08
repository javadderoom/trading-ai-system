# Python Dataset Builder

## Purpose

Turn raw MT5 EA logs and screenshots into a structured dataset that can be loaded in pandas and used for AI training.

The EA writes the raw material.
Python turns it into usable samples.

---

## Input Sources

From the MT5 EA:
- `time_events_YYYYMMDD.jsonl`
- `trade_events_YYYYMMDD.jsonl`
- per-symbol screenshot folders under `MQL5/Files/TradingAI/screenshots/<symbol>/<tf>/`

---

## Main Scripts

All scripts live under `python/` and are run from the repo root.

### 1. File Sync / Watcher

Two scripts mirror MT5 output into the repo:

- **`python/sync_mt5_logs.py`** — syncs both JSONL logs and screenshots from the MT5 `TradingAI/` folder into `data/` and `screenshots/`. Supports `--watch` mode with configurable interval.
- **`python/sync_mt5_screenshots.py`** — syncs only PNG screenshot files. Supports `--watch` mode.

Both scripts read defaults from `python/tradingai_sync_config.json` and respect the `--source`, `--dest`, and `TRADINGAI_MT5_ROOT` / `TRADINGAI_MT5_SCREENSHOT_ROOT` env vars. Source files are deleted after successful copy by default.

### 2. Trade Parser

Reads trade JSONL records and normalizes them into a trade-centric structure.

Responsibilities:
- parse trade entry and exit events
- group related fills into a single trade record
- keep stable trade IDs
- compute trade result fields

### 3. Screenshot Linker

Matches screenshots to trades and time events.

Responsibilities:
- link entry screenshots
- link exit screenshots
- link nearby time snapshots
- validate that every trade has required images

### 4. Dataset Builder

Combines parsed trades and linked screenshots into a final training table.

Responsibilities:
- emit a pandas-friendly table
- export to CSV, Parquet, or JSONL
- validate missing links
- surface bad records loudly

---

## Target Output

Example structured record:

```json
{
  "trade_id": "123",
  "symbol": "EURUSD",
  "tf": "M15",
  "entry_img": "...",
  "exit_img": "...",
  "result": "win",
  "rr": 2.0
}
```

---

## Required Guarantees

- the dataset must load cleanly in pandas
- every trade must have matching images
- no missing links should be silently ignored
- file paths must stay stable and reproducible

---

## Folder Layout

```text
python/
  __init__.py
  models.py              # data classes: TimeEvent, TradeEvent, TradeRecord, TrainingSample
  parser.py              # loads JSONL logs, groups deals into TradeRecords
  linker.py              # validates screenshots, finds pre/post context snapshots
  dataset_builder.py     # combines trades + screenshots into pandas DataFrame, exports CSV + Parquet
  sync_mt5_logs.py       # watches & mirrors MT5 logs + screenshots into repo
  sync_mt5_screenshots.py  # watches & mirrors MT5 PNG files only
  tradingai_sync_config.json  # default source/dest paths, watch interval
  requirements.txt       # pandas, pyarrow

data/                    # mirrored JSONL logs land here
  time_events_YYYYMMDD.jsonl
  trade_events_YYYYMMDD.jsonl

screenshots/             # mirrored screenshots land here (6 timeframes per symbol)
  XAUUSD/
    M1/
    M5/
    M15/
    H1/
    H4/
    D1/
  XAGUSD/
    M1/
    M5/
    M15/
    H1/
    H4/
    D1/
```

---

## Design Rules

- Keep the dataset trade-centric.
- Fail loudly when assets are missing.
- Normalize timestamps early.
- Store paths, not embedded binaries, in the dataset table.
- Keep the mapping from trade IDs to image files deterministic.

---

## Status

All Python scripts are implemented:
- `sync_mt5_logs.py` / `sync_mt5_screenshots.py` — file sync with watch mode
- `parser.py` — loads JSONL, groups deals into trade records with win/loss/RR
- `linker.py` — validates screenshots, attaches pre/post context snapshots
- `dataset_builder.py` — builds CSV + Parquet dataset from parsed data

Run the full pipeline:
```bash
python python/dataset_builder.py --data-dir data --screenshots-dir screenshots --output dataset
```
