#ifndef TRADINGAI_CHARTMANAGER_MQH
#define TRADINGAI_CHARTMANAGER_MQH

struct TradingAI_ChartSlot
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   long   chart_id;
   bool   opened_by_ea;
   datetime last_time_capture_gmt;
   datetime last_bar_open_time;
};

string TradingAI_FormatFileTimestamp(const datetime value)
{
   MqlDateTime stamp;
   TimeToStruct(value, stamp);
   return StringFormat("%04d-%02d-%02d_%02d-%02d", stamp.year, stamp.mon, stamp.day, stamp.hour, stamp.min);
}

string TradingAI_ClampScreenshotName(string name)
{
   const int max_len = 63;
   const string ext = ".png";

   if(StringLen(name) <= max_len)
      return name;

   int keep_len = max_len - StringLen(ext);
   if(keep_len < 1)
      return ext;

   return StringSubstr(name, 0, keep_len) + ext;
}

string TradingAI_TimeframeToShortName(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M15:
         return "M15";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H4:
         return "H4";
      case PERIOD_D1:
         return "D1";
      default:
         return StringSubstr(EnumToString(timeframe), 7);
   }
}

bool TradingAI_FindOpenChart(const string symbol, const ENUM_TIMEFRAMES timeframe, long &chart_id)
{
   long chart = ChartFirst();

   while(chart >= 0)
   {
      if(ChartSymbol(chart) == symbol && ChartPeriod(chart) == timeframe)
      {
         chart_id = chart;
         return true;
      }

      chart = ChartNext(chart);
   }

   chart_id = 0;
   return false;
}

void TradingAI_ApplyChartStyle(const long chart_id)
{
   ChartSetInteger(chart_id, CHART_AUTOSCROLL, false);
   ChartSetInteger(chart_id, CHART_SHIFT, true);
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);
   ChartRedraw(chart_id);
}

bool TradingAI_OpenOrReuseChart(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                long &chart_id,
                                bool &opened_by_ea)
{
   if(TradingAI_FindOpenChart(symbol, timeframe, chart_id))
   {
      opened_by_ea = false;
      TradingAI_ApplyChartStyle(chart_id);
      return true;
   }

   ResetLastError();
   chart_id = ChartOpen(symbol, timeframe);
   if(chart_id == 0)
   {
      PrintFormat("TradingAI: ChartOpen failed for %s %s (error %d)",
                  symbol, TradingAI_TimeframeToShortName(timeframe), GetLastError());
      opened_by_ea = false;
      return false;
   }

   opened_by_ea = true;
   TradingAI_ApplyChartStyle(chart_id);
   return true;
}

bool TradingAI_EnsureManagedChart(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  TradingAI_ChartSlot &slot)
{
   long chart_id = 0;
   bool opened_by_ea = false;

   if(!SymbolSelect(symbol, true))
      return false;

   if(!TradingAI_OpenOrReuseChart(symbol, timeframe, chart_id, opened_by_ea))
      return false;

   slot.symbol = symbol;
   slot.timeframe = timeframe;
   slot.chart_id = chart_id;
   slot.opened_by_ea = opened_by_ea;
   if(slot.last_time_capture_gmt < 0)
      slot.last_time_capture_gmt = 0;
   if(timeframe == PERIOD_M1 || timeframe == PERIOD_M5)
      slot.last_bar_open_time = iTime(symbol, timeframe, 0);
   else if(slot.last_bar_open_time < 0)
      slot.last_bar_open_time = 0;
   return true;
}

bool TradingAI_EnsureFolder(const string path)
{
   if(path == "")
      return true;

   if(FolderCreate(path))
      return true;

   int error_code = GetLastError();
   if(error_code != 0)
      PrintFormat("TradingAI: folder create returned false for %s (error %d)", path, error_code);

   return true;
}

bool TradingAI_FindManagedChartIndex(const string symbol, const ENUM_TIMEFRAMES timeframe, TradingAI_ChartSlot &slots[], int &index_out)
{
   for(int index = 0; index < ArraySize(slots); index++)
   {
      if(slots[index].symbol == symbol && slots[index].timeframe == timeframe)
      {
         index_out = index;
         return true;
      }
   }

   index_out = -1;
   return false;
}

bool TradingAI_EnsureManagedChartsForSymbol(const string symbol, TradingAI_ChartSlot &slots[])
{
   const ENUM_TIMEFRAMES timeframes[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};

   for(int index = 0; index < 6; index++)
   {
      int slot_index = -1;
      if(TradingAI_FindManagedChartIndex(symbol, timeframes[index], slots, slot_index))
         continue;

      int new_size = ArraySize(slots) + 1;
      ArrayResize(slots, new_size);
      slots[new_size - 1].last_time_capture_gmt = 0;

      if(!TradingAI_EnsureManagedChart(symbol, timeframes[index], slots[new_size - 1]))
         return false;
   }

   return true;
}

void TradingAI_CloseManagedCharts(TradingAI_ChartSlot &slots[])
{
   for(int index = 0; index < ArraySize(slots); index++)
   {
      if(slots[index].opened_by_ea && slots[index].chart_id > 0)
         ChartClose(slots[index].chart_id);
   }
}

bool TradingAI_GetManagedChartId(const string symbol,
                                 const ENUM_TIMEFRAMES timeframe,
                                 TradingAI_ChartSlot &slots[],
                                 long &chart_id_out)
{
   int slot_index = -1;
   if(!TradingAI_FindManagedChartIndex(symbol, timeframe, slots, slot_index))
   {
      chart_id_out = 0;
      return false;
   }

   chart_id_out = slots[slot_index].chart_id;
   return chart_id_out > 0;
}

int TradingAI_TimeframeCaptureIntervalSeconds(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:
         return 60;
      case PERIOD_M5:
         return 120;
      case PERIOD_M15:
         return 300;
      case PERIOD_H1:
         return 900;
      case PERIOD_H4:
         return 3600;
      case PERIOD_D1:
         return 21600;
      default:
         return 300;
   }
}

string TradingAI_QuoteFolderName(const string symbol)
{
   return "TradingAI\\" + symbol;
}

string TradingAI_ScreenshotRootFolder()
{
   return "TradingAI\\screenshots";
}

string TradingAI_ScreenshotSymbolFolder(const string symbol)
{
   return TradingAI_ScreenshotRootFolder() + "\\" + symbol;
}

string TradingAI_ScreenshotTimeframeFolder(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   return TradingAI_ScreenshotSymbolFolder(symbol) + "\\" + TradingAI_TimeframeToShortName(timeframe);
}

string TradingAI_ScreenshotRelativeFolder(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   return "screenshots/" + symbol + "/" + TradingAI_TimeframeToShortName(timeframe);
}

bool TradingAI_EnsureScreenshotFolders(const string symbol)
{
   if(!TradingAI_EnsureFolder("TradingAI"))
      return false;

   if(!TradingAI_EnsureFolder(TradingAI_ScreenshotRootFolder()))
      return false;

   if(!TradingAI_EnsureFolder(TradingAI_ScreenshotSymbolFolder(symbol)))
      return false;

   return true;
}

bool TradingAI_EnsureScreenshotFoldersForTimeframe(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   if(!TradingAI_EnsureScreenshotFolders(symbol))
      return false;

   return TradingAI_EnsureFolder(TradingAI_ScreenshotTimeframeFolder(symbol, timeframe));
}

bool TradingAI_ShouldCaptureTimeframeNow(TradingAI_ChartSlot &slot, const datetime now_gmt)
{
   if(slot.timeframe == PERIOD_M1 || slot.timeframe == PERIOD_M5)
   {
      datetime current_bar_open = iTime(slot.symbol, slot.timeframe, 0);
      if(current_bar_open <= 0)
         return false;

      if(slot.last_bar_open_time <= 0)
      {
         slot.last_bar_open_time = current_bar_open;
         return true;
      }

      if(current_bar_open == slot.last_bar_open_time)
         return false;

      slot.last_bar_open_time = current_bar_open;
      return true;
   }

   int interval_seconds = TradingAI_TimeframeCaptureIntervalSeconds(slot.timeframe);
   if(interval_seconds <= 0)
      return true;

   if(slot.last_time_capture_gmt <= 0)
   {
      slot.last_time_capture_gmt = now_gmt;
      return true;
   }

   if((now_gmt - slot.last_time_capture_gmt) < interval_seconds)
      return false;

   slot.last_time_capture_gmt = now_gmt;
   return true;
}

string TradingAI_TimeframeScreenshotSubpath(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            const string prefix,
                                            const string event_tag)
{
   string file_name = StringFormat("TradingAI_%s_%s_%s.png",
                                   prefix,
                                   TradingAI_TimeframeToShortName(timeframe),
                                   symbol + "_" + event_tag);

   return TradingAI_QuoteFolderName(symbol) + "\\" + TradingAI_ClampScreenshotName(file_name);
}

#endif
