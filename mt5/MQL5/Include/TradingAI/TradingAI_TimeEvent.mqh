#ifndef TRADINGAI_TIMEEVENT_MQH
#define TRADINGAI_TIMEEVENT_MQH

#include <TradingAI/TradingAI_Json.mqh>

struct TradingAI_TimeEvent
{
   string event_type;
   string snapshot_id;
   string file_stamp;
   string symbol;
   string time_utc;
   string screenshots;
   int    digits;
   double bid;
   double ask;
   long   spread_points;
   string  bar_m5;
   string  bar_m1;
   string  bar_m15;
   string  bar_h1;
   string  bar_h4;
   string  bar_d1;
};

string TradingAI_FormatCompactTime(const datetime value)
{
   MqlDateTime stamp;
   TimeToStruct(value, stamp);
   return StringFormat("%04d%02d%02d_%02d%02d%02d", stamp.year, stamp.mon, stamp.day, stamp.hour, stamp.min, stamp.sec);
}

string TradingAI_BarTimeToString(const string symbol, const ENUM_TIMEFRAMES period)
{
   datetime bar_time = iTime(symbol, period, 0);
   if(bar_time <= 0)
      return "";

   return TimeToString(bar_time, TIME_DATE | TIME_SECONDS);
}

string TradingAI_BuildTimeEventJson(const TradingAI_TimeEvent &event)
{
   string json = "{";
   json += "\"event_type\":" + TradingAI_JsonString(event.event_type) + ",";
   json += "\"snapshot_id\":" + TradingAI_JsonString(event.snapshot_id) + ",";
   json += "\"file_stamp\":" + TradingAI_JsonString(event.file_stamp) + ",";
   json += "\"symbol\":" + TradingAI_JsonString(event.symbol) + ",";
   json += "\"time_utc\":" + TradingAI_JsonString(event.time_utc) + ",";
   json += "\"screenshots\":" + TradingAI_JsonString(event.screenshots) + ",";
   json += "\"bid\":" + DoubleToString(event.bid, event.digits) + ",";
   json += "\"ask\":" + DoubleToString(event.ask, event.digits) + ",";
   json += "\"spread_points\":" + StringFormat("%I64d", event.spread_points) + ",";
   json += "\"bar_m1\":" + TradingAI_JsonString(event.bar_m1) + ",";
   json += "\"bar_m5\":" + TradingAI_JsonString(event.bar_m5) + ",";
   json += "\"bar_m15\":" + TradingAI_JsonString(event.bar_m15) + ",";
   json += "\"bar_h1\":" + TradingAI_JsonString(event.bar_h1) + ",";
   json += "\"bar_h4\":" + TradingAI_JsonString(event.bar_h4) + ",";
   json += "\"bar_d1\":" + TradingAI_JsonString(event.bar_d1);
   json += "}";
   return json;
}

bool TradingAI_BuildTimeEvent(const string symbol, TradingAI_TimeEvent &event)
{
   if(!SymbolSelect(symbol, true))
      return false;

   datetime now_time = TimeGMT();
   double bid = 0.0;
   double ask = 0.0;
   long spread_points = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(!SymbolInfoDouble(symbol, SYMBOL_BID, bid))
      return false;

   if(!SymbolInfoDouble(symbol, SYMBOL_ASK, ask))
      return false;

   spread_points = (long)SymbolInfoInteger(symbol, SYMBOL_SPREAD);

   event.symbol = symbol;
   event.event_type = "time_snapshot";
   event.file_stamp = TradingAI_FormatFileTimestamp(now_time);
   event.time_utc = TimeToString(now_time, TIME_DATE | TIME_SECONDS);
   event.snapshot_id = symbol + "_" + TradingAI_FormatCompactTime(now_time);
   event.digits = digits > 0 ? digits : 8;
   event.bid = bid;
   event.ask = ask;
   event.spread_points = spread_points;
   event.bar_m1 = TradingAI_BarTimeToString(symbol, PERIOD_M1);
   event.bar_m5 = TradingAI_BarTimeToString(symbol, PERIOD_M5);
   event.bar_m15 = TradingAI_BarTimeToString(symbol, PERIOD_M15);
   event.bar_h1 = TradingAI_BarTimeToString(symbol, PERIOD_H1);
   event.bar_h4 = TradingAI_BarTimeToString(symbol, PERIOD_H4);
   event.bar_d1 = TradingAI_BarTimeToString(symbol, PERIOD_D1);

   return true;
}

#endif
