//+------------------------------------------------------------------+
//|                                  SB_Gold_v31_Stage2_Risk.mq5     |
//|                  Asian Session Range Breakout — XAUUSD           |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  BOSQICH 2 / 5 :  RISK NAZORATI                          ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  Bosqich 1 ning HAMMASI + quyidagilar:                           |
//|                                                                  |
//|  [11] KUNLIK SAVDO LIMITI. Eski kodda SL urilgandan keyin        |
//|       darhol qayta kirish mumkin edi (ko'pincha TESKARI          |
//|       tomonga) -> bir kunda 3-5 marta to'liq SL -> -5R.          |
//|       Endi InpMaxTradesPerDay bilan cheklanadi.                  |
//|                                                                  |
//|  [12] KUNLIK ZARAR LIMITI. Belgilangan % ga yetganda EA          |
//|       kun oxirigacha to'xtaydi.                                  |
//|                                                                  |
//|  [13] RISK ASOSIDA LOT (ixtiyoriy, standart holda O'CHIQ).       |
//|       Eski kodda lot qat'iy 0.10, SL masofasi esa range          |
//|       kengligiga teng -> zarar $20 dan $255 gacha (12.7x!).      |
//|       InpUseRiskSizing=true qilsangiz — har savdoda bir xil %.   |
//|       SIZNING SO'ROVINGIZ BO'YICHA standart holda 0.10 qat'iy.   |
//|                                                                  |
//|  [14] LOT VALIDATSIYASI. VOLUME_MIN / MAX / STEP ga moslash.     |
//|       0.10 lot ba'zi hisoblarda noto'g'ri qadam bo'lishi mumkin. |
//|                                                                  |
//|  [15] MARJA TEKSHIRUVI. OrderCalcMargin bilan oldindan.          |
//|                                                                  |
//|  [16] Kunlik statistika RESTART-SAFE (savdo tarixidan            |
//|       o'qiladi, xotirada saqlanmaydi) -> terminal qayta          |
//|       yuklansa ham limitlar ishlaydi.                            |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Stage 2"
#property version   "3.10"
#property description "BOSQICH 2/5: Risk nazorati. Kunlik limitlar, lot"
#property description "validatsiyasi, marja tekshiruvi, ixtiyoriy risk-sizing."

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
input double   InpRR_Ratio          = 2.0;    // Risk/Reward nisbati
input int      InpMagicNumber       = 100003; // Magic number

input group "════════ RISK NAZORATI  [BOSQICH 2] ════════"
input bool     InpUseRiskSizing     = false;  // Risk asosida lot hisoblash (false = qat'iy lot)
input double   InpRiskPercent       = 1.0;    // Savdoga risk (%) — faqat RiskSizing=true da
input double   InpMaxLotCap         = 1.00;   // Hisoblangan lot uchun yuqori chegara
input int      InpMaxTradesPerDay   = 1;      // Kuniga max savdo (0 = cheksiz)
input double   InpMaxDailyLossPct   = 3.0;    // Kunlik max zarar % (0 = o'chiq)
input double   InpMaxMarginUsePct   = 30.0;   // Bo'sh marjadan max foydalanish %

input group "════════ SL MEXANIKASI  [BOSQICH 1] ════════"
input int      InpSL_BufferPoints   = 50;     // SL buffer (punkt)
input double   InpMaxEntryDistPct   = 30.0;   // Max kirish masofasi (range %)
input bool     InpAddSpreadToSellSL = true;   // SELL SL ga spread qo'shish
input bool     InpVerifyStops       = true;   // Orderdan keyin SL/TP tekshiruvi
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa pozitsiyani yopish

input group "════════ Ijro sifati ════════"
input int      InpSlippagePoints    = 50;     // Ruxsat etilgan slippage (punkt)
input int      InpMaxSpreadPoints   = 60;     // Max spread (punkt), 0 = o'chiq
input bool     InpAutoAdjustPoints  = true;   // 3/5-digit brokerda punkt x10
input bool     InpVerboseLog        = true;   // Batafsil log

//==================================================================//
//                        GLOBAL O'ZGARUVCHILAR                     //
//==================================================================//
double   g_rangeHigh      = 0.0;
double   g_rangeLow       = 0.0;
double   g_rangeWidth     = 0.0;
datetime g_lastRangeDate  = 0;

double   g_pipSize        = 0.0;
double   g_pointMult      = 1.0;
double   g_stopsLevelPx   = 0.0;

datetime g_blockedDay     = 0;     // kunlik limit tufayli bloklangan kun

//==================================================================//
//                          YORDAMCHI FUNKSIYALAR                   //
//==================================================================//
string PS(const double price) { return DoubleToString(price, _Digits); }
double NP(const double price) { return NormalizeDouble(price, _Digits); }
void   Log(const string msg)  { if(InpVerboseLog) Print(msg); }

datetime TodayMidnight()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return (TimeCurrent() - (tm.hour * 3600 + tm.min * 60 + tm.sec));
  }

bool NewBar()
  {
   static datetime lastBarTime = 0;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == 0) return false;
   if(t != lastBarTime) { lastBarTime = t; return true; }
   return false;
  }

ulong FindOurPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)        continue;
      if(PositionGetInteger(POSITION_MAGIC)  != InpMagicNumber) continue;
      return ticket;
     }
   return 0;
  }

//==================================================================//
//        KUNLIK STATISTIKA — TARIXDAN (RESTART-SAFE)  [16]         //
//==================================================================//

//--- Bugun ochilgan savdolar soni -------------------------------------
int CountTodayEntries()
  {
   datetime dayStart = TodayMidnight();
   if(!HistorySelect(dayStart, TimeCurrent() + 3600)) return 0;

   int cnt = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC)  != InpMagicNumber) continue;
      if(HistoryDealGetString (t, DEAL_SYMBOL) != _Symbol)        continue;
      if(HistoryDealGetInteger(t, DEAL_ENTRY)  == DEAL_ENTRY_IN)  cnt++;
     }
   return cnt;
  }

//--- Bugungi realizatsiya qilingan P/L (komissiya+swap bilan) ---------
double TodayRealizedPL()
  {
   datetime dayStart = TodayMidnight();
   if(!HistorySelect(dayStart, TimeCurrent() + 3600)) return 0.0;

   double pl = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC)  != InpMagicNumber) continue;
      if(HistoryDealGetString (t, DEAL_SYMBOL) != _Symbol)        continue;
      //  IN deallarda profit=0, faqat komissiya bo'ladi — hammasini qo'shamiz
      pl += HistoryDealGetDouble(t, DEAL_PROFIT)
          + HistoryDealGetDouble(t, DEAL_SWAP)
          + HistoryDealGetDouble(t, DEAL_COMMISSION);
     }
   return pl;
  }

//--- Kunlik limitlarni tekshirish -------------------------------------
bool DailyLimitsOK()
  {
   datetime today = TodayMidnight();

//--- [11] savdolar soni ----------------------------------------------
   if(InpMaxTradesPerDay > 0)
     {
      int done = CountTodayEntries();
      if(done >= InpMaxTradesPerDay)
        {
         if(g_blockedDay != today)
           {
            g_blockedDay = today;
            PrintFormat("[LIMIT] Kunlik savdo limiti to'ldi: %d/%d — ertagacha to'xtash",
                        done, InpMaxTradesPerDay);
           }
         return false;
        }
     }

//--- [12] kunlik zarar -----------------------------------------------
   if(InpMaxDailyLossPct > 0.0)
     {
      double realized = TodayRealizedPL();
      if(realized < 0.0)
        {
         //  Kun boshidagi balansni tiklaymiz (hech qanday xotira kerak emas)
         double dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE) - realized;
         if(dayStartBalance > 0.0)
           {
            double lossPct = (-realized) / dayStartBalance * 100.0;
            if(lossPct >= InpMaxDailyLossPct)
              {
               if(g_blockedDay != today)
                 {
                  g_blockedDay = today;
                  PrintFormat("[LIMIT] KUNLIK ZARAR LIMITI: %.2f%% (%.2f) >= %.2f%% "
                              "— ertagacha to'xtash",
                              lossPct, realized, InpMaxDailyLossPct);
                 }
               return false;
              }
           }
        }
     }

   return true;
  }

//==================================================================//
//                  LOT HISOBLASH VA VALIDATSIYA  [13][14]          //
//==================================================================//

//--- Lotni broker qadamiga moslashtirish -------------------------------
double NormalizeVolume(double vol)
  {
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0) vstep = 0.01;

//--- PASTGA yaxlitlash (riskni oshirmaslik uchun) ---------------------
   vol = MathFloor(vol / vstep + 1e-8) * vstep;

   if(vol < vmin) vol = vmin;
   if(vol > vmax) vol = vmax;

//--- qadamning o'nlik xonalari soni ------------------------------------
   int volDigits = 0;
   double s = vstep;
   while(s < 1.0 - 1e-9 && volDigits < 8) { s *= 10.0; volDigits++; }

   return NormalizeDouble(vol, volDigits);
  }

//--- Risk asosida lot ---------------------------------------------------
double CalcLot(const double riskDist)
  {
//--- qat'iy lot rejimi (STANDART) --------------------------------------
   if(!InpUseRiskSizing)
     {
      double v = NormalizeVolume(InpLotSize);
      if(MathAbs(v - InpLotSize) > 1e-8)
         PrintFormat("[LOT] %.2f -> %.2f ga moslashtirildi (broker VOLUME_STEP)",
                     InpLotSize, v);
      return v;
     }

//--- risk asosida -------------------------------------------------------
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0 || riskDist <= 0.0)
     {
      Print("[LOT][XATO] Tick qiymati/o'lchami olinmadi — qat'iy lot ishlatiladi");
      return NormalizeVolume(InpLotSize);
     }

   double lossPerLot = (riskDist / tickSize) * tickValue;   // 1 lot uchun zarar
   if(lossPerLot <= 0.0)
     {
      Print("[LOT][XATO] lossPerLot <= 0 — qat'iy lot ishlatiladi");
      return NormalizeVolume(InpLotSize);
     }

   double lot = riskMoney / lossPerLot;
   if(InpMaxLotCap > 0.0 && lot > InpMaxLotCap) lot = InpMaxLotCap;

   double result = NormalizeVolume(lot);

   PrintFormat("[LOT] Balans=%.2f  Risk=%.1f%%=%.2f  SL masofasi=%s  "
               "1 lot zarari=%.2f  ->  LOT=%.2f  (haqiqiy risk %.2f)",
               balance, InpRiskPercent, riskMoney, PS(riskDist),
               lossPerLot, result, result * lossPerLot);

   return result;
  }

//--- Marja yetarlimi?  [15] --------------------------------------------
bool HasEnoughMargin(const bool isBuy, const double lot, const double price)
  {
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(!OrderCalcMargin(ot, _Symbol, lot, price, margin))
     {
      Print("[MARJA][OGOHLANTIRISH] OrderCalcMargin ishlamadi — tekshiruv o'tkazib yuborildi");
      return true;   // bloklamaymiz, lekin ogohlantiramiz
     }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double limit      = freeMargin * InpMaxMarginUsePct / 100.0;

   if(margin > limit)
     {
      PrintFormat("[MARJA] Yetarli emas: kerak=%.2f, ruxsat=%.2f (bo'sh marja=%.2f, %.0f%%)",
                  margin, limit, freeMargin, InpMaxMarginUsePct);
      return false;
     }

   Log(StringFormat("[MARJA] OK: kerak=%.2f / bo'sh=%.2f", margin, freeMargin));
   return true;
  }

//==================================================================//
//                            OnInit                                //
//==================================================================//
int OnInit()
  {
   g_pointMult = 1.0;
   if(InpAutoAdjustPoints && (_Digits == 3 || _Digits == 5)) g_pointMult = 10.0;
   g_pipSize = _Point * g_pointMult;

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_stopsLevelPx  = (double)stopsLevel * _Point;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathRound(InpSlippagePoints * g_pointMult));
   if(!trade.SetTypeFillingBySymbol(_Symbol))
      Print("[OGOHLANTIRISH] Filling mode aniqlanmadi — CTrade standarti");

   Print("════════════════════════════════════════════════════════");
   Print("  SESSION BREAKOUT GOLD  v3.10  —  BOSQICH 2/5 (RISK)");
   Print("════════════════════════════════════════════════════════");
   PrintFormat("  Simvol / TF ......... %s / %s", _Symbol,
               EnumToString((ENUM_TIMEFRAMES)Period()));
   PrintFormat("  Digits / punkt x .... %d / x%.0f (1 punkt = %s)",
               _Digits, g_pointMult, PS(g_pipSize));
   PrintFormat("  Lot rejimi .......... %s",
               (InpUseRiskSizing
                ? StringFormat("RISK ASOSIDA (%.2f%%)", InpRiskPercent)
                : StringFormat("QAT'IY %.2f lot", InpLotSize)));
   PrintFormat("  Kunlik savdo limiti . %s",
               (InpMaxTradesPerDay > 0 ? IntegerToString(InpMaxTradesPerDay) : "cheksiz"));
   PrintFormat("  Kunlik zarar limiti . %s",
               (InpMaxDailyLossPct > 0.0
                ? StringFormat("%.2f%%", InpMaxDailyLossPct) : "o'chiq"));
   PrintFormat("  SL buffer ........... %d punkt = %s", InpSL_BufferPoints,
               PS(InpSL_BufferPoints * g_pipSize));
   PrintFormat("  Max spread .......... %d punkt = %s", InpMaxSpreadPoints,
               PS(InpMaxSpreadPoints * g_pipSize));
   PrintFormat("  Volume MIN/MAX/STEP . %.2f / %.2f / %.2f",
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
   PrintFormat("  Asian / Savdo ....... %02d:00-%02d:00  /  %02d:00-%02d:00",
               InpAsianStartHour, InpAsianEndHour, InpSessionHour, InpSessionEndHour);
   Print("════════════════════════════════════════════════════════");

   if(InpRR_Ratio <= 0.0)
     { Alert("XATO: InpRR_Ratio > 0 bo'lishi kerak!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpAsianStartHour >= InpAsianEndHour)
     { Alert("XATO: AsianStart < AsianEnd bo'lishi kerak!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseRiskSizing && InpRiskPercent <= 0.0)
     { Alert("XATO: InpRiskPercent > 0 bo'lishi kerak!"); return(INIT_PARAMETERS_INCORRECT); }

   return(INIT_SUCCEEDED);
  }

//==================================================================//
void OnDeinit(const int reason) { Comment(""); }

//==================================================================//
//                    ASIAN RANGE NI QURISH                         //
//==================================================================//
void BuildAsianRange()
  {
   datetime todayMidnight = TodayMidnight();

   if(g_lastRangeDate != todayMidnight && g_rangeHigh > 0.0)
     {
      g_rangeHigh = 0.0; g_rangeLow = 0.0; g_rangeWidth = 0.0;
      Log("[RANGE] Yangi kun boshlandi — eski range tozalandi");
     }

   if(g_lastRangeDate == todayMidnight) return;

   datetime rangeStart = todayMidnight + InpAsianStartHour * 3600;
   datetime rangeEnd   = todayMidnight + InpAsianEndHour   * 3600;
   if(TimeCurrent() < rangeEnd) return;

   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= 0) { Print("[RANGE][XATO] Tarix mavjud emas"); return; }

   double highest = 0.0, lowest = 0.0;
   int    counted = 0;

   for(int i = 0; i < bars; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t == 0)         break;
      if(t < rangeStart) break;
      if(t >= rangeEnd)  continue;

      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow (_Symbol, PERIOD_CURRENT, i);
      if(h <= 0.0 || l <= 0.0) continue;

      if(counted == 0) { highest = h; lowest = l; }
      else { if(h > highest) highest = h; if(l < lowest) lowest = l; }
      counted++;
     }

   if(counted == 0 || highest <= 0.0 || lowest <= 0.0 || highest <= lowest)
     {
      static datetime lastWarnDay = 0;
      if(lastWarnDay != todayMidnight)
        {
         lastWarnDay = todayMidnight;
         PrintFormat("[RANGE][XATO] Asian range QURILMADI (bar: %d) — bugun savdo yo'q",
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
   PrintFormat("[RANGE] SL levellari:  BUY SL=%s   SELL SL=%s",
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
   if(ticket == 0 && !MQLInfoInteger(MQL_TESTER)) { Sleep(200); ticket = FindOurPosition(); }
   if(ticket == 0)
     { Print("[OGOHLANTIRISH] Pozitsiya topilmadi — SL tekshiruvi o'tkazib yuborildi"); return; }

   double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   double actualSL    = PositionGetDouble(POSITION_SL);
   double actualTP    = PositionGetDouble(POSITION_TP);

   double slip = isBuy ? (actualEntry - plannedEntry) : (plannedEntry - actualEntry);
   if(MathAbs(slip) > _Point * 0.5)
      PrintFormat("[SLIPPAGE] Reja=%s  Haqiqiy=%s  Farq=%s (%s)",
                  PS(plannedEntry), PS(actualEntry), PS(MathAbs(slip)),
                  (slip > 0 ? "yomonlashdi" : "yaxshilandi"));

   double realRisk = MathAbs(actualEntry - wantedSL);
   double wantedTP = NP(isBuy ? actualEntry + realRisk * InpRR_Ratio
                              : actualEntry - realRisk * InpRR_Ratio);

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
      PrintFormat("[TASDIQ] SL=%s  TP=%s  risk=%s  RR=%.2f  OK",
                  PS(actualSL), PS(actualTP), PS(realRisk), InpRR_Ratio);
      return;
     }

   if(trade.PositionModify(ticket, wantedSL, wantedTP))
     {
      PrintFormat("[TUZATILDI] SL=%s  TP=%s  (haqiqiy entry=%s, risk=%s)",
                  PS(wantedSL), PS(wantedTP), PS(actualEntry), PS(realRisk));
      return;
     }

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
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     { Print("[XATO] Tik ma'lumoti olinmadi"); return; }

   double spread = tick.ask - tick.bid;

   if(InpMaxSpreadPoints > 0)
     {
      double maxSpread = InpMaxSpreadPoints * g_pipSize;
      if(spread > maxSpread)
        {
         PrintFormat("[FILTR] Spread juda keng: %s > %s", PS(spread), PS(maxSpread));
         return;
        }
     }

//--- SL LEVELI (qat'iy) ------------------------------------------------
   double bufferPx = InpSL_BufferPoints * g_pipSize;
   double entry, slPrice, breakLevel, entryDist;

   if(isBuy)
     {
      entry      = tick.ask;
      breakLevel = g_rangeHigh;
      entryDist  = entry - breakLevel;
      slPrice    = g_rangeLow - bufferPx;
     }
   else
     {
      entry      = tick.bid;
      breakLevel = g_rangeLow;
      entryDist  = breakLevel - entry;
      slPrice    = g_rangeHigh + bufferPx;
      if(InpAddSpreadToSellSL) slPrice += spread;
     }

//--- kech kirish filtri -------------------------------------------------
   if(InpMaxEntryDistPct > 0.0)
     {
      double maxEntryDist = g_rangeWidth * InpMaxEntryDistPct / 100.0;
      if(entryDist > maxEntryDist)
        {
         PrintFormat("[FILTR] KECH KIRISH rad etildi | %s | masofa=%s > ruxsat=%s",
                     (isBuy ? "BUY" : "SELL"), PS(entryDist), PS(maxEntryDist));
         return;
        }
     }

   double riskDist = MathAbs(entry - slPrice);
   if(riskDist <= 0.0) { Print("[XATO] riskDist <= 0"); return; }

   if(g_stopsLevelPx > 0.0 && riskDist < g_stopsLevelPx)
     {
      PrintFormat("[FILTR] SL STOPS_LEVEL dan yaqin: %s < %s",
                  PS(riskDist), PS(g_stopsLevelPx));
      return;
     }

//--- [13][14] LOT HISOBLASH ---------------------------------------------
   double lot = CalcLot(riskDist);
   if(lot <= 0.0) { Print("[XATO] Lot 0 — savdo bekor"); return; }

//--- [15] MARJA TEKSHIRUVI ----------------------------------------------
   if(!HasEnoughMargin(isBuy, lot, entry)) return;

   double tpPrice = isBuy ? entry + riskDist * InpRR_Ratio
                          : entry - riskDist * InpRR_Ratio;

   slPrice = NP(slPrice);
   tpPrice = NP(tpPrice);

//--- pul ifodasidagi risk (hisobot uchun) --------------------------------
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskMoney = 0.0;
   if(tickValue > 0.0 && tickSize > 0.0)
      riskMoney = (riskDist / tickSize) * tickValue * lot;

   PrintFormat("┌─ SIGNAL: %s ────────────────────────────────────", (isBuy ? "BUY" : "SELL"));
   PrintFormat("│  Range .......... %s — %s  (kenglik %s)",
               PS(g_rangeLow), PS(g_rangeHigh), PS(g_rangeWidth));
   PrintFormat("│  Entry .......... %s   (leveldan %s uzoqda)", PS(entry), PS(entryDist));
   PrintFormat("│  Spread ......... %s", PS(spread));
   PrintFormat("│  SL ............. %s   (masofa %s)", PS(slPrice), PS(riskDist));
   PrintFormat("│  TP ............. %s   (RR %.2f)", PS(tpPrice), InpRR_Ratio);
   PrintFormat("│  Lot ............ %.2f   (risk ~ %.2f %s)",
               lot, riskMoney, AccountInfoString(ACCOUNT_CURRENCY));
   PrintFormat("│  Bugungi savdo .. %d / %s", CountTodayEntries(),
               (InpMaxTradesPerDay > 0 ? IntegerToString(InpMaxTradesPerDay) : "inf"));
   PrintFormat("└──────────────────────────────────────────────────");

   bool ok = isBuy
             ? trade.Buy (lot, _Symbol, tick.ask, slPrice, tpPrice, "SB_Buy")
             : trade.Sell(lot, _Symbol, tick.bid, slPrice, tpPrice, "SB_Sell");

   if(!ok)
     {
      PrintFormat("[XATO] %s ochilmadi | retcode=%d | %s",
                  (isBuy ? "BUY" : "SELL"),
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
     }

   PrintFormat("[YUBORILDI] %s | order=%s | narx=%s | hajm=%.2f",
               (isBuy ? "BUY" : "SELL"),
               IntegerToString((long)trade.ResultOrder()),
               PS(trade.ResultPrice()), trade.ResultVolume());

   if(InpVerifyStops)
      VerifyAndFixStops(isBuy, entry, slPrice);
  }

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
  {
   if(!NewBar()) return;

   BuildAsianRange();

   if(g_rangeHigh <= 0.0 || g_rangeLow <= 0.0) return;
   if(FindOurPosition() != 0)                  return;

//--- [11][12] KUNLIK LIMITLAR -----------------------------------------
   if(!DailyLimitsOK()) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour < InpSessionHour || tm.hour >= InpSessionEndHour) return;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close1 <= 0.0) return;

   if(close1 > g_rangeHigh)      TryOpenTrade(true);
   else if(close1 < g_rangeLow)  TryOpenTrade(false);
  }
//+------------------------------------------------------------------+
