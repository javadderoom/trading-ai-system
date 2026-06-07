#ifndef TRADINGAI_SCREENSHOT_MQH
#define TRADINGAI_SCREENSHOT_MQH

#include <TradingAI/TradingAI_ChartManager.mqh>

string TradingAI_BuildScreenshotName(const string prefix,
                                     const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     const string event_tag,
                                     const bool include_symbol = false)
{
   string file_stamp = event_tag;
   string file_name = "";

   if(prefix == "TR")
   {
      file_name = StringFormat("%s_%s.png", prefix, file_stamp);
   }
   else
   {
      file_name = StringFormat("%s.png", file_stamp);
   }

   return TradingAI_ClampScreenshotName(file_name);
}

string TradingAI_BuildScreenshotPath(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     const string prefix,
                                     const string event_tag)
{
   return TradingAI_ScreenshotTimeframeFolder(symbol, timeframe) + "\\" +
          TradingAI_BuildScreenshotName(prefix, symbol, timeframe, event_tag);
}

bool TradingAI_EnsureScreenshotFolderForSymbol(const string symbol)
{
   return TradingAI_EnsureScreenshotFolders(symbol);
}

bool TradingAI_CaptureChartScreenshot(const long chart_id,
                                      const string file_name,
                                      const int width,
                                      const int height)
{
   if(chart_id <= 0)
      return false;

   ChartRedraw(chart_id);
   if(!ChartScreenShot(chart_id, file_name, width, height, ALIGN_RIGHT))
   {
      PrintFormat("TradingAI: ChartScreenShot failed for %s (error %d)", file_name, GetLastError());
      return false;
   }

   return true;
}

bool TradingAI_CaptureScreenshotsForSymbol(const string symbol,
                                           const string prefix,
                                           const string event_tag,
                                           const int width,
                                           const int height,
                                           string &manifest,
                                           TradingAI_ChartSlot &slots[])
{
   const ENUM_TIMEFRAMES timeframes[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   manifest = "";

   if(!TradingAI_EnsureManagedChartsForSymbol(symbol, slots))
      return false;

   if(!TradingAI_EnsureScreenshotFolders(symbol))
      return false;

   for(int index = 0; index < 6; index++)
   {
      long chart_id = 0;
      if(!TradingAI_GetManagedChartId(symbol, timeframes[index], slots, chart_id))
         continue;

      if(!TradingAI_EnsureScreenshotFoldersForTimeframe(symbol, timeframes[index]))
         continue;

      string file_path = TradingAI_BuildScreenshotPath(symbol, timeframes[index], prefix, event_tag);
      if(TradingAI_CaptureChartScreenshot(chart_id, file_path, width, height))
      {
         if(manifest != "")
            manifest += "|";
         manifest += TradingAI_ScreenshotRelativeFolder(symbol, timeframes[index]) + "/" +
                     TradingAI_BuildScreenshotName(prefix, symbol, timeframes[index], event_tag);
      }
   }

   return manifest != "";
}

bool TradingAI_CaptureDueScreenshotsForSymbol(const string symbol,
                                              const string prefix,
                                              const string event_tag,
                                              const int width,
                                              const int height,
                                              string &manifest,
                                              TradingAI_ChartSlot &slots[])
{
   const ENUM_TIMEFRAMES timeframes[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   manifest = "";

   if(!TradingAI_EnsureManagedChartsForSymbol(symbol, slots))
      return false;

   if(!TradingAI_EnsureScreenshotFolders(symbol))
      return false;

   datetime now_gmt = TimeGMT();

   for(int index = 0; index < 6; index++)
   {
      int slot_index = -1;
      if(!TradingAI_FindManagedChartIndex(symbol, timeframes[index], slots, slot_index))
         continue;

      if(!TradingAI_ShouldCaptureTimeframeNow(slots[slot_index], now_gmt))
         continue;

      if(!TradingAI_EnsureScreenshotFoldersForTimeframe(symbol, timeframes[index]))
         continue;

      long chart_id = slots[slot_index].chart_id;
      string file_path = TradingAI_BuildScreenshotPath(symbol, timeframes[index], prefix, event_tag);
      if(TradingAI_CaptureChartScreenshot(chart_id, file_path, width, height))
      {
         if(manifest != "")
            manifest += "|";
         manifest += TradingAI_ScreenshotRelativeFolder(symbol, timeframes[index]) + "/" +
                     TradingAI_BuildScreenshotName(prefix, symbol, timeframes[index], event_tag);
      }
   }

   return manifest != "";
}

#endif
