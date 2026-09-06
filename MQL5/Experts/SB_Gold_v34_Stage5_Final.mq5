//+------------------------------------------------------------------+
//|                                 SB_Gold_v34_Stage5_Final.mq5     |
//|                  Asian Session Range Breakout — XAUUSD           |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  BOSQICH 5 / 5 :  BARQARORLIK + VIZUALIZATSIYA (FINAL)   ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  Bosqich 1+2+3+4 ning HAMMASI + quyidagilar:                     |
//|                                                                  |
//|  [29] RANGE ENDI QAT'IY TF DAN QURILADI (CopyRates).             |
//|       Eski kodda chart TF ishlatilardi: H2/H4/D1 da 06:00 yoki   |
//|       04:00 bari 07:00 dan KEYINGI harakatni ham qamrab olardi   |
//|       -> range sun'iy kengayardi -> SL noto'g'ri.                |
//|       Endi chart TF qanday bo'lishidan qat'i nazar range         |
//|       aniq M5 (yoki tanlangan TF) dan quriladi.                  |
//|                                                                  |
//|  [30] YARIM TUNNI KESIB O'TUVCHI SESSIYA qo'llab-quvvatlanadi.   |
//|       GMT-5 brokerda Osiyo sessiyasi 19:00-04:00 bo'ladi —       |
//|       eski kod bunda JIMGINA hech qachon savdo qilmasdi.         |
//|                                                                  |
//|  [31] TIMEFRAME VALIDATSIYASI + broker GMT offseti hisoboti.     |
//|                                                                  |
//|  [32] TO'LIQ INPUT VALIDATSIYASI — noto'g'ri sozlama bilan       |
//|       EA umuman ishga tushmaydi (jimgina ishlamay turmaydi).     |
//|                                                                  |
//|  [33] SAVDO RUXSATLARI TEKSHIRUVI (terminal / EA / hisob /       |
//|       simvol rejimi).                                            |
//|                                                                  |
//|  [34] HAFTA KUNI FILTRI. Dushanba (gapdan keyingi ishonchsiz     |
//|       range) va Juma (hafta oxiri riski) ni o'chirish mumkin.    |
//|                                                                  |
//|  [35] CHARTDA VIZUALIZATSIYA: range qutisi, SL levellari,        |
//|       savdo oynasi. Backtest tahlili uchun juda foydali.         |
//|                                                                  |
//|  [36] JONLI DASHBOARD — barcha holat bir ekranda.                |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Stage 5 FINAL"
#property version   "3.40"
#property description "BOSQICH 5/5: Qat'iy TF range, yarim tun sessiyalari,"
#property description "to'liq validatsiya, hafta kuni filtri, vizualizatsiya."

#include <Trade\Trade.mqh>

CTrade trade;

//==================================================================//
//                            INPUTLAR                              //
//==================================================================//
input group "════════ Sessiya vaqtlari (BROKER SERVER vaqti) ════════"
input int             InpAsianStartHour    = 0;          // Asian range boshlanishi (soat)
input int             InpAsianEndHour      = 7;          // Asian range tugashi (soat)
input int             InpSessionHour       = 8;          // Savdo oynasi boshlanishi (soat)
input int             InpSessionEndHour    = 11;         // Savdo oynasi tugashi (soat)
input ENUM_TIMEFRAMES InpRangeTF           = PERIOD_M5;  // Range quriladigan TF (M1..H1)

input group "════════ HAFTA KUNI FILTRI  [BOSQICH 5] ════════"
input bool     InpTradeMonday       = true;   // Dushanba
input bool     InpTradeTuesday      = true;   // Seshanba
input bool     InpTradeWednesday    = true;   // Chorshanba
input bool     InpTradeThursday     = true;   // Payshanba
input bool     InpTradeFriday       = true;   // Juma

input group "════════ Savdo parametrlari ════════"
input double   InpLotSize           = 0.10;   // Lot hajmi (qat'iy)
input double   InpRR_Ratio          = 2.0;    // Risk/Reward nisbati
input int      InpMagicNumber       = 100003; // Magic number

input group "════════ POZITSIYA BOSHQARUVI  [BOSQICH 4] ════════"
input bool     InpUseBreakEven      = true;   // Break-even
input double   InpBE_TriggerR       = 1.0;    // BE ishga tushish (R)
input double   InpBE_LockR          = 0.15;   // BE da qulflanadigan foyda (R)
input bool     InpUseTrailing       = true;   // Trailing stop
input double   InpTrailStartR       = 1.5;    // Trailing boshlanishi (R)
input double   InpTrailDistR        = 0.75;   // Trailing masofasi (R)
input int      InpTrailStepPoints   = 20;     // Min SL qadami (punkt)

input group "════════ QISMAN YOPISH  [BOSQICH 4] ════════"
input bool     InpUsePartialClose   = false;  // Qisman yopish
input double   InpPartialAtR        = 1.0;    // Qisman yopish nuqtasi (R)
input double   InpPartialPct        = 50.0;   // Yopiladigan hajm (%)

input group "════════ VAQT BO'YICHA CHIQISH  [BOSQICH 4] ════════"
input bool     InpUseTimeExit       = true;   // Vaqt bo'yicha chiqish
input int      InpForceCloseHour    = 20;     // Majburiy yopish soati
input bool     InpCloseBeforeWeekend= true;   // Juma majburiy yopish
input int      InpFridayCloseHour   = 18;     // Juma yopish soati
input int      InpMaxHoldHours      = 0;      // Max ushlab turish (soat, 0 = o'chiq)

input group "════════ RANGE FILTRI  [BOSQICH 3] ════════"
input bool     InpUseRangeFilter    = true;   // Range kengligi filtri
input int      InpATR_DailyPeriod   = 20;     // Kunlik ATR davri
input double   InpMinRangeATR       = 0.35;   // Min range = ATR(D1) x
input double   InpMaxRangeATR       = 1.50;   // Max range = ATR(D1) x

input group "════════ BREAKOUT SIFATI  [BOSQICH 3] ════════"
input double   InpMinBreakPct       = 5.0;    // Min penetratsiya (range %)
input double   InpMinBodyPct        = 35.0;   // Min bar tanasi (%)
input int      InpMaxBarsSinceBreak = 3;      // Max bar breakoutdan keyin
input double   InpMaxSpreadVsRiskPct= 8.0;    // Spread / SL max %

input group "════════ ADAPTIV SL BUFFER  [BOSQICH 3] ════════"
input bool     InpUseATR_Buffer     = true;   // ATR asosida buffer
input int      InpATR_BufPeriod     = 14;     // ATR davri (joriy TF)
input double   InpATR_BufMult       = 0.35;   // Buffer = ATR x
input double   InpMinBufSpreadMult  = 2.0;    // Buffer >= spread x
input int      InpSL_BufferPoints   = 50;     // Qat'iy buffer (punkt)

input group "════════ RISK NAZORATI  [BOSQICH 2] ════════"
input bool     InpUseRiskSizing     = false;  // Risk asosida lot
input double   InpRiskPercent       = 1.0;    // Savdoga risk (%)
input double   InpMaxLotCap         = 1.00;   // Lot chegarasi
input int      InpMaxTradesPerDay   = 1;      // Kuniga max savdo
input double   InpMaxDailyLossPct   = 3.0;    // Kunlik max zarar %
input double   InpMaxMarginUsePct   = 30.0;   // Bo'sh marjadan max %

input group "════════ SL MEXANIKASI  [BOSQICH 1] ════════"
input double   InpMaxEntryDistPct   = 30.0;   // Max kirish masofasi (range %)
input bool     InpAddSpreadToSellSL = true;   // SELL SL ga spread qo'shish
input bool     InpVerifyStops       = true;   // SL/TP tekshiruvi
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa yopish

input group "════════ Ijro sifati ════════"
input int      InpSlippagePoints    = 50;     // Slippage (punkt)
input int      InpMaxSpreadPoints   = 60;     // Max spread (punkt)
input bool     InpAutoAdjustPoints  = true;   // 3/5-digit punkt x10
input bool     InpVerboseLog        = true;   // Batafsil log

input group "════════ VIZUALIZATSIYA  [BOSQICH 5] ════════"
input bool     InpShowOnChart       = true;   // Chartda range va levellarni chizish
input bool     InpShowDashboard     = true;   // Ekranda holat paneli
input color    InpRangeColor        = clrSteelBlue;   // Range qutisi rangi
input color    InpBuySLColor        = clrTomato;      // BUY SL chizig'i
input color    InpSellSLColor       = clrTomato;      // SELL SL chizig'i

//==================================================================//
//                        GLOBAL O'ZGARUVCHILAR                     //
//==================================================================//
double   g_rangeHigh      = 0.0;
double   g_rangeLow       = 0.0;
double   g_rangeWidth     = 0.0;
datetime g_lastRangeDate  = 0;
datetime g_rangeFrom      = 0;
datetime g_rangeTo        = 0;
bool     g_rangeApproved  = false;
string   g_rangeReject    = "";

double   g_pipSize        = 0.0;
double   g_pointMult      = 1.0;
double   g_stopsLevelPx   = 0.0;
double   g_freezeLevelPx  = 0.0;
double   g_serverGMT      = 0.0;
ENUM_TIMEFRAMES g_rangeTF = PERIOD_M5;   // InpRangeTF, PERIOD_CURRENT hal qilingan

datetime g_blockedDay     = 0;
string   g_blockReason    = "";

int      g_atrDailyH      = INVALID_HANDLE;
int      g_atrBufH        = INVALID_HANDLE;

ulong    g_prevTicket     = 0;

const string OBJ_PREFIX = "SBG_";

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

//--- [30] Yarim tunni kesib o'tishni qo'llab-quvvatlaydigan oyna -----
bool InHourWindow(const int h, const int startH, const int endH)
  {
   if(startH == endH) return false;
   if(startH <  endH) return (h >= startH && h < endH);
   return (h >= startH || h < endH);           // 22:00 -> 03:00 kabi
  }

//--- Range oynasining aniq vaqtlari ----------------------------------
void GetRangeWindow(const datetime todayMidnight, datetime &from, datetime &to)
  {
   if(InpAsianEndHour > InpAsianStartHour)
     {
      from = todayMidnight + InpAsianStartHour * 3600;
      to   = todayMidnight + InpAsianEndHour   * 3600;
     }
   else
     {
      //  [30] Oyna yarim tunni kesib o'tadi: kechagi start -> bugungi end
      from = todayMidnight - 86400 + InpAsianStartHour * 3600;
      to   = todayMidnight + InpAsianEndHour * 3600;
     }
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

double ReadATR(const int handle, const int shift = 1)
  {
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return 0.0;
   if(buf[0] <= 0.0 || !MathIsValidNumber(buf[0])) return 0.0;
   return buf[0];
  }

//--- [34] Hafta kuni filtri -------------------------------------------
bool DayAllowed(const int dow)
  {
   switch(dow)
     {
      case 1: return InpTradeMonday;
      case 2: return InpTradeTuesday;
      case 3: return InpTradeWednesday;
      case 4: return InpTradeThursday;
      case 5: return InpTradeFriday;
     }
   return false;   // Shanba (6) / Yakshanba (0)
  }

string DayName(const int dow)
  {
   switch(dow)
     {
      case 0: return "Yakshanba";
      case 1: return "Dushanba";
      case 2: return "Seshanba";
      case 3: return "Chorshanba";
      case 4: return "Payshanba";
      case 5: return "Juma";
      case 6: return "Shanba";
     }
   return "?";
  }

//--- [33] Savdo ruxsatlari (log spamiga yo'l qo'ymaydi) ---------------
bool TradingAllowed()
  {
   static string lastReason = "";
   string reason = "";

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      reason = "Terminalda avto-savdo O'CHIQ (AutoTrading tugmasi)";
   else if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      reason = "EA sozlamalarida savdo O'CHIQ";
   else if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      reason = "Hisobda savdo taqiqlangan";
   else if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      reason = "Hisobda EA savdosi taqiqlangan";
   else
     {
      long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
      if(mode == SYMBOL_TRADE_MODE_DISABLED)   reason = "Simvolda savdo o'chiq";
      if(mode == SYMBOL_TRADE_MODE_CLOSEONLY)  reason = "Simvolda faqat yopish mumkin";
     }

   if(reason == "")
     {
      if(lastReason != "") { Print("[RUXSAT] Savdo qayta yoqildi"); lastReason = ""; }
      return true;
     }

   if(lastReason != reason)
     {
      lastReason = reason;
      Print("[RUXSAT] SAVDO MUMKIN EMAS: ", reason);
     }
   return false;
  }

//==================================================================//
//                GLOBALVARIABLE — BOSHLANG'ICH SL                  //
//==================================================================//
string GVPrefix()                   { return "SBG_" + IntegerToString(InpMagicNumber) + "_"; }
string GVSLName(const ulong ticket) { return GVPrefix() + IntegerToString((long)ticket); }
string GVPPName(const ulong ticket) { return GVSLName(ticket) + "_P"; }

void   StoreInitialSL(const ulong t, const double sl) { GlobalVariableSet(GVSLName(t), sl); }
bool   HasInitialSL  (const ulong t)                  { return GlobalVariableCheck(GVSLName(t)); }
double GetInitialSL  (const ulong t)                  { return GlobalVariableGet(GVSLName(t)); }
void   MarkPartialDone(const ulong t)                 { GlobalVariableSet(GVPPName(t), 1.0); }
bool   IsPartialDone (const ulong t)                  { return GlobalVariableCheck(GVPPName(t)); }

void CleanupGV()
  {
   string prefix = GVPrefix();
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
     {
      string n = GlobalVariableName(i);
      if(StringFind(n, prefix) == 0) GlobalVariableDel(n);
     }
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
            g_blockedDay  = today;
            g_blockReason = StringFormat("Savdo limiti %d/%d", done, InpMaxTradesPerDay);
            Print("[LIMIT] ", g_blockReason);
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
                  g_blockedDay  = today;
                  g_blockReason = StringFormat("Kunlik zarar %.2f%% >= %.2f%%",
                                               lossPct, InpMaxDailyLossPct);
                  Print("[LIMIT] ", g_blockReason);
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
         PrintFormat("[LOT] %.2f -> %.2f (VOLUME_STEP)", InpLotSize, v);
      return v;
     }

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0 || riskDist <= 0.0)
     { Print("[LOT][XATO] tick ma'lumoti yo'q"); return NormalizeVolume(InpLotSize); }

   double lossPerLot = (riskDist / tickSize) * tickValue;
   if(lossPerLot <= 0.0) return NormalizeVolume(InpLotSize);

   double lot = riskMoney / lossPerLot;
   if(InpMaxLotCap > 0.0 && lot > InpMaxLotCap) lot = InpMaxLotCap;
   double result = NormalizeVolume(lot);

   PrintFormat("[LOT] Balans=%.2f Risk=%.2f SL=%s -> LOT=%.2f (haqiqiy risk %.2f)",
               balance, riskMoney, PS(riskDist), result, result * lossPerLot);
   return result;
  }

bool HasEnoughMargin(const bool isBuy, const double lot, const double price)
  {
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, _Symbol, lot, price, margin)) return true;

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
//              FILTRLAR (Bosqich 3)                                //
//==================================================================//
double GetBufferPrice(const double spread)
  {
   double buf;
   if(InpUseATR_Buffer)
     {
      double atr = ReadATR(g_atrBufH, 1);
      if(atr > 0.0) buf = atr * InpATR_BufMult;
      else          buf = InpSL_BufferPoints * g_pipSize;
     }
   else
      buf = InpSL_BufferPoints * g_pipSize;

   double minBuf = spread * InpMinBufSpreadMult;
   if(buf < minBuf) buf = minBuf;
   return buf;
  }

bool ApproveRangeWidth()
  {
   g_rangeReject = "";
   if(!InpUseRangeFilter) return true;

   double atrD = ReadATR(g_atrDailyH, 1);
   if(atrD <= 0.0)
     { Print("[RANGE-FILTR][OGOH] ATR(D1) yo'q — filtr o'tkazib yuborildi"); return true; }

   double minW = atrD * InpMinRangeATR;
   double maxW = atrD * InpMaxRangeATR;

   if(g_rangeWidth < minW)
     {
      g_rangeReject = StringFormat("juda TOR (%s < %s)", PS(g_rangeWidth), PS(minW));
      PrintFormat("[RANGE-FILTR] RAD: %s  ATR(D1)=%s", g_rangeReject, PS(atrD));
      return false;
     }
   if(g_rangeWidth > maxW)
     {
      g_rangeReject = StringFormat("juda KENG (%s > %s)", PS(g_rangeWidth), PS(maxW));
      PrintFormat("[RANGE-FILTR] RAD: %s  ATR(D1)=%s", g_rangeReject, PS(atrD));
      return false;
     }

   PrintFormat("[RANGE-FILTR] QABUL: %s (ruxsat %s-%s, ATR(D1)=%s, nisbat %.2f)",
               PS(g_rangeWidth), PS(minW), PS(maxW), PS(atrD), g_rangeWidth / atrD);
   return true;
  }

bool ApproveBreakout(const bool isBuy, const double close1)
  {
   if(InpMinBreakPct > 0.0)
     {
      double need = g_rangeWidth * InpMinBreakPct / 100.0;
      double pen  = isBuy ? (close1 - g_rangeHigh) : (g_rangeLow - close1);
      if(pen < need)
        { PrintFormat("[BREAK] RAD: penetratsiya %s < %s", PS(pen), PS(need)); return false; }
     }

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
           { PrintFormat("[BREAK] RAD: tana %.1f%% < %.1f%%", bodyPct, InpMinBodyPct); return false; }
         if(isBuy != (c > o))
           { Print("[BREAK] RAD: bar yo'nalishi mos emas"); return false; }
        }
     }

   if(InpMaxBarsSinceBreak > 0)
     {
      int barsOutside = 0;
      for(int i = 1; i <= InpMaxBarsSinceBreak + 1; i++)
        {
         double c = iClose(_Symbol, PERIOD_CURRENT, i);
         if(c <= 0.0) break;
         if(!(isBuy ? (c > g_rangeHigh) : (c < g_rangeLow))) break;
         barsOutside++;
        }
      if(barsOutside > InpMaxBarsSinceBreak)
        {
         PrintFormat("[BREAK] RAD: signal eskirgan (%d > %d bar)",
                     barsOutside, InpMaxBarsSinceBreak);
         return false;
        }
     }
   return true;
  }

//==================================================================//
//              VAQT BO'YICHA CHIQISH (Bosqich 4)                   //
//==================================================================//
bool CheckTimeExit(const ulong ticket)
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   string reason = "";

   if(InpCloseBeforeWeekend && tm.day_of_week == 5 && tm.hour >= InpFridayCloseHour)
      reason = StringFormat("JUMA yopish %02d:00 — hafta oxiri gap riski", InpFridayCloseHour);

   if(reason == "" && InpUseTimeExit && tm.hour >= InpForceCloseHour)
      reason = StringFormat("Kunlik yopish %02d:00 — tungi gap riski", InpForceCloseHour);

   if(reason == "" && InpMaxHoldHours > 0)
     {
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      long heldSec = (long)(TimeCurrent() - openTime);
      if(heldSec >= (long)InpMaxHoldHours * 3600)
         reason = StringFormat("Max ushlash %.1f soat >= %d", heldSec / 3600.0, InpMaxHoldHours);
     }

   if(reason == "") return false;

   PrintFormat("[VAQT-CHIQISH] %s | P/L=%.2f", reason, PositionGetDouble(POSITION_PROFIT));

   if(!trade.PositionClose(ticket))
     {
      PrintFormat("[XATO] Yopilmadi | retcode=%d | %s",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return false;
     }
   CleanupGV();
   g_prevTicket = 0;
   return true;
  }

//==================================================================//
//              POZITSIYA BOSHQARUVI (Bosqich 4)                    //
//==================================================================//
void ManageOpenPosition()
  {
   ulong ticket = FindOurPosition();
   if(ticket == 0)
     {
      if(g_prevTicket != 0) { CleanupGV(); g_prevTicket = 0; }
      return;
     }
   g_prevTicket = ticket;

   if(CheckTimeExit(ticket)) return;

   bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double vol   = PositionGetDouble(POSITION_VOLUME);

   double initSL;
   if(HasInitialSL(ticket))
      initSL = GetInitialSL(ticket);
   else
     {
      double fallbackRisk = (g_rangeWidth > 0.0) ? g_rangeWidth : MathAbs(entry - curSL);
      initSL = isBuy ? (entry - fallbackRisk) : (entry + fallbackRisk);
      StoreInitialSL(ticket, initSL);
      PrintFormat("[BOSHQARUV][OGOH] Boshlang'ich SL tiklandi (taxminan): %s", PS(initSL));
     }

   double initRisk = MathAbs(entry - initSL);
   if(initRisk <= 0.0) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0) return;

   double curPrice = isBuy ? tick.bid : tick.ask;
   double profitR  = (isBuy ? (curPrice - entry) : (entry - curPrice)) / initRisk;

//--- qisman yopish ----------------------------------------------------
   if(InpUsePartialClose && profitR >= InpPartialAtR && !IsPartialDone(ticket))
     {
      double vmin     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double closeVol = NormalizeVolume(vol * InpPartialPct / 100.0);
      double remain   = vol - closeVol;

      if(closeVol >= vmin && remain >= vmin)
        {
         if(trade.PositionClosePartial(ticket, closeVol))
           {
            MarkPartialDone(ticket);
            PrintFormat("[QISMAN] +%.2fR: %.2f lot yopildi (qoldi %.2f)",
                        profitR, closeVol, remain);
           }
         else
            PrintFormat("[XATO] Qisman yopilmadi | retcode=%d", trade.ResultRetcode());
        }
      else
        {
         MarkPartialDone(ticket);
         PrintFormat("[QISMAN] Imkonsiz: hajm kichik (%.2f, min %.2f)", vol, vmin);
        }
      return;
     }

//--- break-even / trailing --------------------------------------------
   double newSL = curSL;
   string what  = "";

   if(InpUseBreakEven && profitR >= InpBE_TriggerR)
     {
      double beSL = isBuy ? (entry + initRisk * InpBE_LockR)
                          : (entry - initRisk * InpBE_LockR);
      if(isBuy) { if(beSL > newSL)                    { newSL = beSL; what = "BREAK-EVEN"; } }
      else      { if(newSL <= 0.0 || beSL < newSL)    { newSL = beSL; what = "BREAK-EVEN"; } }
     }

   if(InpUseTrailing && profitR >= InpTrailStartR)
     {
      double trSL = isBuy ? (curPrice - initRisk * InpTrailDistR)
                          : (curPrice + initRisk * InpTrailDistR);
      if(isBuy) { if(trSL > newSL)                    { newSL = trSL; what = "TRAILING"; } }
      else      { if(newSL <= 0.0 || trSL < newSL)    { newSL = trSL; what = "TRAILING"; } }
     }

   if(what == "") return;
   newSL = NP(newSL);

   double minStep = MathMax(_Point, InpTrailStepPoints * g_pipSize);
   bool improved  = isBuy ? (newSL > curSL + minStep) : (newSL < curSL - minStep);
   if(!improved) return;

   if(isBuy  && newSL >= tick.bid) return;
   if(!isBuy && newSL <= tick.ask) return;

   double distToPrice = isBuy ? (tick.bid - newSL) : (newSL - tick.ask);
   if(g_stopsLevelPx  > 0.0 && distToPrice < g_stopsLevelPx)  return;
   if(g_freezeLevelPx > 0.0 && distToPrice < g_freezeLevelPx) return;

   if(trade.PositionModify(ticket, newSL, curTP))
      PrintFormat("[%s] +%.2fR | SL: %s -> %s (entry=%s, 1R=%s)",
                  what, profitR, PS(curSL), PS(newSL), PS(entry), PS(initRisk));
   else
      PrintFormat("[XATO] %s SL ko'chirilmadi | retcode=%d | %s",
                  what, trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

//==================================================================//
//     [29] RANGE NI QAT'IY TF DAN QURISH (chart TF dan mustaqil)   //
//==================================================================//
bool ExtractRange(const ENUM_TIMEFRAMES tf, const datetime from, const datetime to,
                  double &hi, double &lo, int &cnt)
  {
   MqlRates r[];
   ArraySetAsSeries(r, false);

   int n = CopyRates(_Symbol, tf, from, to - 1, r);
   if(n <= 0) return false;

   cnt = 0; hi = 0.0; lo = 0.0;
   for(int i = 0; i < n; i++)
     {
      if(r[i].time < from || r[i].time >= to) continue;   // oynadan tashqari
      if(r[i].high <= 0.0 || r[i].low <= 0.0) continue;
      if(cnt == 0) { hi = r[i].high; lo = r[i].low; }
      else
        {
         if(r[i].high > hi) hi = r[i].high;
         if(r[i].low  < lo) lo = r[i].low;
        }
      cnt++;
     }
   return (cnt > 0 && hi > lo);
  }

void BuildAsianRange()
  {
   datetime todayMidnight = TodayMidnight();

   if(g_lastRangeDate != todayMidnight && g_rangeHigh > 0.0)
     {
      g_rangeHigh = 0.0; g_rangeLow = 0.0; g_rangeWidth = 0.0;
      g_rangeApproved = false; g_rangeReject = "";
      DeleteChartObjects();
      Log("[RANGE] Yangi kun — eski range tozalandi");
     }

   if(g_lastRangeDate == todayMidnight) return;

   datetime from, to;
   GetRangeWindow(todayMidnight, from, to);
   if(TimeCurrent() < to) return;                 // oyna hali tugamagan

   double hi = 0.0, lo = 0.0;
   int    cnt = 0;

   if(!ExtractRange(g_rangeTF, from, to, hi, lo, cnt))
     {
      static datetime lastWarnDay = 0;
      if(lastWarnDay != todayMidnight)
        {
         lastWarnDay = todayMidnight;
         PrintFormat("[RANGE][XATO] Range QURILMADI! TF=%s, oyna %s - %s, bar=%d. "
                     "Sabab: tarix yetishmayapti yoki bayram. Bugun savdo yo'q.",
                     EnumToString(g_rangeTF),
                     TimeToString(from, TIME_DATE | TIME_MINUTES),
                     TimeToString(to,   TIME_DATE | TIME_MINUTES), cnt);
        }
      return;
     }

   g_rangeHigh     = hi;
   g_rangeLow      = lo;
   g_rangeWidth    = hi - lo;
   g_rangeFrom     = from;
   g_rangeTo       = to;
   g_lastRangeDate = todayMidnight;

   PrintFormat("[RANGE] %s  %s-%s  High=%s Low=%s Kenglik=%s  (%s, %d bar)",
               TimeToString(todayMidnight, TIME_DATE),
               TimeToString(from, TIME_MINUTES), TimeToString(to, TIME_MINUTES),
               PS(g_rangeHigh), PS(g_rangeLow), PS(g_rangeWidth),
               EnumToString(g_rangeTF), cnt);

   g_rangeApproved = ApproveRangeWidth();

   if(InpShowOnChart) DrawRange();
  }

//==================================================================//
//              [35] CHARTDA VIZUALIZATSIYA                         //
//==================================================================//
void DeleteChartObjects()
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw();
  }

void DrawRange()
  {
   if(g_rangeHigh <= 0.0 || g_rangeLow <= 0.0) return;

   DeleteChartObjects();

   datetime todayMidnight = TodayMidnight();
   datetime sessEnd = todayMidnight + InpSessionEndHour * 3600;
   if(sessEnd <= g_rangeTo) sessEnd = g_rangeTo + 4 * 3600;

//--- range qutisi ------------------------------------------------------
   string box = OBJ_PREFIX + "box";
   if(ObjectCreate(0, box, OBJ_RECTANGLE, 0, g_rangeFrom, g_rangeHigh, g_rangeTo, g_rangeLow))
     {
      ObjectSetInteger(0, box, OBJPROP_COLOR,     InpRangeColor);
      ObjectSetInteger(0, box, OBJPROP_FILL,      true);
      ObjectSetInteger(0, box, OBJPROP_BACK,      true);
      ObjectSetInteger(0, box, OBJPROP_SELECTABLE,false);
     }

//--- range chegaralari savdo oynasi oxirigacha cho'ziladi -------------
   string hiLine = OBJ_PREFIX + "high";
   if(ObjectCreate(0, hiLine, OBJ_TREND, 0, g_rangeFrom, g_rangeHigh, sessEnd, g_rangeHigh))
     {
      ObjectSetInteger(0, hiLine, OBJPROP_COLOR,      InpRangeColor);
      ObjectSetInteger(0, hiLine, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, hiLine, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, hiLine, OBJPROP_SELECTABLE, false);
     }
   string loLine = OBJ_PREFIX + "low";
   if(ObjectCreate(0, loLine, OBJ_TREND, 0, g_rangeFrom, g_rangeLow, sessEnd, g_rangeLow))
     {
      ObjectSetInteger(0, loLine, OBJPROP_COLOR,      InpRangeColor);
      ObjectSetInteger(0, loLine, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, loLine, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, loLine, OBJPROP_SELECTABLE, false);
     }

//--- SL levellari (eng muhim vizual ma'lumot) -------------------------
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buf    = GetBufferPrice(spread);
   double buySL  = g_rangeLow  - buf;
   double sellSL = g_rangeHigh + buf + (InpAddSpreadToSellSL ? spread : 0.0);

   string bsl = OBJ_PREFIX + "buysl";
   if(ObjectCreate(0, bsl, OBJ_TREND, 0, g_rangeTo, buySL, sessEnd, buySL))
     {
      ObjectSetInteger(0, bsl, OBJPROP_COLOR,      InpBuySLColor);
      ObjectSetInteger(0, bsl, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, bsl, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, bsl, OBJPROP_SELECTABLE, false);
     }
   string ssl = OBJ_PREFIX + "sellsl";
   if(ObjectCreate(0, ssl, OBJ_TREND, 0, g_rangeTo, sellSL, sessEnd, sellSL))
     {
      ObjectSetInteger(0, ssl, OBJPROP_COLOR,      InpSellSLColor);
      ObjectSetInteger(0, ssl, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, ssl, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, ssl, OBJPROP_SELECTABLE, false);
     }

//--- matn yorlig'i -----------------------------------------------------
   string lbl = OBJ_PREFIX + "lbl";
   if(ObjectCreate(0, lbl, OBJ_TEXT, 0, g_rangeTo, g_rangeHigh))
     {
      ObjectSetString (0, lbl, OBJPROP_TEXT,
                       StringFormat(" %s  %s", PS(g_rangeWidth),
                                    (g_rangeApproved ? "OK" : "RAD: " + g_rangeReject)));
      ObjectSetInteger(0, lbl, OBJPROP_COLOR,      (g_rangeApproved ? clrLime : clrOrangeRed));
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE,   9);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR,     ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
     }

   ChartRedraw();
  }

//==================================================================//
//              [36] DASHBOARD                                      //
//==================================================================//
void UpdateDashboard()
  {
   if(!InpShowDashboard) return;

//--- optimizatsiya/tester da panel keraksiz va SEKINLASHTIRADI --------
//    (CountTodayEntries/TodayRealizedPL har safar tarixni skanerlaydi)
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

   static datetime lastUpd = 0;
   if(TimeCurrent() == lastUpd) return;      // sekundiga bir marta
   lastUpd = TimeCurrent();

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   MqlTick tick;
   ZeroMemory(tick);
   bool   haveTick = SymbolInfoTick(_Symbol, tick);
   double spread   = (haveTick ? (tick.ask - tick.bid) : 0.0);

   double atrD = ReadATR(g_atrDailyH, 1);
   ulong  tk   = FindOurPosition();

   string s = "";
   s += "╔══════════════════════════════════════════════╗\n";
   s += "║  SESSION BREAKOUT GOLD  v3.40  (Bosqich 5/5) ║\n";
   s += "╚══════════════════════════════════════════════╝\n";
   s += StringFormat(" Server vaqti : %s  (%s)\n",
                     TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                     DayName(tm.day_of_week));
   s += StringFormat(" Simvol / TF  : %s / %s   (range: %s)\n",
                     _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()),
                     EnumToString(g_rangeTF));
   s += StringFormat(" Spread       : %s   Buffer: %s\n",
                     PS(spread), PS(GetBufferPrice(spread)));
   s += "──────────────────────────────────────────────\n";

   if(g_rangeHigh > 0.0)
     {
      s += StringFormat(" RANGE        : %s — %s\n", PS(g_rangeLow), PS(g_rangeHigh));
      s += StringFormat(" Kenglik      : %s", PS(g_rangeWidth));
      if(atrD > 0.0) s += StringFormat("   (ATR D1 ning %.2f x)", g_rangeWidth / atrD);
      s += "\n";
      s += StringFormat(" Holat        : %s\n",
                        (g_rangeApproved ? "QABUL QILINDI" : "RAD: " + g_rangeReject));
      s += StringFormat(" BUY SL       : %s\n",
                        PS(g_rangeLow - GetBufferPrice(spread)));
      s += StringFormat(" SELL SL      : %s\n",
                        PS(g_rangeHigh + GetBufferPrice(spread)
                           + (InpAddSpreadToSellSL ? spread : 0.0)));
     }
   else
      s += " RANGE        : hali qurilmagan\n";

   s += "──────────────────────────────────────────────\n";
   bool inWindow = InHourWindow(tm.hour, InpSessionHour, InpSessionEndHour);
   s += StringFormat(" Savdo oynasi : %02d:00-%02d:00  [%s]\n",
                     InpSessionHour, InpSessionEndHour, (inWindow ? "OCHIQ" : "yopiq"));
   s += StringFormat(" Kun ruxsati  : %s\n",
                     (DayAllowed(tm.day_of_week) ? "ha" : "YO'Q (filtr)"));
   s += StringFormat(" Bugungi savdo: %d / %s     P/L: %.2f\n",
                     CountTodayEntries(),
                     (InpMaxTradesPerDay > 0 ? IntegerToString(InpMaxTradesPerDay) : "inf"),
                     TodayRealizedPL());
   if(g_blockedDay == TodayMidnight() && g_blockReason != "")
      s += StringFormat(" BLOKLANGAN   : %s\n", g_blockReason);

   s += "──────────────────────────────────────────────\n";
   if(tk != 0 && haveTick)
     {
      bool   isBuy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double psl    = PositionGetDouble(POSITION_SL);
      double ptp    = PositionGetDouble(POSITION_TP);
      double pvol   = PositionGetDouble(POSITION_VOLUME);
      double pprof  = PositionGetDouble(POSITION_PROFIT);
      double initSL = HasInitialSL(tk) ? GetInitialSL(tk) : psl;
      double iR     = MathAbs(entry - initSL);
      double cp     = isBuy ? tick.bid : tick.ask;
      double rNow   = (iR > 0.0) ? ((isBuy ? (cp - entry) : (entry - cp)) / iR) : 0.0;

      s += StringFormat(" POZITSIYA    : %s %.2f lot\n", (isBuy ? "BUY" : "SELL"), pvol);
      s += StringFormat(" Entry / hozir: %s / %s\n", PS(entry), PS(cp));
      s += StringFormat(" SL / TP      : %s / %s\n", PS(psl), PS(ptp));
      s += StringFormat(" Natija       : %+.2f R   (%.2f %s)\n",
                        rNow, pprof, AccountInfoString(ACCOUNT_CURRENCY));
      s += StringFormat(" BE / Trail   : +%.2fR / +%.2fR  %s\n",
                        InpBE_TriggerR, InpTrailStartR,
                        (psl != initSL ? "[SL KO'CHIRILGAN]" : ""));
     }
   else if(tk != 0)
      s += " POZITSIYA    : ochiq (tik ma'lumoti yo'q)\n";
   else
      s += " POZITSIYA    : yo'q\n";

   s += "──────────────────────────────────────────────\n";
   s += StringFormat(" Lot rejimi   : %s\n",
                     (InpUseRiskSizing ? StringFormat("RISK %.2f%%", InpRiskPercent)
                                       : StringFormat("QAT'IY %.2f", InpLotSize)));
   s += StringFormat(" Balans/Equity: %.2f / %.2f\n",
                     AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY));

   Comment(s);
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
   if(ticket == 0) { Print("[OGOH] Pozitsiya topilmadi"); return; }

   double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   double actualSL    = PositionGetDouble(POSITION_SL);
   double actualTP    = PositionGetDouble(POSITION_TP);

   double slip = isBuy ? (actualEntry - plannedEntry) : (plannedEntry - actualEntry);
   if(MathAbs(slip) > _Point * 0.5)
      PrintFormat("[SLIPPAGE] Reja=%s Haqiqiy=%s Farq=%s",
                  PS(plannedEntry), PS(actualEntry), PS(MathAbs(slip)));

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

   if(needFix)
     {
      if(trade.PositionModify(ticket, wantedSL, wantedTP))
         PrintFormat("[TUZATILDI] SL=%s TP=%s (entry=%s, 1R=%s)",
                     PS(wantedSL), PS(wantedTP), PS(actualEntry), PS(realRisk));
      else
        {
         PrintFormat("[XATO] SL/TP tiklanmadi | retcode=%d | %s",
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
         if(slMissing && InpCloseIfNoSL)
           {
            Print("[HIMOYA] SL SIZ POZITSIYA — YOPILMOQDA!");
            trade.PositionClose(ticket);
            return;
           }
        }
     }
   else
      PrintFormat("[TASDIQ] SL=%s TP=%s 1R=%s OK", PS(actualSL), PS(actualTP), PS(realRisk));

   double storeSL = PositionGetDouble(POSITION_SL);
   if(storeSL <= 0.0) storeSL = wantedSL;
   StoreInitialSL(ticket, storeSL);
   g_prevTicket = ticket;
   PrintFormat("[BOSHQARUV] Boshlang'ich SL saqlandi: %s (1R = %s)",
               PS(storeSL), PS(MathAbs(actualEntry - storeSL)));
  }

//==================================================================//
//                       SAVDO OCHISHGA URINISH                     //
//==================================================================//
void TryOpenTrade(const bool isBuy)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     { Print("[XATO] Tik yo'q"); return; }

   double spread = tick.ask - tick.bid;

   if(InpMaxSpreadPoints > 0)
     {
      double maxSpread = InpMaxSpreadPoints * g_pipSize;
      if(spread > maxSpread)
        { PrintFormat("[FILTR] Spread keng: %s > %s", PS(spread), PS(maxSpread)); return; }
     }

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
         PrintFormat("[FILTR] KECH KIRISH | masofa=%s > ruxsat=%s",
                     PS(entryDist), PS(maxEntryDist));
         return;
        }
     }

   double riskDist = MathAbs(entry - slPrice);
   if(riskDist <= 0.0) return;

   if(InpMaxSpreadVsRiskPct > 0.0)
     {
      double ratio = spread / riskDist * 100.0;
      if(ratio > InpMaxSpreadVsRiskPct)
        {
         PrintFormat("[FILTR] Spread SL ning %.1f%% ini yeydi (max %.1f%%)",
                     ratio, InpMaxSpreadVsRiskPct);
         return;
        }
     }

   if(g_stopsLevelPx > 0.0 && riskDist < g_stopsLevelPx)
     { PrintFormat("[FILTR] SL STOPS_LEVEL dan yaqin: %s", PS(riskDist)); return; }

   double lot = CalcLot(riskDist);
   if(lot <= 0.0) return;
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
   PrintFormat("│  Range .......... %s — %s (%s)",
               PS(g_rangeLow), PS(g_rangeHigh), PS(g_rangeWidth));
   PrintFormat("│  Entry .......... %s (leveldan %s)", PS(entry), PS(entryDist));
   PrintFormat("│  Spread/buffer .. %s / %s", PS(spread), PS(bufferPx));
   PrintFormat("│  SL / TP ........ %s / %s  (1R = %s)",
               PS(slPrice), PS(tpPrice), PS(riskDist));
   PrintFormat("│  Lot ............ %.2f (risk ~ %.2f %s)",
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
//                            OnInit                                //
//==================================================================//
int OnInit()
  {
   g_pointMult = 1.0;
   if(InpAutoAdjustPoints && (_Digits == 3 || _Digits == 5)) g_pointMult = 10.0;
   g_pipSize = _Point * g_pointMult;

   g_stopsLevelPx  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)  * _Point;
   g_freezeLevelPx = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   g_serverGMT     = (double)(TimeTradeServer() - TimeGMT()) / 3600.0;

//--- [29] PERIOD_CURRENT ni haqiqiy TF ga aylantirish -----------------
   g_rangeTF = (InpRangeTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpRangeTF;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathRound(InpSlippagePoints * g_pointMult));
   if(!trade.SetTypeFillingBySymbol(_Symbol))
      Print("[OGOH] Filling mode aniqlanmadi");

   g_atrDailyH = iATR(_Symbol, PERIOD_D1,      InpATR_DailyPeriod);
   g_atrBufH   = iATR(_Symbol, PERIOD_CURRENT, InpATR_BufPeriod);
   if(g_atrDailyH == INVALID_HANDLE || g_atrBufH == INVALID_HANDLE)
     { Alert("XATO: ATR indikatori yaratilmadi!"); return(INIT_FAILED); }

//================ [32] TO'LIQ INPUT VALIDATSIYASI =================//
   string err = "";

   if(InpAsianStartHour < 0 || InpAsianStartHour > 23) err = "InpAsianStartHour 0-23 oralig'ida bo'lsin";
   else if(InpAsianEndHour   < 0 || InpAsianEndHour   > 23) err = "InpAsianEndHour 0-23 oralig'ida bo'lsin";
   else if(InpSessionHour    < 0 || InpSessionHour    > 23) err = "InpSessionHour 0-23 oralig'ida bo'lsin";
   else if(InpSessionEndHour < 0 || InpSessionEndHour > 23) err = "InpSessionEndHour 0-23 oralig'ida bo'lsin";
   else if(InpAsianStartHour == InpAsianEndHour) err = "Asian range oynasi bo'sh (start == end)";
   else if(InpSessionHour == InpSessionEndHour) err = "Savdo oynasi bo'sh (start == end)";
   else if(InpRR_Ratio <= 0.0) err = "InpRR_Ratio > 0 bo'lsin";
   else if(InpLotSize  <= 0.0) err = "InpLotSize > 0 bo'lsin";
   else if(InpUseRiskSizing && InpRiskPercent <= 0.0) err = "InpRiskPercent > 0 bo'lsin";
   else if(InpUseRangeFilter && InpMinRangeATR >= InpMaxRangeATR) err = "MinRangeATR < MaxRangeATR bo'lsin";
   else if(InpUseBreakEven && InpBE_LockR >= InpBE_TriggerR) err = "InpBE_LockR < InpBE_TriggerR bo'lsin";
   else if(InpUseTrailing && InpTrailDistR >= InpTrailStartR) err = "InpTrailDistR < InpTrailStartR bo'lsin";
   else if(InpUsePartialClose && (InpPartialPct <= 0.0 || InpPartialPct >= 100.0)) err = "InpPartialPct 0-100 orasida bo'lsin";
   else if(InpMaxEntryDistPct < 0.0) err = "InpMaxEntryDistPct manfiy bo'lmasin";
   else if(g_rangeTF > PERIOD_H1) err = StringFormat("Range TF (%s) M1..H1 oralig'ida bo'lsin — H2+ da 07:00 ni kesib o'tuvchi bar range ni buzadi", EnumToString(g_rangeTF));
   else if(!InpTradeMonday && !InpTradeTuesday && !InpTradeWednesday
        && !InpTradeThursday && !InpTradeFriday) err = "Hech bo'lmasa bitta hafta kuni yoqilsin";

   if(err != "")
     {
      Alert("KONFIGURATSIYA XATOSI: " + err);
      Print("[INIT][XATO] ", err);
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- vaqt chiqishi mantiqiy tekshiruvi (yarim tunni hisobga olgan) ----
   if(InpUseTimeExit && InpSessionHour < InpSessionEndHour
      && InpForceCloseHour <= InpSessionEndHour)
     {
      Alert("KONFIGURATSIYA XATOSI: InpForceCloseHour savdo oynasidan KEYIN bo'lsin");
      return(INIT_PARAMETERS_INCORRECT);
     }

//================ [31] TIMEFRAME OGOHLANTIRISHI ===================//
   if(Period() > PERIOD_H1)
      Print("╔══════════════════════════════════════════════════════════╗\n"
            "║ [OGOHLANTIRISH] Chart TF H1 dan katta!                   ║\n"
            "║ Range InpRangeTF dan to'g'ri quriladi, LEKIN kirish      ║\n"
            "║ signali chart TF ga bog'liq — savdo oynasida bar         ║\n"
            "║ deyarli bo'lmaydi. M5 yoki M15 tavsiya qilinadi.         ║\n"
            "╚══════════════════════════════════════════════════════════╝");

//======================== HISOBOT =================================//
   Print("════════════════════════════════════════════════════════");
   Print("  SESSION BREAKOUT GOLD  v3.40  —  BOSQICH 5/5 (FINAL)");
   Print("════════════════════════════════════════════════════════");
   PrintFormat("  Simvol / chart TF ... %s / %s", _Symbol,
               EnumToString((ENUM_TIMEFRAMES)Period()));
   PrintFormat("  Range TF ............ %s  (chart TF dan MUSTAQIL)",
               EnumToString(g_rangeTF));
   PrintFormat("  Digits / punkt ...... %d / x%.0f (1 punkt = %s)",
               _Digits, g_pointMult, PS(g_pipSize));
   PrintFormat("  Server GMT offset ... %+.1f soat  (server: %s, GMT: %s)",
               g_serverGMT,
               TimeToString(TimeTradeServer(), TIME_MINUTES),
               TimeToString(TimeGMT(),         TIME_MINUTES));
   PrintFormat("  Asian range ......... %02d:00 - %02d:00 %s",
               InpAsianStartHour, InpAsianEndHour,
               (InpAsianEndHour <= InpAsianStartHour ? "(YARIM TUNNI KESADI)" : ""));
   PrintFormat("  Savdo oynasi ........ %02d:00 - %02d:00 %s",
               InpSessionHour, InpSessionEndHour,
               (InpSessionEndHour <= InpSessionHour ? "(YARIM TUNNI KESADI)" : ""));
   PrintFormat("  Hafta kunlari ....... Du:%s Se:%s Cho:%s Pa:%s Ju:%s",
               (InpTradeMonday?"+":"-"), (InpTradeTuesday?"+":"-"),
               (InpTradeWednesday?"+":"-"), (InpTradeThursday?"+":"-"),
               (InpTradeFriday?"+":"-"));
   PrintFormat("  Lot rejimi .......... %s",
               (InpUseRiskSizing ? StringFormat("RISK %.2f%%", InpRiskPercent)
                                 : StringFormat("QAT'IY %.2f", InpLotSize)));
   PrintFormat("  Kunlik limit ........ %d savdo / %.2f%% zarar",
               InpMaxTradesPerDay, InpMaxDailyLossPct);
   PrintFormat("  SL buffer ........... %s",
               (InpUseATR_Buffer
                ? StringFormat("ATR(%d) x %.2f (min = spread x %.1f)",
                               InpATR_BufPeriod, InpATR_BufMult, InpMinBufSpreadMult)
                : StringFormat("qat'iy %d punkt", InpSL_BufferPoints)));
   PrintFormat("  BE / Trailing ....... +%.2fR (%.2fR qulf) / +%.2fR (%.2fR masofa)",
               InpBE_TriggerR, InpBE_LockR, InpTrailStartR, InpTrailDistR);
   PrintFormat("  Vaqt chiqishi ....... %02d:00  |  Juma: %02d:00",
               InpForceCloseHour, InpFridayCloseHour);
   PrintFormat("  STOPS / FREEZE ...... %s / %s", PS(g_stopsLevelPx), PS(g_freezeLevelPx));
   PrintFormat("  VOLUME min/max/step . %.2f / %.2f / %.2f",
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
   Print("════════════════════════════════════════════════════════");

   TradingAllowed();      // [33] boshlang'ich tekshiruv (log uchun)

   return(INIT_SUCCEEDED);
  }

//==================================================================//
void OnDeinit(const int reason)
  {
   if(g_atrDailyH != INVALID_HANDLE) IndicatorRelease(g_atrDailyH);
   if(g_atrBufH   != INVALID_HANDLE) IndicatorRelease(g_atrBufH);
   DeleteChartObjects();
   Comment("");
  }

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
  {
//--- 1) Pozitsiya boshqaruvi HAR TICKDA -------------------------------
   ManageOpenPosition();

//--- 2) Dashboard ------------------------------------------------------
   UpdateDashboard();

//--- 3) Signal mantiqi faqat yangi barda -------------------------------
   if(!NewBar()) return;

   BuildAsianRange();

   if(!TradingAllowed())                       return;   // [33]
   if(g_rangeHigh <= 0.0 || g_rangeLow <= 0.0) return;
   if(!g_rangeApproved)                        return;
   if(FindOurPosition() != 0)                  return;
   if(!DailyLimitsOK())                        return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

//--- [34] hafta kuni filtri --------------------------------------------
   if(!DayAllowed(tm.day_of_week)) return;

//--- [30] savdo oynasi (yarim tunni kesib o'tishi mumkin) ---------------
   if(!InHourWindow(tm.hour, InpSessionHour, InpSessionEndHour)) return;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close1 <= 0.0) return;

   bool wantBuy  = (close1 > g_rangeHigh);
   bool wantSell = (close1 < g_rangeLow);
   if(!wantBuy && !wantSell) return;

   if(!ApproveBreakout(wantBuy, close1)) return;

   TryOpenTrade(wantBuy);
  }
//+------------------------------------------------------------------+
