//+------------------------------------------------------------------+
//|                                              ExportBars.mq5      |
//|   MT5 dan tarixiy barlarni CSV ga eksport qiladi (Python uchun)   |
//|                                                                  |
//|  ISHLATISH:                                                      |
//|   1. Bu faylni MQL5\Scripts\ papkasiga qo'ying (Experts EMAS!)   |
//|   2. MetaEditor da F7 bilan kompilyatsiya qiling                 |
//|   3. XAUUSD chartini oching, HOME tugmasini bosing va tarix      |
//|      yuklanishini kuting (Tools->Options->Charts->Max bars in    |
//|      chart = Unlimited qilib qo'ying)                            |
//|   4. Navigator -> Scripts -> ExportBars ni chartga tashlang      |
//|   5. Fayl bu yerda paydo bo'ladi:                                |
//|      File -> Open Data Folder -> MQL5\Files\                     |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold"
#property version   "1.00"
#property script_show_inputs
#property description "Tarixiy barlarni CSV ga eksport qiladi."

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;  // Qaysi timeframe
input int             InpYears     = 5;           // Necha yillik tarix
input string          InpFileName  = "";          // Fayl nomi (bo'sh = avtomatik)

void OnStart()
  {
   datetime to   = TimeCurrent();
   datetime from = to - (datetime)((long)InpYears * 365 * 86400);

   Print("═══════════════════════════════════════════════════");
   PrintFormat("Eksport: %s  %s", _Symbol, EnumToString(InpTimeframe));
   PrintFormat("Davr: %s .. %s",
               TimeToString(from, TIME_DATE), TimeToString(to, TIME_DATE));

   MqlRates r[];
   ArraySetAsSeries(r, false);

   int n = CopyRates(_Symbol, InpTimeframe, from, to, r);
   if(n <= 0)
     {
      Print("XATO: ma'lumot olinmadi. Chartda HOME bosib tarixni yuklang,");
      Print("keyin qayta urinib ko'ring. CopyRates xatosi: ", GetLastError());
      return;
     }
   PrintFormat("Olindi: %d bar", n);

   string fname = InpFileName;
   if(StringLen(fname) == 0)
      fname = StringFormat("%s_%s.csv", _Symbol, EnumToString(InpTimeframe));

   int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE)
     {
      Print("XATO: fayl ochilmadi (", fname, ") xato=", GetLastError());
      return;
     }

   FileWriteString(fh, "datetime,open,high,low,close,tick_volume,spread\n");

   int d = _Digits;
   for(int i = 0; i < n; i++)
     {
      string line = StringFormat("%s,%s,%s,%s,%s,%d,%d\n",
                                 TimeToString(r[i].time, TIME_DATE | TIME_MINUTES),
                                 DoubleToString(r[i].open,  d),
                                 DoubleToString(r[i].high,  d),
                                 DoubleToString(r[i].low,   d),
                                 DoubleToString(r[i].close, d),
                                 (int)r[i].tick_volume,
                                 (int)r[i].spread);
      FileWriteString(fh, line);
     }
   FileClose(fh);

//--- broker ma'lumotlari — bu menga KERAK ---------------------------
   Print("───────────── BROKER MA'LUMOTLARI ─────────────");
   PrintFormat("Simvol ............ %s", _Symbol);
   PrintFormat("Digits / Point .... %d / %s", _Digits, DoubleToString(_Point, 5));
   PrintFormat("Joriy spread ...... %d punkt = %s",
               (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
               DoubleToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point, _Digits));
   PrintFormat("Contract size ..... %.2f",
               SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
   PrintFormat("Tick value / size . %.5f / %s",
               SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
               DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), 5));
   PrintFormat("Volume min/max/step %.2f / %.2f / %.2f",
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
   PrintFormat("STOPS / FREEZE .... %d / %d punkt",
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   PrintFormat("Server vaqti ...... %s", TimeToString(TimeTradeServer(), TIME_DATE | TIME_MINUTES));
   PrintFormat("GMT vaqti ......... %s", TimeToString(TimeGMT(), TIME_DATE | TIME_MINUTES));
   PrintFormat("Server GMT offset . %+.1f soat",
               (double)(TimeTradeServer() - TimeGMT()) / 3600.0);
   Print("───────────────────────────────────────────────");
   PrintFormat("TAYYOR -> MQL5\\Files\\%s  (%d bar)", fname, n);
   Print("═══════════════════════════════════════════════════");

   Alert(StringFormat("Eksport tayyor: %s (%d bar)\nMQL5\\Files papkasida", fname, n));
  }
//+------------------------------------------------------------------+
