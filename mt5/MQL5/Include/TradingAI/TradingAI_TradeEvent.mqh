#ifndef TRADINGAI_TRADEEVENT_MQH
#define TRADINGAI_TRADEEVENT_MQH

#include <TradingAI/TradingAI_Json.mqh>

enum TradingAI_TradePhase
{
   TRADE_PHASE_UNKNOWN = 0,
   TRADE_PHASE_ENTRY   = 1,
   TRADE_PHASE_EXIT    = 2
};

string TradingAI_TradePhaseToString(const TradingAI_TradePhase phase)
{
   switch(phase)
   {
      case TRADE_PHASE_ENTRY:
         return "entry";
      case TRADE_PHASE_EXIT:
         return "exit";
      default:
         return "unknown";
   }
}

string TradingAI_DealTypeToString(const ENUM_DEAL_TYPE deal_type)
{
   switch(deal_type)
   {
      case DEAL_TYPE_BUY:
         return "buy";
      case DEAL_TYPE_SELL:
         return "sell";
      case DEAL_TYPE_BALANCE:
         return "balance";
      case DEAL_TYPE_CREDIT:
         return "credit";
      case DEAL_TYPE_CHARGE:
         return "charge";
      case DEAL_TYPE_CORRECTION:
         return "correction";
      case DEAL_TYPE_BONUS:
         return "bonus";
      case DEAL_TYPE_COMMISSION:
         return "commission";
      case DEAL_TYPE_COMMISSION_DAILY:
         return "commission_daily";
      case DEAL_TYPE_COMMISSION_MONTHLY:
         return "commission_monthly";
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:
         return "commission_agent_daily";
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY:
         return "commission_agent_monthly";
      case DEAL_TYPE_INTEREST:
         return "interest";
      case DEAL_TYPE_BUY_CANCELED:
         return "buy_canceled";
      case DEAL_TYPE_SELL_CANCELED:
         return "sell_canceled";
      default:
         return "unknown";
   }
}

string TradingAI_DealEntryToString(const ENUM_DEAL_ENTRY entry)
{
   switch(entry)
   {
      case DEAL_ENTRY_IN:
         return "in";
      case DEAL_ENTRY_OUT:
         return "out";
      case DEAL_ENTRY_INOUT:
         return "inout";
      case DEAL_ENTRY_OUT_BY:
         return "out_by";
      default:
         return "unknown";
   }
}

struct TradingAI_TradeEvent
{
   string                event_type;
   string                event_id;
   string                file_stamp;
   string                symbol;
   string                comment;
   string                screenshots;
   string                phase;
   string                deal_type;
   string                deal_entry;
   string                time_utc;
   long                  deal_ticket;
   long                  order_ticket;
   long                  position_ticket;
   long                  magic;
   double                price;
   int                   price_digits;
   double                volume;
   double                profit;
};

string TradingAI_BuildTradeEventJson(const TradingAI_TradeEvent &event)
{
   string json = "{";
   json += "\"event_type\":" + TradingAI_JsonString(event.event_type) + ",";
   json += "\"event_id\":" + TradingAI_JsonString(event.event_id) + ",";
   json += "\"file_stamp\":" + TradingAI_JsonString(event.file_stamp) + ",";
   json += "\"symbol\":" + TradingAI_JsonString(event.symbol) + ",";
   json += "\"comment\":" + TradingAI_JsonString(event.comment) + ",";
   json += "\"screenshots\":" + TradingAI_JsonString(event.screenshots) + ",";
   json += "\"phase\":" + TradingAI_JsonString(event.phase) + ",";
   json += "\"deal_type\":" + TradingAI_JsonString(event.deal_type) + ",";
   json += "\"deal_entry\":" + TradingAI_JsonString(event.deal_entry) + ",";
   json += "\"time_utc\":" + TradingAI_JsonString(event.time_utc) + ",";
   json += "\"deal_ticket\":" + StringFormat("%I64d", event.deal_ticket) + ",";
   json += "\"order_ticket\":" + StringFormat("%I64d", event.order_ticket) + ",";
   json += "\"position_ticket\":" + StringFormat("%I64d", event.position_ticket) + ",";
   json += "\"magic\":" + StringFormat("%I64d", event.magic) + ",";
   json += "\"price\":" + DoubleToString(event.price, event.price_digits) + ",";
   json += "\"volume\":" + DoubleToString(event.volume, 2) + ",";
   json += "\"profit\":" + DoubleToString(event.profit, 2);
   json += "}";
   return json;
}

#endif
