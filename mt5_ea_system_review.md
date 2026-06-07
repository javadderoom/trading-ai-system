# MT5 Trading AI EA System Review

## 1. High-Level Purpose

The EA is a market memory and event capture system for MT5.

It does not trade.
It does not analyze.
It records raw market state, trade events, and screenshots so a later AI layer can learn from them.

Think of it as a trading black box recorder.

---

## 2. Current System Flow

MT5 market + trades
        ↓
EA detects:
- time events
- trade events
- candle-open sync point
        ↓
EA writes:
- time JSONL logs
- trade JSONL logs
- per-symbol screenshot files
        ↓
Stored in:
`MQL5/Files/TradingAI/`
        ↓
Future:
Python dataset builder and AI layer

---

## 3. What Is Built Now

### 3.1 Time Logger

The EA writes periodic time snapshots in GMT.

Captured fields include:
- symbol
- GMT timestamp
- bid / ask
- spread
- `M1`, `M5`, `M15`, `H1`, `H4`, `D1` bar open times
- screenshot file references

Output file:
`MQL5/Files/TradingAI/time_events_YYYYMMDD.jsonl`

### 3.2 Trade Logger

The EA listens to `OnTradeTransaction` and logs each new deal.

Captured fields include:
- symbol
- deal ticket
- order ticket
- position ticket
- deal type
- deal entry phase
- price
- volume
- profit
- screenshot file references

Output file:
`MQL5/Files/TradingAI/trade_events_YYYYMMDD.jsonl`

### 3.3 Screenshot Layer

The EA opens or reuses charts and captures screenshots into per-symbol folders.

Folder layout:
`MQL5/Files/TradingAI/<symbol>/`

Screenshot behavior:
- time snapshots capture chart images for configured timeframes
- trade events capture chart images immediately on deal events
- `M1` and `M5` screenshots are gated on candle open, not mid-candle
- time screenshot filenames are minute-based, not second-based

### 3.4 Session Sync

The time and screenshot session waits for the next `M5` candle open before starting.

This keeps the dataset aligned to a clean market boundary.

Trade logging still happens immediately.

---

## 4. Timeframe Logic

Current screenshot / chart support:
- `M1`
- `M5`
- `M15`
- `H1`
- `H4`
- `D1`

Current timing behavior:
- `M1` screenshots: candle-open driven, effectively every 1 minute
- `M5` screenshots: candle-open driven, effectively every 5 minutes
- `M15` screenshots: about every 5 minutes
- `H1` screenshots: about every 15 minutes
- `H4` screenshots: about every 60 minutes
- `D1` screenshots: about every 6 hours

Note:
- `M1` and `M5` are candle-open driven
- the larger timeframes are elapsed-time driven

---

## 5. EA Controls

The EA now exposes switches so individual actions can be turned on or off:

- `InpEnableTimeLogger`
- `InpEnableTradeLogger`
- `InpEnableStartupState`
- `InpEnableTimeScreenshots`
- `InpEnableTradeScreenshots`
- `InpEnableChartPreload`
- `InpSyncToM5Open`

Other inputs:
- `InpTimerSeconds`
- `InpTimeSymbols`
- `InpScreenshotWidth`
- `InpScreenshotHeight`

---

## 6. Chart Management

Charts are opened once and reused.

This avoids repeatedly opening the same symbol/timeframe combination every time a screenshot is needed.

The EA currently manages:
- `M1`
- `M5`
- `M15`
- `H1`
- `H4`
- `D1`

---

## 7. Strengths So Far

### 1. Clean separation of event types

Time events and trade events are logged separately.

### 2. Better dataset alignment

GMT timestamps and the M5 sync gate make the logs easier to line up later.

### 3. Less noisy screenshots

Per-timeframe gates and per-symbol folders reduce clutter.

### 4. Easy future expansion

The EA is split into small include files rather than one giant MQL file.

---

## 8. Current Limitations

The system still does not:
- detect market structure
- score trade quality
- infer an edge
- generate live signals
- build AI-ready training samples yet

It is still a recorder first.

---

## 9. Main Weak Point

The data is still mostly raw.

That is fine for now, but the next layer must:
- link screenshots to events
- select meaningful market conditions
- build structured samples
- create labels or outcomes for learning

---

## 10. System Stage

This is now Stage 1:
raw sensory capture with synchronized time, trade, and chart evidence.

---

## 11. Next Step

Python dataset builder:
- reads JSONL logs
- matches screenshots to time and trade events
- builds training records
- prepares AI-ready inputs
