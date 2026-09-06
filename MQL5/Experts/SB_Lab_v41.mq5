//+------------------------------------------------------------------+
//|                                          SB_Lab_v41.mq5          |
//|            LABORATORIYA — barcha g'oyalarni sinash uchun          |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  MUHIM: STANDART SOZLAMALAR = SIZNING ASL KODINGIZ       ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  Barcha filtrlar O'CHIQ, SL/TP rejimi asl formulada, faqat       |
//|  1-sessiya yoqilgan. Ya'ni hech nima o'zgartirmasangiz —         |
//|  natija v2.00 bilan bir xil bo'lishi kerak.                      |
//|                                                                  |
//|  Keyin BITTA-BITTADAN yoqib/o'zgartirib test qilasiz.            |
//|  Strategy Tester ning OPTIMIZATSIYA rejimi uchun mo'ljallangan.   |
//|                                                                  |
//|  ═══════════ SINALADIGAN 3 TA ASOSIY G'OYA ═══════════           |
//|                                                                  |
//|  1) KIRISH REJIMI — PENDING STOP ORDER                           |
//|     Asl kod: bar yopilgandan KEYIN market order -> narx           |
//|     allaqachon leveldan $1-3 uzoqda. TP shuncha uzoqlashadi.      |
//|     Pending: BuyStop aynan rangeHigh+offset da turadi ->          |
//|     entry yaxshiroq, SL leveldan uzoqroq, TP yaqinroq.            |
//|     Kamchiligi: soyalarda (wick) ham ishga tushadi.               |
//|     -> InpEntryMode = ENTRY_PENDING_STOP                          |
//|                                                                  |
//|  2) SL/TP GEOMETRIYASI — TOR SL + YAQIN TP                       |
//|     Asl: SL = range kengligi, TP = 2 x range -> narx range        |
//|     kengligining 2.1 barobarini bosib o'tishi kerak. Oltinda      |
//|     London breakouti odatda range ning 0.5-1.5 barobari.          |
//|     Yechim: SL = 0.5 x range, TP = 1.0 x range. RR o'sha 2.0,     |
//|     lekin TP ERISHILADIGAN masofada.                              |
//|     -> InpSL_Mode = SL_RANGE_FRACTION, InpSL_RangeFrac = 0.5      |
//|                                                                  |
//|  3) KO'P SESSIYA — savdo imkoniyati 3 barobar                     |
//|     -> InpS2_Enable = true, InpS3_Enable = true                   |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Lab"
#property version   "4.10"
#property description "Optimizatsiya laboratoriyasi. Standart sozlamalar = asl v2.00."
#property description "SL/TP/kirish rejimlari va filtrlar alohida sinaladi."

#include <Trade\Trade.mqh>
CTrade trade;

#define MAX_SESSIONS 4

//==================================================================//
//                            REJIMLAR                              //
//==================================================================//
enum ENUM_SL_MODE
  {
   SL_RANGE_FROM_ENTRY,   // ASL: entry -/+ (range kengligi + buffer)
   SL_RANGE_FRACTION,     // entry -/+ (range x koeff + buffer)   <- G'OYA 2
   SL_RANGE_LEVEL,        // rangeLow - buffer / rangeHigh + buffer
   SL_ATR                 // entry -/+ (ATR x koeff + buffer)
  };

enum ENUM_TP_MODE
  {
   TP_RR,                 // ASL: TP = entry -/+ risk x RR
   TP_RANGE_MULT,         // TP = breakout level -/+ range x koeff  <- G'OYA 2
   TP_ATR                 // TP = entry -/+ ATR x koeff
  };

enum ENUM_ENTRY_MODE
  {
   ENTRY_MARKET_ON_CLOSE, // ASL: bar yopilgach market order
   ENTRY_PENDING_STOP     // Levelda BuyStop/SellStop            <- G'OYA 1
  };

//==================================================================//
//                            INPUTLAR                              //
//==================================================================//
input group "═══════ ASOSIY REJIMLAR (bu yerda tajriba qilasiz) ═══════"
input ENUM_ENTRY_MODE InpEntryMode   = ENTRY_MARKET_ON_CLOSE; // Kirish rejimi
input ENUM_SL_MODE    InpSL_Mode     = SL_RANGE_FROM_ENTRY;   // SL rejimi
input ENUM_TP_MODE    InpTP_Mode     = TP_RR;                 // TP rejimi
input double   InpSL_RangeFrac   = 0.50;   // SL_RANGE_FRACTION: range x shu
input double   InpSL_ATRMult     = 1.00;   // SL_ATR: ATR x shu
input double   InpTP_RangeMult   = 1.00;   // TP_RANGE_MULT: range x shu
input double   InpTP_ATRMult     = 2.00;   // TP_ATR: ATR x shu
input int      InpPendingOffPts  = 10;     // Pending order offseti (punkt)

input group "═══════ SESSIYA 1: Osiyo -> London (ASL) ═══════"
input bool     InpS1_Enable      = true;   // 1-sessiya
input int      InpS1_RangeStart  = 0;      // Range boshi (soat)
input int      InpS1_RangeEnd    = 7;      // Range oxiri (soat)
input int      InpS1_TradeStart  = 8;      // Savdo boshi (soat)
input int      InpS1_TradeEnd    = 11;     // Savdo oxiri (soat)

input group "═══════ SESSIYA 2: London -> NY ═══════"
input bool     InpS2_Enable      = false;  // 2-sessiya
input int      InpS2_RangeStart  = 8;      // Range boshi (soat)
input int      InpS2_RangeEnd    = 13;     // Range oxiri (soat)
input int      InpS2_TradeStart  = 14;     // Savdo boshi (soat)
input int      InpS2_TradeEnd    = 17;     // Savdo oxiri (soat)

input group "═══════ SESSIYA 3: NY ═══════"
input bool     InpS3_Enable      = false;  // 3-sessiya
input int      InpS3_RangeStart  = 14;     // Range boshi (soat)
input int      InpS3_RangeEnd    = 18;     // Range oxiri (soat)
input int      InpS3_TradeStart  = 19;     // Savdo boshi (soat)
input int      InpS3_TradeEnd    = 22;     // Savdo oxiri (soat)

input group "═══════ SESSIYA 4: qo'shimcha ═══════"
input bool     InpS4_Enable      = false;  // 4-sessiya
input int      InpS4_RangeStart  = 20;     // Range boshi (soat)
input int      InpS4_RangeEnd    = 23;     // Range oxiri (soat)
input int      InpS4_TradeStart  = 23;     // Savdo boshi (soat)
input int      InpS4_TradeEnd    = 2;      // Savdo oxiri (soat)

input group "═══════ Savdo parametrlari (ASL QIYMATLAR) ═══════"
input double   InpLotSize           = 0.10;   // Lot hajmi
input int      InpSL_BufferPoints   = 50;     // SL buffer (punkt)
input double   InpRR_Ratio          = 2.0;    // Risk/Reward (TP_RR rejimida)
input int      InpMaxSpreadPoints   = 350;    // Max spread (punkt) — ASL: 350
input int      InpMagicNumber       = 100003; // Magic (sessiyaga: magic + N)

input group "═══════ Pozitsiya cheklovlari (ASL: cheksiz) ═══════"
input int      InpMaxConcurrentPos  = 1;      // Bir vaqtda max pozitsiya
input int      InpMaxTradesPerSess  = 0;      // Sessiyaga max savdo (0 = cheksiz)
input int      InpMaxTradesPerDay   = 0;      // Kuniga max savdo (0 = cheksiz)

input group "═══════ FILTRLAR — hammasi O'CHIQ (0 = o'chiq) ═══════"
input double   InpMaxEntryDistPct   = 0.0;    // Max kirish masofasi (range %) — 0=o'chiq
input double   InpMinBreakPct       = 0.0;    // Min penetratsiya (range %) — 0=o'chiq
input double   InpMinBodyPct        = 0.0;    // Min bar tanasi (%) — 0=o'chiq
input bool     InpUseRangeFilter    = false;  // Range kengligi filtri (ATR)
input int      InpATR_DailyPeriod   = 20;     // Kunlik ATR davri
input double   InpMinRangeATR       = 0.30;   // Min range = ATR(D1) x
input double   InpMaxRangeATR       = 2.00;   // Max range = ATR(D1) x

input group "═══════ POZITSIYA BOSHQARUVI — O'CHIQ ═══════"
input bool     InpUseBreakEven      = false;  // Break-even
input double   InpBE_TriggerR       = 1.00;   // BE ishga tushish (R)
input double   InpBE_LockR          = 0.10;   // BE da qulflanadigan (R)
input bool     InpUseTrailing       = false;  // Trailing stop
input double   InpTrailStartR       = 1.50;   // Trailing boshi (R)
input double   InpTrailDistR        = 0.75;   // Trailing masofasi (R)
input bool     InpUseTimeExit       = false;  // Vaqt bo'yicha chiqish
input int      InpForceCloseHour    = 23;     // Majburiy yopish soati
input bool     InpCloseFriday       = false;  // Juma yopish
input int      InpFridayCloseHour   = 20;     // Juma yopish soati

input group "═══════ Hafta kuni filtri ═══════"
input bool     InpMon = true;   // Dushanba
input bool     InpTue = true;   // Seshanba
input bool     InpWed = true;   // Chorshanba
input bool     InpThu = true;   // Payshanba
input bool     InpFri = true;   // Juma

input group "═══════ Himoyalar ═══════"
input int      InpSlippagePoints    = 10;     // Slippage (CTrade standarti = 10)
input bool     InpVerifyStops       = true;   // SL o'rnatilganini tekshirish
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa yopish
input bool     InpAutoAdjustPoints  = false;  // 3/5-digit punkt x10 (ASL: false)
input bool     InpVerboseLog        = false;  // Batafsil log (optimizatsiyada: false!)

//==================================================================//
//                        HOLAT                                     //
//==================================================================//
bool     s_on   [MAX_SESSIONS];
int      s_rs   [MAX_SESSIONS], s_re[MAX_SESSIONS];
int      s_ts   [MAX_SESSIONS], s_te[MAX_SESSIONS];
string   s_name [MAX_SESSIONS];

double   s_high [MAX_SESSIONS], s_low[MAX_SESSIONS], s_width[MAX_SESSIONS];
datetime s_rdate[MAX_SESSIONS];
bool     s_ok   [MAX_SESSIONS];      // range filtridan o'tdimi
int      s_cnt  [MAX_SESSIONS];
datetime s_cday [MAX_SESSIONS];
datetime s_pday [MAX_SESSIONS];      // pending qo'yilgan kun

double   g_pipSize   = 0.0;
double   g_pointMult = 1.0;
double   g_stopsPx   = 0.0;
int      g_dayTrades = 0;
datetime g_dayStamp  = 0;
int      g_atrD      = INVALID_HANDLE;
int      g_atrC      = INVALID_HANDLE;

//==================================================================//
//                          YORDAMCHILAR                            //
//==================================================================//
string PS(const double p) { return DoubleToString(p, _Digits); }
double NP(const double p) { return NormalizeDouble(p, _Digits); }
void   Log(const string m){ if(InpVerboseLog) Print(m); }

datetime TodayMidnight()
  {
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   return (TimeCurrent() - (tm.hour * 3600 + tm.min * 60 + tm.sec));
  }

bool InWindow(const int h, const int a, const int b)
  {
   if(a == b) return false;
   if(a <  b) return (h >= a && h < b);
   return (h >= a || h < b);
  }

bool NewBar()
  {
   static datetime last = 0;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == 0) return false;
   if(t != last) { last = t; return true; }
   return false;
  }

double ReadATR(const int h)
  {
   if(h == INVALID_HANDLE) return 0.0;
   double b[];
   if(CopyBuffer(h, 0, 1, 1, b) != 1) return 0.0;
   if(b[0] <= 0.0 || !MathIsValidNumber(b[0])) return 0.0;
   return b[0];
  }

bool DayAllowed(const int d)
  {
   switch(d)
     {
      case 1: return InpMon;  case 2: return InpTue;  case 3: return InpWed;
      case 4: return InpThu;  case 5: return InpFri;
     }
   return false;
  }

int CountOurPositions()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg >= InpMagicNumber && mg < InpMagicNumber + MAX_SESSIONS) n++;
     }
   return n;
  }

ulong FindSessionPosition(const int si)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber + si) continue;
      return tk;
     }
   return 0;
  }

int CountSessionPendings(const int si)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber + si) continue;
      n++;
     }
   return n;
  }

void DeleteSessionPendings(const int si, const string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber + si) continue;
      if(trade.OrderDelete(tk))
         Log(StringFormat("[%s] Pending o'chirildi (%s)", s_name[si], why));
      else
         PrintFormat("[%s][XATO] Pending o'chmadi | retcode=%d",
                     s_name[si], trade.ResultRetcode());
     }
  }

//--- boshlang'ich SL (BE/trailing uchun) -------------------------------
string GVName(const ulong t) { return "SBL_" + IntegerToString(InpMagicNumber)
                                      + "_" + IntegerToString((long)t); }
void   StoreISL(const ulong t, const double sl) { GlobalVariableSet(GVName(t), sl); }
bool   HasISL  (const ulong t) { return GlobalVariableCheck(GVName(t)); }
double GetISL  (const ulong t) { return GlobalVariableGet(GVName(t)); }
void   CleanGV()
  {
   string pfx = "SBL_" + IntegerToString(InpMagicNumber) + "_";
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
     {
      string n = GlobalVariableName(i);
      if(StringFind(n, pfx) == 0) GlobalVariableDel(n);
     }
  }

//==================================================================//
//                  SL / TP HISOBLASH — REJIMLAR                    //
//==================================================================//
double CalcSL(const int si, const bool isBuy, const double entry, const double spread)
  {
   double w   = s_width[si];
   double buf = InpSL_BufferPoints * g_pipSize;
   double d;

   switch(InpSL_Mode)
     {
      //--- ASL FORMULA: masofa = range kengligi + buffer ---------------
      case SL_RANGE_FROM_ENTRY:
         d = w + buf;
         return (isBuy ? entry - d : entry + d);

      //--- G'OYA 2: TOR SL — masofa = range x koeff + buffer -----------
      case SL_RANGE_FRACTION:
         d = w * InpSL_RangeFrac + buf;
         return (isBuy ? entry - d : entry + d);

      //--- Qat'iy level (v3.x uslubi) ----------------------------------
      case SL_RANGE_LEVEL:
         if(isBuy) return s_low[si] - buf;
         return s_high[si] + buf + spread;   // sell SL Ask bo'yicha ishlaydi

      //--- ATR asosida --------------------------------------------------
      case SL_ATR:
        {
         double atr = ReadATR(g_atrC);
         if(atr <= 0.0) atr = w;             // fallback
         d = atr * InpSL_ATRMult + buf;
         return (isBuy ? entry - d : entry + d);
        }
     }

   d = w + buf;
   return (isBuy ? entry - d : entry + d);
  }

double CalcTP(const int si, const bool isBuy, const double entry, const double risk)
  {
   switch(InpTP_Mode)
     {
      //--- ASL: risk x RR -----------------------------------------------
      case TP_RR:
         return (isBuy ? entry + risk * InpRR_Ratio : entry - risk * InpRR_Ratio);

      //--- G'OYA 2: breakout LEVELIDAN range ning koeffitsiyenti --------
      case TP_RANGE_MULT:
        {
         double lvl = isBuy ? s_high[si] : s_low[si];
         double d   = s_width[si] * InpTP_RangeMult;
         return (isBuy ? lvl + d : lvl - d);
        }

      case TP_ATR:
        {
         double atr = ReadATR(g_atrC);
         if(atr <= 0.0) atr = s_width[si];
         double d = atr * InpTP_ATRMult;
         return (isBuy ? entry + d : entry - d);
        }
     }
   return (isBuy ? entry + risk * InpRR_Ratio : entry - risk * InpRR_Ratio);
  }

//==================================================================//
//                            OnInit                                //
//==================================================================//
int OnInit()
  {
   g_pointMult = 1.0;
   if(InpAutoAdjustPoints && (_Digits == 3 || _Digits == 5)) g_pointMult = 10.0;
   g_pipSize = _Point * g_pointMult;
   g_stopsPx = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   s_on[0]=InpS1_Enable; s_rs[0]=InpS1_RangeStart; s_re[0]=InpS1_RangeEnd;
   s_ts[0]=InpS1_TradeStart; s_te[0]=InpS1_TradeEnd; s_name[0]="S1";

   s_on[1]=InpS2_Enable; s_rs[1]=InpS2_RangeStart; s_re[1]=InpS2_RangeEnd;
   s_ts[1]=InpS2_TradeStart; s_te[1]=InpS2_TradeEnd; s_name[1]="S2";

   s_on[2]=InpS3_Enable; s_rs[2]=InpS3_RangeStart; s_re[2]=InpS3_RangeEnd;
   s_ts[2]=InpS3_TradeStart; s_te[2]=InpS3_TradeEnd; s_name[2]="S3";

   s_on[3]=InpS4_Enable; s_rs[3]=InpS4_RangeStart; s_re[3]=InpS4_RangeEnd;
   s_ts[3]=InpS4_TradeStart; s_te[3]=InpS4_TradeEnd; s_name[3]="S4";

   for(int i = 0; i < MAX_SESSIONS; i++)
     {
      s_high[i]=0; s_low[i]=0; s_width[i]=0;
      s_rdate[i]=0; s_ok[i]=false; s_cnt[i]=0; s_cday[i]=0; s_pday[i]=0;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathRound(InpSlippagePoints * g_pointMult));
   trade.SetTypeFillingBySymbol(_Symbol);

   g_atrD = iATR(_Symbol, PERIOD_D1,      InpATR_DailyPeriod);
   g_atrC = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrD == INVALID_HANDLE || g_atrC == INVALID_HANDLE)
     { Alert("ATR yaratilmadi!"); return(INIT_FAILED); }

//--- validatsiya --------------------------------------------------------
   int active = 0;
   for(int i = 0; i < MAX_SESSIONS; i++)
     {
      if(!s_on[i]) continue;
      active++;
      if(s_rs[i] == s_re[i] || s_ts[i] == s_te[i])
        { Alert(s_name[i] + ": oyna bo'sh!"); return(INIT_PARAMETERS_INCORRECT); }
     }
   if(active == 0)  { Alert("Sessiya yoqilmagan!");  return(INIT_PARAMETERS_INCORRECT); }
   if(InpRR_Ratio <= 0.0) { Alert("RR > 0!");        return(INIT_PARAMETERS_INCORRECT); }
   if(InpSL_Mode == SL_RANGE_FRACTION && InpSL_RangeFrac <= 0.0)
     { Alert("InpSL_RangeFrac > 0!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseBreakEven && InpBE_LockR >= InpBE_TriggerR)
     { Alert("BE_LockR < BE_TriggerR!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseTrailing && InpTrailDistR >= InpTrailStartR)
     { Alert("TrailDistR < TrailStartR!"); return(INIT_PARAMETERS_INCORRECT); }

//--- hisobot (optimizatsiyada bosilmaydi) --------------------------------
   if(!MQLInfoInteger(MQL_OPTIMIZATION))
     {
      Print("═══════════════════════════════════════════════════════════");
      Print("  SB LAB v4.10  —  optimizatsiya laboratoriyasi");
      Print("═══════════════════════════════════════════════════════════");
      PrintFormat("  Simvol/TF ..... %s / %s  Digits=%d  1 punkt=%s",
                  _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()), _Digits, PS(g_pipSize));
      PrintFormat("  KIRISH rejimi . %s", EnumToString(InpEntryMode));
      PrintFormat("  SL rejimi ..... %s%s", EnumToString(InpSL_Mode),
                  (InpSL_Mode == SL_RANGE_FRACTION
                   ? StringFormat("  (range x %.2f)", InpSL_RangeFrac)
                   : (InpSL_Mode == SL_ATR
                      ? StringFormat("  (ATR x %.2f)", InpSL_ATRMult) : "")));
      PrintFormat("  TP rejimi ..... %s%s", EnumToString(InpTP_Mode),
                  (InpTP_Mode == TP_RANGE_MULT
                   ? StringFormat("  (range x %.2f)", InpTP_RangeMult)
                   : (InpTP_Mode == TP_ATR
                      ? StringFormat("  (ATR x %.2f)", InpTP_ATRMult)
                      : StringFormat("  (RR %.2f)", InpRR_Ratio))));
      PrintFormat("  Buffer / spread %d / %d punkt", InpSL_BufferPoints, InpMaxSpreadPoints);
      PrintFormat("  Lot ........... %.2f", InpLotSize);
      PrintFormat("  Filtrlar ...... kirish=%.0f%% penetr=%.0f%% tana=%.0f%% rangeATR=%s",
                  InpMaxEntryDistPct, InpMinBreakPct, InpMinBodyPct,
                  (InpUseRangeFilter ? "yoq" : "och"));
      PrintFormat("  BE / Trail .... %s / %s",
                  (InpUseBreakEven ? "yoq" : "och"), (InpUseTrailing ? "yoq" : "och"));
      for(int i = 0; i < MAX_SESSIONS; i++)
         PrintFormat("  %s %s range %02d-%02d  savdo %02d-%02d",
                     s_name[i], (s_on[i] ? "[YOQ]" : "[och]"),
                     s_rs[i], s_re[i], s_ts[i], s_te[i]);
      Print("═══════════════════════════════════════════════════════════");
     }

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_atrD != INVALID_HANDLE) IndicatorRelease(g_atrD);
   if(g_atrC != INVALID_HANDLE) IndicatorRelease(g_atrC);
   Comment("");
  }

//==================================================================//
//              SESSIYA RANGE                                       //
//==================================================================//
void BuildSessionRange(const int si)
  {
   datetime today = TodayMidnight();

   if(s_rdate[si] != today && s_high[si] > 0.0)
     {
      s_high[si]=0; s_low[si]=0; s_width[si]=0; s_ok[si]=false;
      DeleteSessionPendings(si, "yangi kun");
     }
   if(s_rdate[si] == today) return;

   datetime from, to;
   if(s_re[si] > s_rs[si])
     { from = today + s_rs[si]*3600;            to = today + s_re[si]*3600; }
   else
     { from = today - 86400 + s_rs[si]*3600;    to = today + s_re[si]*3600; }

   if(TimeCurrent() < to) return;

   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= 0) return;

   double hi = 0.0, lo = 0.0;
   int    n  = 0;
   for(int i = 0; i < bars; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t == 0)    break;
      if(t <  from) break;
      if(t >= to)   continue;
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow (_Symbol, PERIOD_CURRENT, i);
      if(h <= 0.0 || l <= 0.0) continue;
      if(n == 0) { hi = h; lo = l; }
      else { if(h > hi) hi = h; if(l < lo) lo = l; }
      n++;
     }

   if(n == 0 || hi <= lo) return;

   s_high[si]  = hi;
   s_low[si]   = lo;
   s_width[si] = hi - lo;
   s_rdate[si] = today;

//--- range kengligi filtri (standart: O'CHIQ) ---------------------------
   s_ok[si] = true;
   if(InpUseRangeFilter)
     {
      double atr = ReadATR(g_atrD);
      if(atr > 0.0)
        {
         double mn = atr * InpMinRangeATR, mx = atr * InpMaxRangeATR;
         if(s_width[si] < mn || s_width[si] > mx)
           {
            s_ok[si] = false;
            Log(StringFormat("[%s] Range filtri RAD: %s (ruxsat %s-%s)",
                             s_name[si], PS(s_width[si]), PS(mn), PS(mx)));
           }
        }
     }

   Log(StringFormat("[%s] RANGE %s-%s kenglik=%s (%d bar) %s",
                    s_name[si], PS(lo), PS(hi), PS(hi - lo), n,
                    (s_ok[si] ? "OK" : "RAD")));
  }

//==================================================================//
//              SL VERIFIKATSIYASI                                  //
//==================================================================//
void VerifyStops(const int si, const double wSL, const double wTP)
  {
   ulong tk = FindSessionPosition(si);
   if(tk == 0 && !MQLInfoInteger(MQL_TESTER)) { Sleep(200); tk = FindSessionPosition(si); }
   if(tk == 0) return;

   double aSL = PositionGetDouble(POSITION_SL);
   if(aSL != 0.0) { StoreISL(tk, aSL); return; }

   Print("[KRITIK] Broker SL ni qabul qilmadi — tiklanmoqda...");
   if(trade.PositionModify(tk, wSL, wTP)) { StoreISL(tk, wSL); return; }

   PrintFormat("[XATO] SL tiklanmadi | retcode=%d | %s",
               trade.ResultRetcode(), trade.ResultRetcodeDescription());
   if(InpCloseIfNoSL)
     {
      Print("[HIMOYA] SL siz pozitsiya — yopilmoqda!");
      trade.PositionClose(tk);
     }
  }

//==================================================================//
//              HISOBLAGICHLAR                                      //
//==================================================================//
void RegisterTrade(const int si)
  {
   datetime today = TodayMidnight();
   if(s_cday[si] != today) { s_cday[si] = today; s_cnt[si] = 0; }
   s_cnt[si]++;
   if(g_dayStamp != today) { g_dayStamp = today; g_dayTrades = 0; }
   g_dayTrades++;
  }

//==================================================================//
//        KIRISH REJIMI 1: MARKET (ASL)                             //
//==================================================================//
void MarketEntry(const int si, const bool isBuy)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0) return;

   double spread = tick.ask - tick.bid;
   if(InpMaxSpreadPoints > 0 && spread > InpMaxSpreadPoints * g_pipSize)
     { Log("[FILTR] Spread keng"); return; }

   double entry = isBuy ? tick.ask : tick.bid;

//--- kech kirish filtri (standart: O'CHIQ) ------------------------------
   if(InpMaxEntryDistPct > 0.0)
     {
      double dist = isBuy ? (entry - s_high[si]) : (s_low[si] - entry);
      if(dist > s_width[si] * InpMaxEntryDistPct / 100.0)
        { Log("[FILTR] Kech kirish"); return; }
     }

   double slPrice = NP(CalcSL(si, isBuy, entry, spread));
   double risk    = MathAbs(entry - slPrice);
   if(risk <= 0.0) return;
   if(g_stopsPx > 0.0 && risk < g_stopsPx) { Log("[FILTR] SL STOPS_LEVEL dan yaqin"); return; }

   double tpPrice = NP(CalcTP(si, isBuy, entry, risk));

//--- TP noto'g'ri tomonda emasligini tekshirish --------------------------
   if(isBuy  && tpPrice <= entry) { Log("[XATO] TP entry dan past"); return; }
   if(!isBuy && tpPrice >= entry) { Log("[XATO] TP entry dan yuqori"); return; }

   trade.SetExpertMagicNumber(InpMagicNumber + si);
   string cmt = StringFormat("SBL_S%d_%s", si + 1, (isBuy ? "B" : "S"));

   bool ok = isBuy
             ? trade.Buy (InpLotSize, _Symbol, tick.ask, slPrice, tpPrice, cmt)
             : trade.Sell(InpLotSize, _Symbol, tick.bid, slPrice, tpPrice, cmt);

   if(!ok)
     {
      PrintFormat("[%s][XATO] %s ochilmadi | retcode=%d | %s",
                  s_name[si], (isBuy ? "BUY" : "SELL"),
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
     }

   Log(StringFormat("[%s] %s entry=%s SL=%s TP=%s risk=%s",
                    s_name[si], (isBuy ? "BUY" : "SELL"),
                    PS(entry), PS(slPrice), PS(tpPrice), PS(risk)));

   RegisterTrade(si);
   if(InpVerifyStops) VerifyStops(si, slPrice, tpPrice);
  }

//==================================================================//
//        KIRISH REJIMI 2: PENDING STOP  [G'OYA 1]                  //
//==================================================================//
//  Levelda BuyStop/SellStop qo'yiladi. Afzalliklari:
//    - entry aynan levelda -> "kech kirish" muammosi YO'Q
//    - SL leveldan uzoqroqda qoladi -> keraksiz stop-out kam
//    - TP yaqinroq -> erishish ehtimoli yuqori
//  Kamchiligi: soya (wick) bilan ham ishga tushadi.
//==================================================================//
void PlacePendings(const int si)
  {
   datetime today = TodayMidnight();
   if(s_pday[si] == today) return;              // kuniga bir marta
   if(CountSessionPendings(si) > 0) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0) return;
   double spread = tick.ask - tick.bid;

   if(InpMaxSpreadPoints > 0 && spread > InpMaxSpreadPoints * g_pipSize) return;

   double off       = InpPendingOffPts * g_pipSize;
   double buyPrice  = NP(s_high[si] + off);
   double sellPrice = NP(s_low[si]  - off);

   trade.SetExpertMagicNumber(InpMagicNumber + si);
   int placed = 0;

//--- BUY STOP -----------------------------------------------------------
//    Narx allaqachon leveldan yuqorida bo'lsa, stop order qo'yib bo'lmaydi
   if(buyPrice > tick.ask + g_stopsPx)
     {
      double sl   = NP(CalcSL(si, true, buyPrice, spread));
      double risk = MathAbs(buyPrice - sl);
      double tp   = NP(CalcTP(si, true, buyPrice, risk));
      if(risk > 0.0 && risk >= g_stopsPx && tp > buyPrice)
        {
         if(trade.BuyStop(InpLotSize, buyPrice, _Symbol, sl, tp,
                          ORDER_TIME_GTC, 0,
                          StringFormat("SBL_S%d_BS", si + 1)))
           {
            placed++;
            Log(StringFormat("[%s] BuyStop %s SL=%s TP=%s (risk %s)",
                             s_name[si], PS(buyPrice), PS(sl), PS(tp), PS(risk)));
           }
         else
            PrintFormat("[%s][XATO] BuyStop | retcode=%d | %s", s_name[si],
                        trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }

//--- SELL STOP ----------------------------------------------------------
   if(sellPrice < tick.bid - g_stopsPx)
     {
      double sl   = NP(CalcSL(si, false, sellPrice, spread));
      double risk = MathAbs(sellPrice - sl);
      double tp   = NP(CalcTP(si, false, sellPrice, risk));
      if(risk > 0.0 && risk >= g_stopsPx && tp < sellPrice)
        {
         if(trade.SellStop(InpLotSize, sellPrice, _Symbol, sl, tp,
                           ORDER_TIME_GTC, 0,
                           StringFormat("SBL_S%d_SS", si + 1)))
           {
            placed++;
            Log(StringFormat("[%s] SellStop %s SL=%s TP=%s (risk %s)",
                             s_name[si], PS(sellPrice), PS(sl), PS(tp), PS(risk)));
           }
         else
            PrintFormat("[%s][XATO] SellStop | retcode=%d | %s", s_name[si],
                        trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }

   if(placed > 0) s_pday[si] = today;
  }

//--- pendinglarni boshqarish (har tickda) --------------------------------
void ManagePendings()
  {
   if(InpEntryMode != ENTRY_PENDING_STOP) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   for(int si = 0; si < MAX_SESSIONS; si++)
     {
      if(!s_on[si]) continue;
      if(CountSessionPendings(si) == 0) continue;

      //--- OCO: pozitsiya ochildi -> qolgan pendingni o'chirish -----------
      if(FindSessionPosition(si) != 0)
        {
         DeleteSessionPendings(si, "OCO — pozitsiya ochildi");
         RegisterTrade(si);
         continue;
        }

      //--- savdo oynasi yopildi -> pendinglarni o'chirish ------------------
      if(!InWindow(tm.hour, s_ts[si], s_te[si]))
         DeleteSessionPendings(si, "savdo oynasi yopildi");
     }
  }

//==================================================================//
//        POZITSIYA BOSHQARUVI (standart: O'CHIQ)                   //
//==================================================================//
void ManagePositions()
  {
   if(!InpUseBreakEven && !InpUseTrailing && !InpUseTimeExit && !InpCloseFriday)
     { return; }                                  // hech nima yoqilmagan

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg < InpMagicNumber || mg >= InpMagicNumber + MAX_SESSIONS) continue;

      //--- vaqt bo'yicha chiqish ------------------------------------------
      bool exitNow = false;
      if(InpCloseFriday && tm.day_of_week == 5 && tm.hour >= InpFridayCloseHour) exitNow = true;
      if(!exitNow && InpUseTimeExit && tm.hour >= InpForceCloseHour)             exitNow = true;
      if(exitNow)
        {
         if(trade.PositionClose(tk))
            Log(StringFormat("[VAQT-CHIQISH] ticket=%s P/L=%.2f",
                             IntegerToString((long)tk), PositionGetDouble(POSITION_PROFIT)));
         continue;
        }

      if(!InpUseBreakEven && !InpUseTrailing) continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double cSL   = PositionGetDouble(POSITION_SL);
      double cTP   = PositionGetDouble(POSITION_TP);

      double iSL = HasISL(tk) ? GetISL(tk) : cSL;
      if(!HasISL(tk) && cSL != 0.0) StoreISL(tk, cSL);
      double iR = MathAbs(entry - iSL);
      if(iR <= 0.0) continue;

      double cp = isBuy ? tick.bid : tick.ask;
      double R  = (isBuy ? (cp - entry) : (entry - cp)) / iR;

      double nSL = cSL;
      if(InpUseBreakEven && R >= InpBE_TriggerR)
        {
         double be = isBuy ? entry + iR * InpBE_LockR : entry - iR * InpBE_LockR;
         if(isBuy) { if(be > nSL) nSL = be; }
         else      { if(nSL <= 0.0 || be < nSL) nSL = be; }
        }
      if(InpUseTrailing && R >= InpTrailStartR)
        {
         double tr = isBuy ? cp - iR * InpTrailDistR : cp + iR * InpTrailDistR;
         if(isBuy) { if(tr > nSL) nSL = tr; }
         else      { if(nSL <= 0.0 || tr < nSL) nSL = tr; }
        }

      nSL = NP(nSL);
      double minStep = MathMax(_Point, 10 * g_pipSize);
      if(isBuy  && !(nSL > cSL + minStep)) continue;
      if(!isBuy && !(nSL < cSL - minStep)) continue;
      if(isBuy  && nSL >= tick.bid) continue;
      if(!isBuy && nSL <= tick.ask) continue;

      double dp = isBuy ? (tick.bid - nSL) : (nSL - tick.ask);
      if(g_stopsPx > 0.0 && dp < g_stopsPx) continue;

      if(trade.PositionModify(tk, nSL, cTP))
         Log(StringFormat("[SL-KO'CHDI] +%.2fR  %s -> %s", R, PS(cSL), PS(nSL)));
     }
  }

//==================================================================//
//              BREAKOUT SIFATI (standart: O'CHIQ)                  //
//==================================================================//
bool ApproveBreakout(const int si, const bool isBuy, const double c1)
  {
   if(InpMinBreakPct > 0.0)
     {
      double need = s_width[si] * InpMinBreakPct / 100.0;
      double pen  = isBuy ? (c1 - s_high[si]) : (s_low[si] - c1);
      if(pen < need) { Log("[FILTR] Penetratsiya zaif"); return false; }
     }

   if(InpMinBodyPct > 0.0)
     {
      double o = iOpen (_Symbol, PERIOD_CURRENT, 1);
      double c = iClose(_Symbol, PERIOD_CURRENT, 1);
      double h = iHigh (_Symbol, PERIOD_CURRENT, 1);
      double l = iLow  (_Symbol, PERIOD_CURRENT, 1);
      double br = h - l;
      if(br > 0.0 && MathAbs(c - o) / br * 100.0 < InpMinBodyPct)
        { Log("[FILTR] Bar tanasi zaif"); return false; }
     }
   return true;
  }

//==================================================================//
//                  SESSIYANI QAYTA ISHLASH                         //
//==================================================================//
void ProcessSession(const int si, const int hour)
  {
   if(!s_on[si]) return;

   BuildSessionRange(si);
   if(s_high[si] <= 0.0 || s_low[si] <= 0.0) return;
   if(!s_ok[si]) return;

   if(!InWindow(hour, s_ts[si], s_te[si])) return;
   if(FindSessionPosition(si) != 0) return;
   if(InpMaxConcurrentPos > 0 && CountOurPositions() >= InpMaxConcurrentPos) return;

   datetime today = TodayMidnight();
   if(s_cday[si] != today) { s_cday[si] = today; s_cnt[si] = 0; }
   if(g_dayStamp != today) { g_dayStamp = today; g_dayTrades = 0; }
   if(InpMaxTradesPerSess > 0 && s_cnt[si]   >= InpMaxTradesPerSess) return;
   if(InpMaxTradesPerDay  > 0 && g_dayTrades >= InpMaxTradesPerDay)  return;

//--- PENDING rejimi: oyna ochilishi bilan orderlarni qo'yamiz -----------
   if(InpEntryMode == ENTRY_PENDING_STOP)
     {
      PlacePendings(si);
      return;
     }

//--- MARKET rejimi (ASL): yopilgan barning close narxi -------------------
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(c1 <= 0.0) return;

   bool wantBuy  = (c1 > s_high[si]);
   bool wantSell = (c1 < s_low[si]);
   if(!wantBuy && !wantSell) return;
   if(!ApproveBreakout(si, wantBuy, c1)) return;

   MarketEntry(si, wantBuy);
  }

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
  {
   ManagePendings();       // OCO va oyna yopilishi — har tickda
   ManagePositions();      // BE/trailing/vaqt — har tickda (yoqilgan bo'lsa)

   if(!NewBar()) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(!DayAllowed(tm.day_of_week)) return;

   for(int si = 0; si < MAX_SESSIONS; si++)
      ProcessSession(si, tm.hour);

//--- yopilgan pozitsiyalarning GV larini tozalash -------------------------
   if(CountOurPositions() == 0) CleanGV();
  }
//+------------------------------------------------------------------+
