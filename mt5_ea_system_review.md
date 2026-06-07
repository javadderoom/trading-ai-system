# MT5 Trading AI EA – System Review

## 1. High-Level Purpose

Your EA is a multi-symbol, multi-timeframe market data capture system with trade linking.

It does NOT trade or analyze.
It only records market states and trades and connects them.

Think of it as a trading “black box recorder”.

---

## 2. Main Data Flow

MT5 Market + Trades
        ↓
EA detects:
- time events
- trade events
        ↓
Outputs:
- context screenshots
- entry/exit screenshots
- trade JSON logs
        ↓
Stored in:
MQL5/Files/TradingAI/
        ↓
Future: Python / AI layer

---

## 3. Screenshot System

### 3.1 Context Screenshots (Time-Based)

Symbols:
- XAUUSD
- XAGUSD

Timeframes:
- M5, M15, H1, H4, D1

Capture logic:
- M5 → ~2 min
- M15 → ~5 min
- H1 → ~15 min
- H4 → ~60 min
- D1 → ~6 hours

Purpose:
Build full market history across multiple timeframes.

---

### 3.2 Trade Screenshots

On trade entry:
- capture chart snapshot

On trade exit:
- capture chart snapshot

Purpose:
Freeze exact decision moments.

---

## 4. Trade Logging System

Triggered via OnTradeTransaction.

Captures:
- symbol
- price
- time
- phase (entry/exit)
- trade ID

Output example:

{
  "id": "XAUUSD_123456789",
  "symbol": "XAUUSD",
  "price": 2034.50,
  "time": "2026-06-07 12:00:00",
  "phase": "entry"
}

---

## 5. Chart Management System

- Charts are opened once at startup
- Reused for all screenshots
- Prevents lag from repeated opening

Symbols + TFs are preloaded.

---

## 6. Timing Engine

Each timeframe has its own capture interval:

- M5 → 120 sec
- M15 → 300 sec
- H1 → 900 sec
- H4 → 3600 sec
- D1 → 21600 sec

EA checks every 60 seconds and only captures when due.

---

## 7. What the System Achieves

### 1. Market Memory
You can reconstruct historical chart states.

### 2. Multi-Timeframe Alignment
Compare M5 → D1 at same timestamp.

### 3. Trade Context Linking
Each trade is tied to entry/exit visuals.

### 4. Cross-Asset Dataset Foundation
XAUUSD and XAGUSD are synchronized.

---

## 8. Limitations

Current system does NOT:
- detect market structure (BOS, liquidity)
- evaluate trades
- generate signals
- filter meaningful events
- interpret data

It only records raw data.

---

## 9. Main Weak Point

Dataset is dense but not selective.
Many screenshots are not “important events”.

---

## 10. System Stage

This is Stage 1:
“Raw sensory system”

No intelligence yet, only perception + memory.

---

## 11. Next Step

Python dataset builder:
- links screenshots to trades
- creates structured dataset
- prepares AI-ready inputs
