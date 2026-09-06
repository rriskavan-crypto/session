//+------------------------------------------------------------------+
//|                                    SB_Gold_v30_Stage1_SL.mq5     |
//|                  Asian Session Range Breakout — XAUUSD           |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  BOSQICH 1 / 5 :  SL MEXANIKASI TO'LIQ QAYTA YOZILDI     ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  v2.00 ga nisbatan TUZATILGAN MUAMMOLAR:                         |
//|                                                                  |
//|  [1] SL endi ENTRY dan emas, QAT'IY LEVEL dan hisoblanadi.       |
//|      Eski: SL = entry - (rangeHigh-rangeLow) - buffer            |
//|            -> entry rangeHigh+buffer dan oshsa, SL RANGE ICHIDA  |
//|            -> oddiy retest da SL uriladi                         |
//|      Yangi: BUY  SL = rangeLow  - buffer      (qat'iy)           |
//|             SELL SL = rangeHigh + buffer + spread (qat'iy)       |
//|                                                                  |
//|  [2] SL o'rnatilganligi ORDERDAN KEYIN TEKSHIRILADI.             |
//|      Market-execution brokerlar SL/TP ni tashlab yuborishi       |
//|      mumkin -> "SL siz pozitsiya". Endi PositionModify bilan     |
//|      tiklanadi, tiklanmasa pozitsiya YOPILADI.                   |
//|                                                                  |
//|  [3] SLIPPAGE kompensatsiyasi. SL level qat'iy bo'lgani uchun    |
//|      slippage SL ga ta'sir qilmaydi; TP haqiqiy fill narxidan    |
//|      qayta hisoblanadi -> RR har doim rejadagiga teng.           |
//|                                                                  |
//|  [4] SELL SL ga SPREAD qo'shiladi. MT5 da sell SL Ask bo'yicha   |
//|      ishlaydi, barlar esa Bid dan quriladi -> sell SL spread     |
//|      miqdoricha ERTA urilardi. Endi kompensatsiya qilinadi.      |
//|                                                                  |
//|  [5] NormalizeDouble barcha narxlarda -> "Invalid stops" yo'q.   |
//|                                                                  |
//|  [6] Har bir savdo natijasi retcode bilan LOG qilinadi.          |
//|                                                                  |
//|  [7] KECH KIRISH FILTRI: entry breakout levelidan juda uzoq      |
//|      bo'lsa savdo RAD ETILADI (SL ni cho'zmaslik uchun).         |
//|                                                                  |
//|  [8] Yangi kunda eski range MAJBURIY tozalanadi -> kechagi       |
//|      levellar bilan savdo qilish xavfi yo'q.                     |
//|                                                                  |
//|  [9] Filling mode + deviation avtomatik sozlanadi.               |
//|                                                                  |
//| [10] 2/3-digit broker farqi avtomatik moslashtiriladi.           |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Stage 1"
#property link      ""
#property version   "3.00"
#property description "BOSQICH 1/5: SL mexanikasi. Level-based SL, spread"
#property description "kompensatsiyasi, SL verifikatsiyasi, slippage-proof TP."

#include <Trade\Trade.mqh>

CTrade trade;

//==================================================================//
//                            INPUTLAR                              //
//==================================================================//
input group "════════ Sessiya vaqtlari (BROKER SERVER vaqti) ════════"
input int      InpAsianStartHour    = 0;      // Asian range boshlanishi (soat)
input int      InpAsianEndHour      = 7;      // Asian range tugashi (soat)
input int      InpSessionHour       = 8;      // Savdo oynasi boshlanishi (soat)
input int      InpSessionEndHour    = 11;     // Savdo oynasi tugashi (soat)

input group "════════ Savdo parametrlari ════════"
input double   InpLotSize           = 0.10;   // Lot hajmi (qat'iy)
input double   InpRR_Ratio          = 2.0;    // Risk/Reward nisbati (TP = RR x SL)
input int      InpMagicNumber       = 100003; // Magic number

input group "════════ SL MEXANIKASI  [BOSQICH 1] ════════"
input int      InpSL_BufferPoints   = 50;     // SL buffer (punkt, range chegarasidan tashqarida)
input double   InpMaxEntryDistPct   = 30.0;   // Max kirish masofasi (range kengligining %)
input bool     InpAddSpreadToSellSL = true;   // SELL SL ga spread qo'shish (tavsiya: true)
input bool     InpVerifyStops       = true;   // Orderdan keyin SL/TP ni tekshirish
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa pozitsiyani yopish

input group "════════ Ijro sifati ════════"
input int      InpSlippagePoints    = 50;     // Ruxsat etilgan slippage (punkt)
input int      InpMaxSpreadPoints   = 60;     // Max spread (punkt) — 0 = filtr o'chiq
input bool     InpAutoAdjustPoints  = true;   // 3/5-digit brokerda punktni x10 qilish
input bool     InpVerboseLog        = true;   // Batafsil log

//==================================================================//
//                        GLOBAL O'ZGARUVCHILAR                     //
//==================================================================//
double   g_rangeHigh      = 0.0;   // bugungi Asian range yuqori chegarasi
double   g_rangeLow       = 0.0;   // bugungi Asian range quyi chegarasi
double   g_rangeWidth     = 0.0;   // range kengligi (narx birligida)
datetime g_lastRangeDate  = 0;     // range qurilgan kun (yarim tun)

double   g_pipSize        = 0.0;   // "moslashtirilgan punkt" narx birligida
double   g_pointMult      = 1.0;   // 1.0 yoki 10.0 (digits ga qarab)
double   g_stopsLevelPx   = 0.0;   // broker STOPS_LEVEL narx birligida

//==================================================================//
//                          YORDAMCHI FUNKSIYALAR                   //
//==================================================================//

//--- Narxni matnga (log uchun) ---------------------------------------
string PS(const double price)
  {
   return DoubleToString(price, _Digits);
  }

//--- Narxni broker digits ga normalizatsiya --------------------------
double NP(const double price)
  {
   return NormalizeDouble(price, _Digits);
  }

//--- Batafsil log -----------------------------------------------------
void Log(const string msg)
  {
   if(InpVerboseLog) Print(msg);
  }

//--- Bugungi yarim tun (server vaqti) --------------------------------
datetime TodayMidnight()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return (TimeCurrent() - (tm.hour * 3600 + tm.min * 60 + tm.sec));
  }

//--- Yangi bar detektori ---------------------------------------------
bool NewBar()
  {
   static datetime lastBarTime = 0;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == 0) return false;                 // tarix hali yuklanmagan
   if(t != lastBarTime)
     {
      lastBarTime = t;
      return true;
     }
   return false;
  }

//--- Bizning pozitsiyamizni topish (0 = yo'q) ------------------------
ulong FindOurPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);   // bu chaqiruv pozitsiyani TANLAYDI
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)   != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC)   != InpMagicNumber) continue;
      return ticket;
     }
   return 0;
  }

//==================================================================//
//                            OnInit                                //
//==================================================================//
int OnInit()
  {
//--- 2/3-digit broker moslashuvi -------------------------------------
   g_pointMult = 1.0;
   if(InpAutoAdjustPoints && (_Digits == 3 || _Digits == 5))
      g_pointMult = 10.0;
   g_pipSize = _Point * g_pointMult;

//--- broker cheklovlari ----------------------------------------------
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_stopsLevelPx  = (double)stopsLevel * _Point;

//--- CTrade sozlamalari ----------------------------------------------
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathRound(InpSlippagePoints * g_pointMult));

   if(!trade.SetTypeFillingBySymbol(_Symbol))
      Print("[OGOHLANTIRISH] Filling mode aniqlanmadi — CTrade standarti ishlatiladi");

//--- konfiguratsiya hisoboti -----------------------------------------
   Print("════════════════════════════════════════════════════════");
   Print("  SESSION BREAKOUT GOLD  v3.00  —  BOSQICH 1/5 (SL)");
   Print("════════════════════════════════════════════════════════");
   PrintFormat("  Simvol .............. %s", _Symbol);
   PrintFormat("  Timeframe ........... %s", EnumToString((ENUM_TIMEFRAMES)Period()));
   PrintFormat("  Digits / Point ...... %d / %s", _Digits, DoubleToString(_Point, 5));
   PrintFormat("  Punkt ko'paytiruvchi  x%.0f  (1 punkt = %s)",
               g_pointMult, DoubleToString(g_pipSize, _Digits));
   PrintFormat("  SL buffer ........... %d punkt = %s", InpSL_BufferPoints,
               PS(InpSL_BufferPoints * g_pipSize));
   PrintFormat("  Max spread .......... %d punkt = %s", InpMaxSpreadPoints,
               PS(InpMaxSpreadPoints * g_pipSize));
   PrintFormat("  Slippage ............ %d punkt", InpSlippagePoints);
   PrintFormat("  STOPS_LEVEL ......... %d punkt = %s", (int)stopsLevel, PS(g_stopsLevelPx));
   PrintFormat("  Asian range ......... %02d:00 - %02d:00", InpAsianStartHour, InpAsianEndHour);
   PrintFormat("  Savdo oynasi ........ %02d:00 - %02d:00", InpSessionHour, InpSessionEndHour);
   PrintFormat("  Lot / RR ............ %.2f / %.2f", InpLotSize, InpRR_Ratio);
   PrintFormat("  Max kirish masofasi.. range kengligining %.1f%%", InpMaxEntryDistPct);
   Print("════════════════════════════════════════════════════════");

//--- eng oddiy sanity-check ------------------------------------------
   if(InpRR_Ratio <= 0.0)
     {
      Alert("XATO: InpRR_Ratio 0 dan katta bo'lishi kerak!");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpAsianStartHour >= InpAsianEndHour)
     {
      Alert("XATO: InpAsianStartHour < InpAsianEndHour bo'lishi kerak!");
      return(INIT_PARAMETERS_INCORRECT);
     }

   return(INIT_SUCCEEDED);
  }

//==================================================================//
void OnDeinit(const int reason)
  {
   Comment("");
  }

//==================================================================//
//                    ASIAN RANGE NI QURISH                         //
//==================================================================//
void BuildAsianRange()
  {
   datetime todayMidnight = TodayMidnight();

//--- [TUZATISH 8] Yangi kun -> eski rangeni MAJBURIY tozalash --------
//    Aks holda bugungi barlar topilmasa, KECHAGI levellar bilan
//    savdo qilinardi.
   if(g_lastRangeDate != todayMidnight && g_rangeHigh > 0.0)
     {
      g_rangeHigh  = 0.0;
      g_rangeLow   = 0.0;
      g_rangeWidth = 0.0;
      Log("[RANGE] Yangi kun boshlandi — eski range tozalandi");
     }

   if(g_lastRangeDate == todayMidnight) return;   // bugun allaqachon qurilgan

   datetime rangeStart = todayMidnight + InpAsianStartHour * 3600;
   datetime rangeEnd   = todayMidnight + InpAsianEndHour   * 3600;
   if(TimeCurrent() < rangeEnd) return;           // Asian sessiya hali tugamagan

   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= 0)
     {
      Print("[RANGE][XATO] Tarix mavjud emas");
      return;
     }

   double highest = 0.0, lowest = 0.0;
   int    counted = 0;

   for(int i = 0; i < bars; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t == 0)          break;                  // tarix tugadi
      if(t < rangeStart)  break;                  // oynadan chiqdik
      if(t >= rangeEnd)   continue;               // hali oynaga kirmadik

      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow (_Symbol, PERIOD_CURRENT, i);
      if(h <= 0.0 || l <= 0.0) continue;

      if(counted == 0) { highest = h; lowest = l; }
      else
        {
         if(h > highest) highest = h;
         if(l < lowest ) lowest  = l;
        }
      counted++;
     }

//--- muvaffaqiyatsizlikni JIM O'TKAZIB YUBORMAYMIZ -------------------
   if(counted == 0 || highest <= 0.0 || lowest <= 0.0 || highest <= lowest)
     {
      static datetime lastWarnDay = 0;
      if(lastWarnDay != todayMidnight)
        {
         lastWarnDay = todayMidnight;
         PrintFormat("[RANGE][XATO] Asian range QURILMADI (topilgan bar: %d). "
                     "Bugun savdo bo'lmaydi. Sabab: tarix yetishmayapti yoki bayram.",
                     counted);
        }
      return;
     }

   g_rangeHigh     = highest;
   g_rangeLow      = lowest;
   g_rangeWidth    = highest - lowest;
   g_lastRangeDate = todayMidnight;

   PrintFormat("[RANGE] %s  High=%s  Low=%s  Kenglik=%s  (%d bar)",
               TimeToString(todayMidnight, TIME_DATE),
               PS(g_rangeHigh), PS(g_rangeLow), PS(g_rangeWidth), counted);
   PrintFormat("[RANGE] Rejalashtirilgan SL levellari:  BUY SL=%s   SELL SL=%s",
               PS(g_rangeLow  - InpSL_BufferPoints * g_pipSize),
               PS(g_rangeHigh + InpSL_BufferPoints * g_pipSize));
  }

//==================================================================//
//        ORDERDAN KEYIN SL/TP NI TEKSHIRISH VA TIKLASH             //
//==================================================================//
void VerifyAndFixStops(const bool isBuy,
                       const double plannedEntry,
                       const double wantedSL)
  {
   ulong ticket = FindOurPosition();

//--- terminal pozitsiyani ro'yxatga qo'shishi uchun qisqa kutish -----
   if(ticket == 0 && !MQLInfoInteger(MQL_TESTER))
     {
      Sleep(200);
      ticket = FindOurPosition();
     }

   if(ticket == 0)
     {
      Print("[OGOHLANTIRISH] Pozitsiya topilmadi — SL tekshiruvi o'tkazib yuborildi");
      return;
     }

   double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   double actualSL    = PositionGetDouble(POSITION_SL);
   double actualTP    = PositionGetDouble(POSITION_TP);

//--- [TUZATISH 3] SLIPPAGE hisoboti ----------------------------------
   double slip = isBuy ? (actualEntry - plannedEntry) : (plannedEntry - actualEntry);
   if(MathAbs(slip) > _Point * 0.5)
      PrintFormat("[SLIPPAGE] Reja=%s  Haqiqiy=%s  Farq=%s (%s)",
                  PS(plannedEntry), PS(actualEntry), PS(MathAbs(slip)),
                  (slip > 0 ? "yomonlashdi" : "yaxshilandi"));

//--- [TUZATISH 3] TP ni HAQIQIY entry dan qayta hisoblash ------------
//    SL level qat'iy, shuning uchun slippage faqat TP ni buzadi.
   double realRisk = MathAbs(actualEntry - wantedSL);
   double wantedTP = NP(isBuy ? actualEntry + realRisk * InpRR_Ratio
                              : actualEntry - realRisk * InpRR_Ratio);

//--- [TUZATISH 2] SL umuman o'rnatilganmi? ---------------------------
   bool slMissing = (actualSL == 0.0);
   if(slMissing)
      Print("╔═══════════════════════════════════════════════════════╗\n"
            "║ [KRITIK] BROKER SL NI QABUL QILMADI — TIKLANMOQDA...  ║\n"
            "╚═══════════════════════════════════════════════════════╝");

   bool needFix = slMissing
               || (MathAbs(actualSL - wantedSL) > _Point * 0.5)
               || (MathAbs(actualTP - wantedTP) > _Point * 0.5);

   if(!needFix)
     {
      PrintFormat("[TASDIQ] SL=%s  TP=%s  risk=%s  RR=%.2f  ✓",
                  PS(actualSL), PS(actualTP), PS(realRisk), InpRR_Ratio);
      return;
     }

   if(trade.PositionModify(ticket, wantedSL, wantedTP))
     {
      PrintFormat("[TUZATILDI] SL=%s  TP=%s  (haqiqiy entry=%s, risk=%s)",
                  PS(wantedSL), PS(wantedTP), PS(actualEntry), PS(realRisk));
      return;
     }

//--- tuzatib bo'lmadi -------------------------------------------------
   PrintFormat("[XATO] SL/TP tiklanmadi | retcode=%d | %s",
               trade.ResultRetcode(), trade.ResultRetcodeDescription());

   if(slMissing && InpCloseIfNoSL)
     {
      Print("[HIMOYA] SL SIZ POZITSIYA — DARHOL YOPILMOQDA!");
      if(!trade.PositionClose(ticket))
         PrintFormat("[XATO] Pozitsiya yopilmadi | retcode=%d | %s — QO'LDA YOPING!",
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
  }

//==================================================================//
//                       SAVDO OCHISHGA URINISH                     //
//==================================================================//
void TryOpenTrade(const bool isBuy)
  {
//--- 1) Tik ma'lumotini olish va tekshirish --------------------------
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     {
      Print("[XATO] Tik ma'lumoti olinmadi — savdo o'tkazib yuborildi");
      return;
     }

   double spread = tick.ask - tick.bid;

//--- 2) Spread filtri (narx birligida, punkt emas) -------------------
   if(InpMaxSpreadPoints > 0)
     {
      double maxSpread = InpMaxSpreadPoints * g_pipSize;
      if(spread > maxSpread)
        {
         PrintFormat("[FILTR] Spread juda keng: %s > %s — savdo yo'q",
                     PS(spread), PS(maxSpread));
         return;
        }
     }

//--- 3) SL LEVELINI ANIQLASH  [TUZATISH 1 + 4] -----------------------
//    MUHIM: SL entry ga EMAS, range LEVELIGA bog'langan.
   double bufferPx = InpSL_BufferPoints * g_pipSize;
   double entry, slPrice, breakLevel, entryDist;

   if(isBuy)
     {
      entry      = tick.ask;
      breakLevel = g_rangeHigh;
      entryDist  = entry - breakLevel;
      slPrice    = g_rangeLow - bufferPx;              // ← QAT'IY LEVEL
     }
   else
     {
      entry      = tick.bid;
      breakLevel = g_rangeLow;
      entryDist  = breakLevel - entry;
      slPrice    = g_rangeHigh + bufferPx;             // ← QAT'IY LEVEL
      //  MT5: SELL SL Ask bo'yicha uriladi, barlar esa Bid dan quriladi.
      //  Spread qo'shmasak — SL spread miqdoricha ERTA uriladi.
      if(InpAddSpreadToSellSL) slPrice += spread;
     }

//--- 4) KECH KIRISH FILTRI  [TUZATISH 7] ------------------------------
//    Entry breakout levelidan juda uzoqda bo'lsa — SL cho'ziladi va
//    RR buziladi. Bunday savdoni umuman ochmagan ma'qul.
   if(InpMaxEntryDistPct > 0.0)
     {
      double maxEntryDist = g_rangeWidth * InpMaxEntryDistPct / 100.0;
      if(entryDist > maxEntryDist)
        {
         PrintFormat("[FILTR] KECH KIRISH rad etildi | %s | masofa=%s > ruxsat=%s "
                     "(range=%s, %.1f%%)",
                     (isBuy ? "BUY" : "SELL"),
                     PS(entryDist), PS(maxEntryDist), PS(g_rangeWidth),
                     InpMaxEntryDistPct);
         return;
        }
     }

//--- 5) Risk masofasi va TP -------------------------------------------
   double riskDist = MathAbs(entry - slPrice);
   if(riskDist <= 0.0)
     {
      Print("[XATO] Risk masofasi 0 yoki manfiy — savdo bekor qilindi");
      return;
     }

//--- 6) Broker STOPS_LEVEL tekshiruvi ---------------------------------
   if(g_stopsLevelPx > 0.0 && riskDist < g_stopsLevelPx)
     {
      PrintFormat("[FILTR] SL broker STOPS_LEVEL dan yaqin: %s < %s",
                  PS(riskDist), PS(g_stopsLevelPx));
      return;
     }

   double tpPrice = isBuy ? entry + riskDist * InpRR_Ratio
                          : entry - riskDist * InpRR_Ratio;

//--- 7) NORMALIZATSIYA  [TUZATISH 5] ----------------------------------
   slPrice = NP(slPrice);
   tpPrice = NP(tpPrice);

//--- 8) Signal hisoboti ------------------------------------------------
   PrintFormat("┌─ SIGNAL: %s ────────────────────────────────────", (isBuy ? "BUY" : "SELL"));
   PrintFormat("│  Range .......... %s — %s  (kenglik %s)",
               PS(g_rangeLow), PS(g_rangeHigh), PS(g_rangeWidth));
   PrintFormat("│  Breakout level . %s", PS(breakLevel));
   PrintFormat("│  Entry (kutilgan) %s   (leveldan %s uzoqda)", PS(entry), PS(entryDist));
   PrintFormat("│  Spread ......... %s", PS(spread));
   PrintFormat("│  SL ............. %s   (risk masofasi %s)", PS(slPrice), PS(riskDist));
   PrintFormat("│  TP ............. %s   (RR %.2f)", PS(tpPrice), InpRR_Ratio);
   PrintFormat("│  Lot ............ %.2f", InpLotSize);
   PrintFormat("└──────────────────────────────────────────────────");

//--- 9) Orderni yuborish -----------------------------------------------
   bool ok = isBuy
             ? trade.Buy (InpLotSize, _Symbol, tick.ask, slPrice, tpPrice, "SB_Buy")
             : trade.Sell(InpLotSize, _Symbol, tick.bid, slPrice, tpPrice, "SB_Sell");

//--- 10) Natijani TEKSHIRISH  [TUZATISH 6] -----------------------------
   if(!ok)
     {
      PrintFormat("[XATO] %s ochilmadi | retcode=%d | %s",
                  (isBuy ? "BUY" : "SELL"),
                  trade.ResultRetcode(),
                  trade.ResultRetcodeDescription());
      return;
     }

   PrintFormat("[YUBORILDI] %s | order=%s | narx=%s | hajm=%.2f",
               (isBuy ? "BUY" : "SELL"),
               IntegerToString((long)trade.ResultOrder()),
               PS(trade.ResultPrice()),
               trade.ResultVolume());

//--- 11) SL haqiqatan o'rnatildimi?  [TUZATISH 2 + 3] ------------------
   if(InpVerifyStops)
      VerifyAndFixStops(isBuy, entry, slPrice);
  }

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
  {
//--- barcha mantiq faqat YANGI BAR da (repaint yo'q) -----------------
   if(!NewBar()) return;

   BuildAsianRange();

   if(g_rangeHigh <= 0.0 || g_rangeLow <= 0.0) return;   // range tayyor emas
   if(FindOurPosition() != 0)                  return;   // pozitsiya ochiq

//--- savdo oynasi -----------------------------------------------------
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour < InpSessionHour || tm.hour >= InpSessionEndHour) return;

//--- signal: YOPILGAN barning close narxi (repaint yo'q) --------------
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close1 <= 0.0) return;

   if(close1 > g_rangeHigh)
      TryOpenTrade(true);
   else
      if(close1 < g_rangeLow)
         TryOpenTrade(false);
  }
//+------------------------------------------------------------------+
