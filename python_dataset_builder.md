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

### 1. File Watcher

Continuously watches the MT5 output folder and detects:
- new JSONL lines
- new screenshot files

Responsibilities:
- track new files safely
- avoid duplicate processing
- keep an index of processed records

Helper script:
- `python/sync_mt5_screenshots.py` mirrors MT5 screenshot files into the repo `screenshots/` folder
- use `--source` or `TRADINGAI_MT5_SCREENSHOT_ROOT` to point at the MT5 data folder
- `python/tradingai_sync_config.json` can store the default source, destination, and watch interval
- the sync helper deletes source screenshots after a successful copy by default

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

## Suggested Folder Layout

```text
python/
  watcher.py
  parser.py
  linker.py
  dataset_builder.py
  config.py
  models.py
  sync_mt5_screenshots.py

screenshots/
  XAUUSD/
    M5/
    M15/
    H1/
  XAGUSD/
    M5/
    M15/
    H1/
```

---

## Design Rules

- Keep the dataset trade-centric.
- Fail loudly when assets are missing.
- Normalize timestamps early.
- Store paths, not embedded binaries, in the dataset table.
- Keep the mapping from trade IDs to image files deterministic.

---

## Next Step

Implement the Python pipeline in small pieces:
- watcher first
- parser second
- linker third
- dataset builder last
