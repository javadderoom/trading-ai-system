#ifndef TRADINGAI_JSON_MQH
#define TRADINGAI_JSON_MQH

string TradingAI_EscapeJson(const string value)
{
   string result = value;

   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\t", "\\t");

   return result;
}

string TradingAI_JsonString(const string value)
{
   return "\"" + TradingAI_EscapeJson(value) + "\"";
}

string TradingAI_JsonNumber(const double value, const int digits = 5)
{
   return DoubleToString(value, digits);
}

string TradingAI_JsonInteger(const long value)
{
   return StringFormat("%I64d", value);
}

#endif
