#ifndef TRADINGAI_FILELOGGER_MQH
#define TRADINGAI_FILELOGGER_MQH

class CTradingAIFileLogger
{
private:
   string m_base_folder;

   string BuildDailyPath(const string prefix) const
   {
      MqlDateTime now;
      TimeToStruct(TimeCurrent(), now);

      string date_part = StringFormat("%04d%02d%02d", now.year, now.mon, now.day);
      return m_base_folder + "\\" + prefix + "_" + date_part + ".jsonl";
   }

public:
   bool Init(const string folder_name)
   {
      m_base_folder = folder_name;

      if(!FolderCreate(m_base_folder))
      {
         int error_code = GetLastError();
         if(error_code != 0)
            PrintFormat("TradingAI: folder creation returned false for %s (error %d)", m_base_folder, error_code);
      }

      return true;
   }

   bool AppendJsonLine(const string prefix, const string line) const
   {
      string path = BuildDailyPath(prefix);
      int handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);

      if(handle == INVALID_HANDLE)
      {
         PrintFormat("TradingAI: unable to open log file %s (error %d)", path, GetLastError());
         return false;
      }

      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\r\n");
      FileFlush(handle);
      FileClose(handle);
      return true;
   }
};

#endif
