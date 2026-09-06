//+------------------------------------------------------------------+
//|                               SB_Gold_v32_Stage3_Filters.mq5     |
//|                  Asian Session Range Breakout — XAUUSD           |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  BOSQICH 3 / 5 :  SIGNAL SIFATI + ADAPTIV FILTRLAR       ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  Bosqich 1 + 2 ning HAMMASI + quyidagilar:                       |
//|                                                                  |
//|  [17] ADAPTIV SL BUFFER (ATR asosida).                           |
//|       Eski: 50 punkt qat'iy -> 2-digit brokerda $0.50,           |
//|             3-digit brokerda $0.05 (amalda NOL!)                 |
//|       Yangi: buffer = ATR(M15) x koeffitsiyent,                  |
//|              pastki chegara = spread x 2 (stop-hunting himoyasi)  |
//|       Tinch kunda tor, shovqinli kunda keng — avtomatik.         |
//|                                                                  |
//|  [18] RANGE KENGLIGI FILTRI (kunlik ATR ga nisbatan).            |
//|       Juda TOR range -> SL bitta barda uriladi.                  |
//|       Juda KENG range -> TP ga yetib bo'lmaydi, risk ulkan.      |
//|       Ikkalasi ham endi rad etiladi.                             |
//|                                                                  |
//|  [19] BREAKOUT SIFATI FILTRI:                                     |
//|       a) minimal penetratsiya — 1 tick "breakout" qabul qilinmaydi|
//|       b) bar tanasi — doji/pin-bar bilan kirmaymiz               |
//|       c) breakout bari yo'nalishi close1 bilan mos kelishi       |
//|                                                                  |
//|  [20] SPREAD / RISK NISBATI. Spread SL masofasining katta        |
//|       qismini yesa — savdo ma'nosiz. Endi tekshiriladi.          |
//|                                                                  |
//|  [21] SESSIYA BOSHIDAGI "ESKIRGAN SIGNAL" filtri.                |
//|       Breakout 07:20 da bo'lib, kirish 08:00 da bo'lsa —         |
//|       signal eskirgan. InpMaxBarsSinceBreak bilan cheklanadi.    |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Stage 3"
#property version   "3.20"
#property description "BOSQICH 3/5: ATR adaptiv buffer, range kengligi filtri,"
#property description "breakout sifati, spread/risk nisbati."

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

input group "════════ RANGE FILTRI  [BOSQICH 3] ════════"
input bool     InpUseRangeFilter    = true;   // Range kengligi filtrini yoqish
input int      InpATR_DailyPeriod   = 20;     // Kunlik ATR davri
input double   InpMinRangeATR       = 0.35;   // Min range = ATR(D1) x shu
input double   InpMaxRangeATR       = 1.50;   // Max range = ATR(D1) x shu

input group "════════ BREAKOUT SIFATI  [BOSQICH 3] ════════"
input double   InpMinBreakPct       = 5.0;    // Min penetratsiya (range kengligining %)
input double   InpMinBodyPct        = 35.0;   // Breakout barining min tanasi (%)
input int      InpMaxBarsSinceBreak = 3;      // Breakoutdan keyin max bar (0 = o'chiq)
input double   InpMaxSpreadVsRiskPct= 8.0;    // Spread SL masofasining max % (0 = o'chiq)

input group "════════ ADAPTIV SL BUFFER  [BOSQICH 3] ════════"
input bool     InpUseATR_Buffer     = true;   // ATR asosida buffer (false = qat'iy punkt)
input int      InpATR_BufPeriod     = 14;     // Buffer uchun ATR davri (joriy TF)
input double   InpATR_BufMult       = 0.35;   // Buffer = ATR x shu
input double   InpMinBufSpreadMult  = 2.0;    // Buffer >= spread x shu (pastki chegara)
input int      InpSL_BufferPoints   = 50;     // Qat'iy buffer (ATR o'chiq bo'lganda)

input group "════════ RISK NAZORATI  [BOSQICH 2] ════════"
input bool     InpUseRiskSizing     = false;  // Risk asosida lot (false = qat'iy)
input double   InpRiskPercent       = 1.0;    // Savdoga risk (%)
input double   InpMaxLotCap         = 1.00;   // Lot yuqori chegarasi
input int      InpMaxTradesPerDay   = 1;      // Kuniga max savdo (0 = cheksiz)
input double   InpMaxDailyLossPct   = 3.0;    // Kunlik max zarar % (0 = o'chiq)
input double   InpMaxMarginUsePct   = 30.0;   // Bo'sh marjadan max %

input group "════════ SL MEXANIKASI  [BOSQICH 1] ════════"
input double   InpMaxEntryDistPct   = 30.0;   // Max kirish masofasi (range %)
input bool     InpAddSpreadToSellSL = true;   // SELL SL ga spread qo'shish
input bool     InpVerifyStops       = true;   // Orderdan keyin SL/TP tekshiruvi
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa yopish

input group "════════ Ijro sifati ════════"
input int      InpSlippagePoints    = 50;     // Slippage (punkt)
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
bool     g_rangeApproved  = false;   // range filtridan o'tdimi?

double   g_pipSize        = 0.0;
double   g_pointMult      = 1.0;
double   g_stopsLevelPx   = 0.0;

datetime g_blockedDay     = 0;

int      g_atrDailyH      = INVALID_HANDLE;   // ATR(D1) — range filtri uchun
int      g_atrBufH        = INVALID_HANDLE;   // ATR(joriy TF) — buffer uchun

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

//--- ATR qiymatini o'qish (shift=1 -> yopilgan bar, repaint yo'q) -----
double ReadATR(const int handle, const int shift = 1)
  {
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return 0.0;
   if(buf[0] <= 0.0 || !MathIsValidNumber(buf[0])) return 0.0;
   return buf[0];
  }

//==================================================================//
//        KUNLIK STATISTIKA — TARIXDAN (RESTART-SAFE)               //
//==================================================================//
int CountTodayEntries()
  {
   datetime dayStart = TodayMidnight();
   if(!HistorySelect(dayStart, TimeCurrent() + 3600)) return 0;
   int cnt = 0, total = HistoryDealsTotal();
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
      pl += HistoryDealGetDouble(t, DEAL_PROFIT)
          + HistoryDealGetDouble(t, DEAL_SWAP)
          + HistoryDealGetDouble(t, DEAL_COMMISSION);
     }
   return pl;
  }

bool DailyLimitsOK()
  {
   datetime today = TodayMidnight();

   if(InpMaxTradesPerDay > 0)
     {
      int done = CountTodayEntries();
      if(done >= InpMaxTradesPerDay)
        {
         if(g_blockedDay != today)
           {
            g_blockedDay = today;
            PrintFormat("[LIMIT] Kunlik savdo limiti: %d/%d — ertagacha to'xtash",
                        done, InpMaxTradesPerDay);
           }
         return false;
        }
     }

   if(InpMaxDailyLossPct > 0.0)
     {
      double realized = TodayRealizedPL();
      if(realized < 0.0)
        {
         double dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE) - realized;
         if(dayStartBalance > 0.0)
           {
            double lossPct = (-realized) / dayStartBalance * 100.0;
            if(lossPct >= InpMaxDailyLossPct)
              {
               if(g_blockedDay != today)
                 {
                  g_blockedDay = today;
                  PrintFormat("[LIMIT] KUNLIK ZARAR: %.2f%% (%.2f) >= %.2f%% — to'xtash",
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
//                  LOT HISOBLASH VA VALIDATSIYA                    //
//==================================================================//
double NormalizeVolume(double vol)
  {
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0) vstep = 0.01;

   vol = MathFloor(vol / vstep + 1e-8) * vstep;
   if(vol < vmin) vol = vmin;
   if(vol > vmax) vol = vmax;

   int volDigits = 0;
   double s = vstep;
   while(s < 1.0 - 1e-9 && volDigits < 8) { s *= 10.0; volDigits++; }
   return NormalizeDouble(vol, volDigits);
  }

double CalcLot(const double riskDist)
  {
   if(!InpUseRiskSizing)
     {
      double v = NormalizeVolume(InpLotSize);
      if(MathAbs(v - InpLotSize) > 1e-8)
         PrintFormat("[LOT] %.2f -> %.2f (broker VOLUME_STEP)", InpLotSize, v);
      return v;
     }

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0 || riskDist <= 0.0)
     { Print("[LOT][XATO] tick ma'lumoti yo'q — qat'iy lot"); return NormalizeVolume(InpLotSize); }

   double lossPerLot = (riskDist / tickSize) * tickValue;
   if(lossPerLot <= 0.0) return NormalizeVolume(InpLotSize);

   double lot = riskMoney / lossPerLot;
   if(InpMaxLotCap > 0.0 && lot > InpMaxLotCap) lot = InpMaxLotCap;
   double result = NormalizeVolume(lot);

   PrintFormat("[LOT] Balans=%.2f Risk=%.1f%%=%.2f SL=%s 1lot=%.2f -> LOT=%.2f (risk %.2f)",
               balance, InpRiskPercent, riskMoney, PS(riskDist),
               lossPerLot, result, result * lossPerLot);
   return result;
  }

bool HasEnoughMargin(const bool isBuy, const double lot, const double price)
  {
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, _Symbol, lot, price, margin))
     { Print("[MARJA][OGOH] OrderCalcMargin ishlamadi"); return true; }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double limit      = freeMargin * InpMaxMarginUsePct / 100.0;
   if(margin > limit)
     {
      PrintFormat("[MARJA] Yetarli emas: kerak=%.2f ruxsat=%.2f (bo'sh=%.2f)",
                  margin, limit, freeMargin);
      return false;
     }
   return true;
  }

//==================================================================//
//              ADAPTIV SL BUFFER  [17]                             //
//==================================================================//
double GetBufferPrice(const double spread)
  {
   double buf;

   if(InpUseATR_Buffer)
     {
      double atr = ReadATR(g_atrBufH, 1);
      if(atr > 0.0)
         buf = atr * InpATR_BufMult;
      else
        {
         buf = InpSL_BufferPoints * g_pipSize;
         Log("[BUFFER] ATR olinmadi — qat'iy punkt bufferiga qaytildi");
        }
     }
   else
      buf = InpSL_BufferPoints * g_pipSize;

//--- PASTKI CHEGARA: buffer hech qachon spread dan kichik bo'lmasin --
//    Aks holda SL aynan stop-hunting zonasida qoladi.
   double minBuf = spread * InpMinBufSpreadMult;
   if(buf < minBuf)
     {
      Log(StringFormat("[BUFFER] %s -> %s ga oshirildi (spread x%.1f chegarasi)",
                       PS(buf), PS(minBuf), InpMinBufSpreadMult));
      buf = minBuf;
     }

   return buf;
  }

//==================================================================//
//              RANGE KENGLIGI FILTRI  [18]                         //
//==================================================================//
bool ApproveRangeWidth()
  {
   if(!InpUseRangeFilter) return true;

   double atrD = ReadATR(g_atrDailyH, 1);
   if(atrD <= 0.0)
     {
      Print("[RANGE-FILTR][OGOH] Kunlik ATR olinmadi — filtr o'tkazib yuborildi");
      return true;
     }

   double minW = atrD * InpMinRangeATR;
   double maxW = atrD * InpMaxRangeATR;

   if(g_rangeWidth < minW)
     {
      PrintFormat("[RANGE-FILTR] RAD: range juda TOR  %s < %s  (ATR(D1)=%s x %.2f). "
                  "Bunday SL bitta barda uriladi.",
                  PS(g_rangeWidth), PS(minW), PS(atrD), InpMinRangeATR);
      return false;
     }

   if(g_rangeWidth > maxW)
     {
      PrintFormat("[RANGE-FILTR] RAD: range juda KENG  %s > %s  (ATR(D1)=%s x %.2f). "
                  "TP ga yetib bo'lmaydi, risk ulkan.",
                  PS(g_rangeWidth), PS(maxW), PS(atrD), InpMaxRangeATR);
      return false;
     }

   PrintFormat("[RANGE-FILTR] QABUL: %s  (ruxsat %s - %s, ATR(D1)=%s)",
               PS(g_rangeWidth), PS(minW), PS(maxW), PS(atrD));
   return true;
  }

//==================================================================//
//              BREAKOUT SIFATI FILTRI  [19][21]                    //
//==================================================================//
bool ApproveBreakout(const bool isBuy, const double close1)
  {
//--- a) MINIMAL PENETRATSIYA -------------------------------------------
   if(InpMinBreakPct > 0.0)
     {
      double need = g_rangeWidth * InpMinBreakPct / 100.0;
      double pen  = isBuy ? (close1 - g_rangeHigh) : (g_rangeLow - close1);
      if(pen < need)
        {
         PrintFormat("[BREAK-FILTR] RAD: penetratsiya zaif %s < %s (range %s ning %.1f%%)",
                     PS(pen), PS(need), PS(g_rangeWidth), InpMinBreakPct);
         return false;
        }
     }

//--- b) BAR TANASI (doji / pin-bar bilan kirmaymiz) ---------------------
   if(InpMinBodyPct > 0.0)
     {
      double o = iOpen (_Symbol, PERIOD_CURRENT, 1);
      double c = iClose(_Symbol, PERIOD_CURRENT, 1);
      double h = iHigh (_Symbol, PERIOD_CURRENT, 1);
      double l = iLow  (_Symbol, PERIOD_CURRENT, 1);
      double barRange = h - l;

      if(barRange > 0.0)
        {
         double bodyPct = MathAbs(c - o) / barRange * 100.0;
         if(bodyPct < InpMinBodyPct)
           {
            PrintFormat("[BREAK-FILTR] RAD: bar tanasi zaif %.1f%% < %.1f%% (doji/pin-bar)",
                        bodyPct, InpMinBodyPct);
            return false;
           }

         //--- bar yo'nalishi signal bilan mos kelishi kerak ------------
         bool bullBar = (c > o);
         if(isBuy != bullBar)
           {
            PrintFormat("[BREAK-FILTR] RAD: bar yo'nalishi mos emas "
                        "(signal=%s, bar=%s)",
                        (isBuy ? "BUY" : "SELL"), (bullBar ? "bullish" : "bearish"));
            return false;
           }
        }
     }

//--- c) [21] SIGNAL ESKIRMAGANMI? --------------------------------------
//    Breakout necha bar oldin sodir bo'lganini sanaymiz. Agar narx
//    ancha vaqtdan beri range tashqarisida bo'lsa — bu yangi impuls
//    emas, biz kechikdik.
   if(InpMaxBarsSinceBreak > 0)
     {
      int barsOutside = 0;
      for(int i = 1; i <= InpMaxBarsSinceBreak + 1; i++)
        {
         double c = iClose(_Symbol, PERIOD_CURRENT, i);
         if(c <= 0.0) break;
         bool outside = isBuy ? (c > g_rangeHigh) : (c < g_rangeLow);
         if(!outside) break;
         barsOutside++;
        }
      if(barsOutside > InpMaxBarsSinceBreak)
        {
         PrintFormat("[BREAK-FILTR] RAD: signal eskirgan — narx %d bardan beri "
                     "range tashqarisida (max %d)",
                     barsOutside, InpMaxBarsSinceBreak);
         return false;
        }
     }

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
      Print("[OGOH] Filling mode aniqlanmadi — CTrade standarti");

//--- ATR indikator handlelari ------------------------------------------
   g_atrDailyH = iATR(_Symbol, PERIOD_D1,      InpATR_DailyPeriod);
   g_atrBufH   = iATR(_Symbol, PERIOD_CURRENT, InpATR_BufPeriod);

   if(g_atrDailyH == INVALID_HANDLE || g_atrBufH == INVALID_HANDLE)
     {
      Alert("XATO: ATR indikatori yaratilmadi!");
      return(INIT_FAILED);
     }

   Print("════════════════════════════════════════════════════════");
   Print("  SESSION BREAKOUT GOLD  v3.20  —  BOSQICH 3/5 (FILTRLAR)");
   Print("════════════════════════════════════════════════════════");
   PrintFormat("  Simvol / TF ......... %s / %s", _Symbol,
               EnumToString((ENUM_TIMEFRAMES)Period()));
   PrintFormat("  Digits / punkt x .... %d / x%.0f (1 punkt = %s)",
               _Digits, g_pointMult, PS(g_pipSize));
   PrintFormat("  SL buffer ........... %s",
               (InpUseATR_Buffer
                ? StringFormat("ATR(%d) x %.2f, min = spread x %.1f",
                               InpATR_BufPeriod, InpATR_BufMult, InpMinBufSpreadMult)
                : StringFormat("qat'iy %d punkt = %s",
                               InpSL_BufferPoints, PS(InpSL_BufferPoints * g_pipSize))));
   PrintFormat("  Range filtri ........ %s",
               (InpUseRangeFilter
                ? StringFormat("ATR(D1,%d) x [%.2f .. %.2f]",
                               InpATR_DailyPeriod, InpMinRangeATR, InpMaxRangeATR)
                : "o'chiq"));
   PrintFormat("  Min penetratsiya .... %.1f%% (range kengligidan)", InpMinBreakPct);
   PrintFormat("  Min bar tanasi ...... %.1f%%", InpMinBodyPct);
   PrintFormat("  Max bar breakoutdan . %d", InpMaxBarsSinceBreak);
   PrintFormat("  Spread/risk max ..... %.1f%%", InpMaxSpreadVsRiskPct);
   PrintFormat("  Lot rejimi .......... %s",
               (InpUseRiskSizing
                ? StringFormat("RISK %.2f%%", InpRiskPercent)
                : StringFormat("QAT'IY %.2f", InpLotSize)));
   PrintFormat("  Kunlik limit ........ %d savdo, %.2f%% zarar",
               InpMaxTradesPerDay, InpMaxDailyLossPct);
   Print("════════════════════════════════════════════════════════");

   if(InpRR_Ratio <= 0.0)
     { Alert("XATO: InpRR_Ratio > 0!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpAsianStartHour >= InpAsianEndHour)
     { Alert("XATO: AsianStart < AsianEnd!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseRangeFilter && InpMinRangeATR >= InpMaxRangeATR)
     { Alert("XATO: MinRangeATR < MaxRangeATR!"); return(INIT_PARAMETERS_INCORRECT); }

   return(INIT_SUCCEEDED);
  }

//==================================================================//
void OnDeinit(const int reason)
  {
   if(g_atrDailyH != INVALID_HANDLE) IndicatorRelease(g_atrDailyH);
   if(g_atrBufH   != INVALID_HANDLE) IndicatorRelease(g_atrBufH);
   Comment("");
  }

//==================================================================//
//                    ASIAN RANGE NI QURISH                         //
//==================================================================//
void BuildAsianRange()
  {
   datetime todayMidnight = TodayMidnight();

   if(g_lastRangeDate != todayMidnight && g_rangeHigh > 0.0)
     {
      g_rangeHigh = 0.0; g_rangeLow = 0.0; g_rangeWidth = 0.0;
      g_rangeApproved = false;
      Log("[RANGE] Yangi kun — eski range tozalandi");
     }

   if(g_lastRangeDate == todayMidnight) return;

   datetime rangeStart = todayMidnight + InpAsianStartHour * 3600;
   datetime rangeEnd   = todayMidnight + InpAsianEndHour   * 3600;
   if(TimeCurrent() < rangeEnd) return;

   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= 0) { Print("[RANGE][XATO] Tarix yo'q"); return; }

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
         PrintFormat("[RANGE][XATO] Range QURILMADI (bar: %d) — bugun savdo yo'q", counted);
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

//--- [18] range kengligi filtri — kuniga bir marta baholanadi ----------
   g_rangeApproved = ApproveRangeWidth();
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
   if(ticket == 0) { Print("[OGOH] Pozitsiya topilmadi — SL tekshiruvi yo'q"); return; }

   double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   double actualSL    = PositionGetDouble(POSITION_SL);
   double actualTP    = PositionGetDouble(POSITION_TP);

   double slip = isBuy ? (actualEntry - plannedEntry) : (plannedEntry - actualEntry);
   if(MathAbs(slip) > _Point * 0.5)
      PrintFormat("[SLIPPAGE] Reja=%s Haqiqiy=%s Farq=%s (%s)",
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
      PrintFormat("[TASDIQ] SL=%s TP=%s risk=%s RR=%.2f OK",
                  PS(actualSL), PS(actualTP), PS(realRisk), InpRR_Ratio);
      return;
     }

   if(trade.PositionModify(ticket, wantedSL, wantedTP))
     {
      PrintFormat("[TUZATILDI] SL=%s TP=%s (entry=%s risk=%s)",
                  PS(wantedSL), PS(wantedTP), PS(actualEntry), PS(realRisk));
      return;
     }

   PrintFormat("[XATO] SL/TP tiklanmadi | retcode=%d | %s",
               trade.ResultRetcode(), trade.ResultRetcodeDescription());

   if(slMissing && InpCloseIfNoSL)
     {
      Print("[HIMOYA] SL SIZ POZITSIYA — YOPILMOQDA!");
      if(!trade.PositionClose(ticket))
         PrintFormat("[XATO] Yopilmadi | retcode=%d — QO'LDA YOPING!", trade.ResultRetcode());
     }
  }

//==================================================================//
//                       SAVDO OCHISHGA URINISH                     //
//==================================================================//
void TryOpenTrade(const bool isBuy)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     { Print("[XATO] Tik ma'lumoti yo'q"); return; }

   double spread = tick.ask - tick.bid;

   if(InpMaxSpreadPoints > 0)
     {
      double maxSpread = InpMaxSpreadPoints * g_pipSize;
      if(spread > maxSpread)
        { PrintFormat("[FILTR] Spread keng: %s > %s", PS(spread), PS(maxSpread)); return; }
     }

//--- [17] ADAPTIV BUFFER ------------------------------------------------
   double bufferPx = GetBufferPrice(spread);

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

   if(InpMaxEntryDistPct > 0.0)
     {
      double maxEntryDist = g_rangeWidth * InpMaxEntryDistPct / 100.0;
      if(entryDist > maxEntryDist)
        {
         PrintFormat("[FILTR] KECH KIRISH | %s | masofa=%s > ruxsat=%s",
                     (isBuy ? "BUY" : "SELL"), PS(entryDist), PS(maxEntryDist));
         return;
        }
     }

   double riskDist = MathAbs(entry - slPrice);
   if(riskDist <= 0.0) { Print("[XATO] riskDist <= 0"); return; }

//--- [20] SPREAD / RISK NISBATI -----------------------------------------
   if(InpMaxSpreadVsRiskPct > 0.0)
     {
      double ratio = spread / riskDist * 100.0;
      if(ratio > InpMaxSpreadVsRiskPct)
        {
         PrintFormat("[FILTR] RAD: spread SL masofasining %.1f%% ini yeydi "
                     "(max %.1f%%). Spread=%s, SL=%s",
                     ratio, InpMaxSpreadVsRiskPct, PS(spread), PS(riskDist));
         return;
        }
     }

   if(g_stopsLevelPx > 0.0 && riskDist < g_stopsLevelPx)
     {
      PrintFormat("[FILTR] SL STOPS_LEVEL dan yaqin: %s < %s",
                  PS(riskDist), PS(g_stopsLevelPx));
      return;
     }

   double lot = CalcLot(riskDist);
   if(lot <= 0.0) { Print("[XATO] Lot 0"); return; }
   if(!HasEnoughMargin(isBuy, lot, entry)) return;

   double tpPrice = isBuy ? entry + riskDist * InpRR_Ratio
                          : entry - riskDist * InpRR_Ratio;
   slPrice = NP(slPrice);
   tpPrice = NP(tpPrice);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskMoney = 0.0;
   if(tickValue > 0.0 && tickSize > 0.0)
      riskMoney = (riskDist / tickSize) * tickValue * lot;

   PrintFormat("┌─ SIGNAL: %s ────────────────────────────────────", (isBuy ? "BUY" : "SELL"));
   PrintFormat("│  Range .......... %s — %s  (kenglik %s)",
               PS(g_rangeLow), PS(g_rangeHigh), PS(g_rangeWidth));
   PrintFormat("│  Entry .......... %s  (leveldan %s)", PS(entry), PS(entryDist));
   PrintFormat("│  Spread / buffer  %s / %s", PS(spread), PS(bufferPx));
   PrintFormat("│  SL ............. %s  (masofa %s)", PS(slPrice), PS(riskDist));
   PrintFormat("│  TP ............. %s  (RR %.2f)", PS(tpPrice), InpRR_Ratio);
   PrintFormat("│  Lot ............ %.2f  (risk ~ %.2f %s)",
               lot, riskMoney, AccountInfoString(ACCOUNT_CURRENCY));
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
   if(!g_rangeApproved)                        return;   // [18] range filtri
   if(FindOurPosition() != 0)                  return;
   if(!DailyLimitsOK())                        return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour < InpSessionHour || tm.hour >= InpSessionEndHour) return;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close1 <= 0.0) return;

   bool wantBuy  = (close1 > g_rangeHigh);
   bool wantSell = (close1 < g_rangeLow);
   if(!wantBuy && !wantSell) return;

//--- [19][21] BREAKOUT SIFATI -------------------------------------------
   if(!ApproveBreakout(wantBuy, close1)) return;

   TryOpenTrade(wantBuy);
  }
//+------------------------------------------------------------------+
