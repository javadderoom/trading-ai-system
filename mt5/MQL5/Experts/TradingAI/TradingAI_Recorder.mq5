#property strict
#property version   "1.0"
#property description "TradingAI recorder EA - logs time snapshots and trade entries/exits into JSONL files."

#include <TradingAI/TradingAI_FileLogger.mqh>
#include <TradingAI/TradingAI_Screenshot.mqh>
#include <TradingAI/TradingAI_TimeEvent.mqh>
#include <TradingAI/TradingAI_TradeEvent.mqh>

input int    InpTimerSeconds = 60;
input string  InpTimeSymbols = "XAUUSD,XAGUSD";
input bool   InpEnableTimeLogger = true;
input bool   InpEnableTradeLogger = true;
input bool   InpEnableStartupState = true;
input bool   InpEnableTimeScreenshots = true;
input bool   InpEnableTradeScreenshots = true;
input bool   InpEnableChartPreload = true;
input bool   InpSyncToM5Open = true;
input int    InpScreenshotWidth = 1280;
input int    InpScreenshotHeight = 720;

CTradingAIFileLogger g_time_logger;
CTradingAIFileLogger g_trade_logger;
TradingAI_ChartSlot g_chart_slots[];
string g_symbols[];
string g_sync_symbol = "";
bool g_session_started = false;
datetime g_m5_sync_open_time = 0;

void LogStartupState(const int timer_seconds)
{
   if(!InpEnableStartupState || !InpEnableTimeLogger)
      return;

   string line = "{";
   line += "\"event_type\":\"startup\",";
   line += "\"time_utc\":" + TradingAI_JsonString(TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS)) + ",";
   line += "\"timer_seconds\":" + IntegerToString(timer_seconds) + ",";
   line += "\"symbols\":" + TradingAI_JsonString(InpTimeSymbols) + ",";
   line += "\"symbols_count\":" + IntegerToString(ArraySize(g_symbols));
   line += "}";

   if(!g_time_logger.AppendJsonLine("time_events", line))
      Print("TradingAI: failed to write startup state");
}

bool TradingAI_IsM5SyncReady()
{
   if(!InpSyncToM5Open)
      return true;

   string anchor_symbol = "";
   datetime current_m5_open = 0;

   for(int index = 0; index < ArraySize(g_symbols); index++)
   {
      string symbol = g_symbols[index];
      if(symbol == "")
         continue;

      if(!SymbolSelect(symbol, true))
         continue;

      datetime symbol_m5_open = iTime(symbol, PERIOD_M5, 0);
      if(symbol_m5_open <= 0)
         continue;

      anchor_symbol = symbol;
      current_m5_open = symbol_m5_open;
      break;
   }

   if(anchor_symbol == "")
      return true;

   if(g_sync_symbol != anchor_symbol || g_m5_sync_open_time <= 0)
   {
      g_sync_symbol = anchor_symbol;
      g_m5_sync_open_time = current_m5_open;
      return false;
   }

   if(current_m5_open == g_m5_sync_open_time)
      return false;

   g_m5_sync_open_time = current_m5_open;
   return true;
}

int OnInit()
{
   if(InpEnableTimeLogger)
   {
      if(!g_time_logger.Init("TradingAI"))
         return INIT_FAILED;
   }

   if(InpEnableTradeLogger)
   {
      if(!g_trade_logger.Init("TradingAI"))
         return INIT_FAILED;
   }

   ArrayResize(g_symbols, 0);
   int symbol_count = StringSplit(InpTimeSymbols, ',', g_symbols);
   for(int index = 0; index < symbol_count; index++)
      StringReplace(g_symbols[index], " ", "");

   ArrayResize(g_chart_slots, 0);
   if((InpEnableTimeScreenshots || InpEnableTradeScreenshots) && InpEnableChartPreload)
   {
      for(int index = 0; index < ArraySize(g_symbols); index++)
      {
         string symbol = g_symbols[index];
         if(symbol == "")
            continue;

         if(!TradingAI_EnsureManagedChartsForSymbol(symbol, g_chart_slots))
            PrintFormat("TradingAI: some screenshots could not be initialized for %s", symbol);
      }
   }

   int timer_seconds = InpTimerSeconds;
   if(timer_seconds < 1)
      timer_seconds = 60;

   if(!EventSetTimer(timer_seconds))
   {
      PrintFormat("TradingAI: EventSetTimer failed (error %d)", GetLastError());
      return INIT_FAILED;
   }

   PrintFormat("TradingAI recorder initialized. timer=%d symbols=%s time_log=%d trade_log=%d time_shots=%d trade_shots=%d preload=%d",
               timer_seconds,
               InpTimeSymbols,
               InpEnableTimeLogger,
               InpEnableTradeLogger,
               InpEnableTimeScreenshots,
               InpEnableTradeScreenshots,
               InpEnableChartPreload);
   PrintFormat("TradingAI sync gate: m5_open=%d", InpSyncToM5Open);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if((InpEnableTimeScreenshots || InpEnableTradeScreenshots) && InpEnableChartPreload)
      TradingAI_CloseManagedCharts(g_chart_slots);

   EventKillTimer();
   PrintFormat("TradingAI recorder stopped. reason=%d", reason);
}

void LogTimeSnapshots()
{
   if(!g_session_started)
      return;

   for(int index = 0; index < ArraySize(g_symbols); index++)
   {
      string symbol = g_symbols[index];
      if(symbol == "")
         continue;

      TradingAI_TimeEvent event;
      ZeroMemory(event);

      if(!TradingAI_BuildTimeEvent(symbol, event))
      {
         PrintFormat("TradingAI: unable to capture time snapshot for %s", symbol);
         continue;
      }

      if(InpEnableTimeScreenshots)
         TradingAI_CaptureDueScreenshotsForSymbol(symbol, "TS", event.snapshot_id, InpScreenshotWidth, InpScreenshotHeight, event.screenshots, g_chart_slots);

      if(InpEnableTimeLogger)
      {
         string line = TradingAI_BuildTimeEventJson(event);
         if(!g_time_logger.AppendJsonLine("time_events", line))
            PrintFormat("TradingAI: failed to write time snapshot for %s", symbol);
      }
   }
}

void OnTimer()
{
   if(!g_session_started)
   {
      if(!TradingAI_IsM5SyncReady())
         return;

      g_session_started = true;
      LogStartupState(InpTimerSeconds < 1 ? 60 : InpTimerSeconds);
   }

   LogTimeSnapshots();
}

TradingAI_TradePhase ResolvePhaseFromDealEntry(const ENUM_DEAL_ENTRY entry)
{
   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
      return TRADE_PHASE_ENTRY;

   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      return TRADE_PHASE_EXIT;

   return TRADE_PHASE_UNKNOWN;
}

bool BuildTradeEventFromDeal(const ulong deal_ticket, TradingAI_TradeEvent &event)
{
   if(!HistoryDealSelect(deal_ticket))
      return false;

   string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
   ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   int symbol_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   TradingAI_TradePhase phase = ResolvePhaseFromDealEntry(deal_entry);

   if(symbol_digits <= 0)
      symbol_digits = 8;

   event.event_id = symbol + "_" + StringFormat("%I64u", deal_ticket);
   event.symbol = symbol;
   event.comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
   event.event_type = "trade_event";
   if(phase == TRADE_PHASE_UNKNOWN)
      return false;

   event.phase = TradingAI_TradePhaseToString(phase);
   event.deal_type = TradingAI_DealTypeToString(deal_type);
   event.deal_entry = TradingAI_DealEntryToString(deal_entry);
   event.time_utc = TimeToString(deal_time, TIME_DATE | TIME_SECONDS);
   event.deal_ticket = (long)deal_ticket;
   event.order_ticket = (long)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
   event.position_ticket = (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   event.magic = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
   event.price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   event.price_digits = symbol_digits;
   event.volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
   event.profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);

   return true;
}

void LogTradeDeal(const ulong deal_ticket)
{
   TradingAI_TradeEvent event;
   ZeroMemory(event);

   if(!BuildTradeEventFromDeal(deal_ticket, event))
   {
      PrintFormat("TradingAI: unable to read deal %I64u", deal_ticket);
      return;
   }

   if(g_session_started && InpEnableTradeScreenshots)
      TradingAI_CaptureScreenshotsForSymbol(event.symbol, "TR", event.event_id, InpScreenshotWidth, InpScreenshotHeight, event.screenshots, g_chart_slots);

   if(InpEnableTradeLogger)
   {
      string line = TradingAI_BuildTradeEventJson(event);
      if(!g_trade_logger.AppendJsonLine("trade_events", line))
         PrintFormat("TradingAI: failed to write deal %I64u", deal_ticket);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(trans.deal == 0)
      return;

   LogTradeDeal(trans.deal);
}
