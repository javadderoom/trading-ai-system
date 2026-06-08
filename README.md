# TradingAI System

A **trading black box recorder** for MetaTrader 5 that captures raw market state, trade events, and synchronized chart screenshots for AI training.

Think flight recorder, not trading bot. The EA does not trade or analyze — it records. A Python pipeline turns the recordings into structured, AI-ready datasets.

---

## Architecture

```
MT5 market + trades
       ↓
EA (MQL5) captures:
  ├─ time snapshots (bid/ask/spread + bar times)
  ├─ trade events  (entry/exit deals)
  └─ chart screenshots (6 timeframes per symbol)
       ↓
Python pipeline:
  ├─ sync_mt5_logs.py   — mirrors data into repo
  ├─ parser.py          — groups deals → trade records with win/loss/RR
  ├─ linker.py          — validates screenshots, attaches context
  └─ dataset_builder.py — exports CSV + Parquet datasets
```

---

## Components

### 1. MT5 EA (`mt5/`)

An MQL5 Expert Advisor that logs time-based market snapshots and trade events as JSONL files, and captures multi-timeframe chart screenshots.

**Configurable inputs** (set in MT5):
| Input | Default | Description |
|---|---|---|
| `InpTimerSeconds` | 60 | Snapshot interval |
| `InpTimeSymbols` | XAUUSD,XAGUSD | Tracked symbols |
| `InpEnableTimeLogger` | true | Periodic market snapshots |
| `InpEnableTradeLogger` | true | Trade entry/exit logging |
| `InpEnableTimeScreenshots` | true | Chart captures on snapshots |
| `InpEnableTradeScreenshots` | true | Chart captures on trades |
| `InpEnableChartPreload` | true | Pre-open chart windows |
| `InpSyncToM5Open` | true | Align start to M5 candle |
| `InpScreenshotWidth/Height` | 1280x720 | Screenshot resolution |

**Output files** (in MT5 `Files/TradingAI/`):
- `time_events_YYYYMMDD.jsonl` — periodic bid/ask/spread/bar snapshots
- `trade_events_YYYYMMDD.jsonl` — individual deal records with phase (entry/exit)
- `screenshots/<symbol>/<tf>/*.png` — M1/M5/M15/H1/H4/D1 chart images

### 2. Python Pipeline (`python/`)

| Script | Purpose |
|---|---|
| `sync_mt5_logs.py` | Watch-mode sync of logs + screenshots from MT5 into `data/` and `screenshots/` |
| `sync_mt5_screenshots.py` | Watch-mode sync of PNG files only |
| `models.py` | Dataclasses: `TimeEvent`, `TradeEvent`, `TradeRecord`, `TrainingSample` |
| `parser.py` | Loads JSONL, groups deals by position ticket, computes win/loss/RR/duration |
| `linker.py` | Links screenshots to trades, finds pre/post entry context snapshots |
| `dataset_builder.py` | Assembles final training table, exports CSV + Parquet |

---

## Quick Start

### Prerequisites
- MetaTrader 5 (build 4000+)
- Python 3.10+

### 1. Install the EA

Copy the `mt5/MQL5/` tree into your MT5 terminal data directory:

```
<MT5_Data>\MQL5\Experts\TradingAI\TradingAI_Recorder.mq5
<MT5_Data>\MQL5\Include\TradingAI\*.mqh
```

Compile `TradingAI_Recorder.mq5` in MetaEditor, then attach it to a chart.

### 2. Sync data into the repo

```bash
# One-time sync
python python/sync_mt5_logs.py

# Or watch mode (continuous)
python python/sync_mt5_logs.py --watch
```

Configure the MT5 root path in `python/tradingai_sync_config.json` or set `TRADINGAI_MT5_ROOT` env var.

### 3. Build a dataset

```bash
pip install pandas pyarrow
python python/dataset_builder.py --data-dir data --screenshots-dir screenshots --output dataset
```

Outputs `dataset/tradingai_dataset.csv` and `dataset/tradingai_dataset.parquet`.

---

## Current Stage

**Stage 1 — Raw sensory capture** (complete)
- Time-synchronized market snapshots
- Trade event logging with entry/exit classification
- Multi-timeframe chart screenshots
- Dataset export pipeline

Stage 2 (planned): market structure detection, trade quality scoring, AI training sample generation.

---

## Project Structure

```
trading-ai-system/
├── mt5/
│   ├── MQL5/Experts/TradingAI/TradingAI_Recorder.mq5
│   └── MQL5/Include/TradingAI/
│       ├── TradingAI_ChartManager.mqh
│       ├── TradingAI_FileLogger.mqh
│       ├── TradingAI_Json.mqh
│       ├── TradingAI_Screenshot.mqh
│       ├── TradingAI_TimeEvent.mqh
│       └── TradingAI_TradeEvent.mqh
├── python/
│   ├── dataset_builder.py
│   ├── linker.py
│   ├── models.py
│   ├── parser.py
│   ├── sync_mt5_logs.py
│   ├── sync_mt5_screenshots.py
│   └── tradingai_sync_config.json
├── data/              # mirrored JSONL logs
├── screenshots/       # mirrored chart images
├── mt5_ea_system_review.md
├── python_dataset_builder.md
└── README.md
```

---

## License

Apache 2.0
