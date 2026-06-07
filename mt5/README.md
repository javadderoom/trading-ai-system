# TradingAI MT5 Scaffold

This folder contains the first MT5 component of the trading AI system: a small EA with two loggers:

- a time-based logger
- a trade-based logger
- a screenshot layer tied to both event streams

## Layout

- `MQL5/Experts/TradingAI/TradingAI_Recorder.mq5`
- `MQL5/Include/TradingAI/TradingAI_FileLogger.mqh`
- `MQL5/Include/TradingAI/TradingAI_ChartManager.mqh`
- `MQL5/Include/TradingAI/TradingAI_Screenshot.mqh`
- `MQL5/Include/TradingAI/TradingAI_TimeEvent.mqh`
- `MQL5/Include/TradingAI/TradingAI_TradeEvent.mqh`
- `MQL5/Include/TradingAI/TradingAI_Json.mqh`

## What it does

- Time logger:
  - Runs on a timer
  - Captures periodic market snapshots for the configured symbols
  - Writes one JSON line per snapshot into `MQL5/Files/TradingAI/time_events_YYYYMMDD.jsonl`
  - Writes a startup record when the EA initializes
- Screenshot layer:
  - Opens or reuses charts for the configured symbols and core timeframes, including `M1`
  - Captures PNG screenshots for each time snapshot and trade event
  - Writes per-symbol PNG files into `MQL5/Files/TradingAI/<symbol>/`
  - Time snapshot filenames are minute-based, not second-based
  - Stores screenshot filenames in the JSON logs
- Trade logger:
  - Watches `OnTradeTransaction`
  - Captures new deals
  - Classifies each deal as `entry`, `exit`, or `unknown`
  - Writes one JSON line per deal into `MQL5/Files/TradingAI/trade_events_YYYYMMDD.jsonl`

## Notes

- The EA is intentionally small and split into includes, so we can add screenshots, chart context, and AI-export layers later without turning it into one large MQL file.
- EA inputs let you enable or disable each action independently:
  - `InpEnableTimeLogger`
  - `InpEnableTradeLogger`
  - `InpEnableStartupState`
  - `InpEnableTimeScreenshots`
  - `InpEnableTradeScreenshots`
  - `InpEnableChartPreload`
  - `InpSyncToM5Open`
- The timer interval and tracked symbols are configurable via EA inputs.
- When `InpSyncToM5Open` is enabled, the time logger and screenshot session waits for the next `M5` candle open before starting.
- Trade events are still logged immediately; only the time/screenshot session is held for the sync point.
- MT5 will only find these headers if you place this tree inside the terminal data directory, for example:
  - `...\MetaQuotes\Terminal\<profile>\MQL5\Experts\TradingAI\TradingAI_Recorder.mq5`
  - `...\MetaQuotes\Terminal\<profile>\MQL5\Include\TradingAI\TradingAI_Json.mqh`
  - `...\MetaQuotes\Terminal\<profile>\MQL5\Include\TradingAI\TradingAI_FileLogger.mqh`
  - `...\MetaQuotes\Terminal\<profile>\MQL5\Include\TradingAI\TradingAI_TimeEvent.mqh`
  - `...\MetaQuotes\Terminal\<profile>\MQL5\Include\TradingAI\TradingAI_TradeEvent.mqh`
- Then compile `TradingAI_Recorder.mq5` from MetaEditor, not from the git repo folder.
