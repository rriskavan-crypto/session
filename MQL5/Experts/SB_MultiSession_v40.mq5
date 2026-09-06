//+------------------------------------------------------------------+
//|                                    SB_MultiSession_v40.mq5       |
//|        SIZNING ESKI KODINGIZ (v2.00) — KO'P SESSIYAGA KENGAYTIRILDI |
//|                                                                  |
//|  ╔══════════════════════════════════════════════════════════╗    |
//|  ║  MUHIM: SL/TP MATEMATIKASI ASLIDAGIDEK QOLDIRILDI!       ║    |
//|  ╚══════════════════════════════════════════════════════════╝    |
//|                                                                  |
//|  slDistance = (rangeHigh - rangeLow) + buffer * _Point            |
//|  BUY : SL = ask - slDistance,  TP = ask + slDistance * RR         |
//|  SELL: SL = bid + slDistance,  TP = bid - slDistance * RR         |
//|                                                                  |
//|  v3.x versiyalarda men SL ni range LEVELIGA bog'lagandim —        |
//|  bu SL ni KENGAYTIRDI va TP ni UZOQLASHTIRDI, natijada qat'iy     |
//|  lot bilan har savdoda ko'proq zarar bo'ldi. Bu yerda o'sha       |
//|  o'zgarish QAYTARIB OLINDI.                                       |
//|                                                                  |
//|  NIMA QO'SHILDI:                                                  |
//|                                                                  |
//|  1) KO'P SESSIYA — 4 tagacha mustaqil range/savdo oynasi.        |
//|     Standart holda faqat 1-sessiya yoqilgan = ASL KOD.            |
//|     Sessiya 2 va 3 ni yoqib savdo sonini oshirasiz.               |
//|                                                                  |
//|  2) FAQAT "BEPUL" HIMOYALAR — natijaga ta'sir qilmaydigan,        |
//|     lekin orderning rad etilishini oldini oluvchi tuzatishlar:    |
//|       - NormalizeDouble (Invalid stops xatosiga qarshi)           |
//|       - SetTypeFillingBySymbol (ECN brokerlarda ishlashi uchun)   |
//|       - har bir xato retcode bilan LOG qilinadi                   |
//|       - SL o'rnatilganligi tekshiriladi (SL siz pozitsiya yo'q)   |
//|       - yangi kunda eski range tozalanadi                         |
//|                                                                  |
//|  HECH QANDAY FILTR QO'SHILMADI. Kunlik limit yo'q, ATR filtri     |
//|  yo'q, break-even yo'q, vaqt chiqishi yo'q — asl koddagidek.      |
//|                                                                  |
//|  PARITET TEKSHIRUVI: faqat 1-sessiya yoqilgan holda natija        |
//|  asl v2.00 bilan deyarli bir xil bo'lishi kerak. Agar sezilarli   |
//|  farq bo'lsa — menga ayting, sabab topamiz.                       |
//+------------------------------------------------------------------+
#property copyright "Session Breakout Gold - Multi Session"
#property version   "4.00"
#property description "Asl v2.00 SL/TP matematikasi + 4 tagacha sessiya."
#property description "Filtrlar yo'q. Faqat order rad etilishiga qarshi himoya."

#include <Trade\Trade.mqh>
CTrade trade;

#define MAX_SESSIONS 4

//==================================================================//
//                            INPUTLAR                              //
//==================================================================//
input group "═══════ SESSIYA 1: Osiyo range -> London breakout ═══════"
input bool     InpS1_Enable      = true;   // 1-sessiya yoqilsinmi
input int      InpS1_RangeStart  = 0;      // Range boshlanishi (soat)
input int      InpS1_RangeEnd    = 7;      // Range tugashi (soat)
input int      InpS1_TradeStart  = 8;      // Savdo boshlanishi (soat)
input int      InpS1_TradeEnd    = 11;     // Savdo tugashi (soat)

input group "═══════ SESSIYA 2: London range -> NY breakout ═══════"
input bool     InpS2_Enable      = false;  // 2-sessiya yoqilsinmi
input int      InpS2_RangeStart  = 8;      // Range boshlanishi (soat)
input int      InpS2_RangeEnd    = 13;     // Range tugashi (soat)
input int      InpS2_TradeStart  = 14;     // Savdo boshlanishi (soat)
input int      InpS2_TradeEnd    = 17;     // Savdo tugashi (soat)

input group "═══════ SESSIYA 3: NY range -> kech breakout ═══════"
input bool     InpS3_Enable      = false;  // 3-sessiya yoqilsinmi
input int      InpS3_RangeStart  = 14;     // Range boshlanishi (soat)
input int      InpS3_RangeEnd    = 18;     // Range tugashi (soat)
input int      InpS3_TradeStart  = 19;     // Savdo boshlanishi (soat)
input int      InpS3_TradeEnd    = 22;     // Savdo tugashi (soat)

input group "═══════ SESSIYA 4: qo'shimcha (masalan tungi) ═══════"
input bool     InpS4_Enable      = false;  // 4-sessiya yoqilsinmi
input int      InpS4_RangeStart  = 20;     // Range boshlanishi (soat)
input int      InpS4_RangeEnd    = 23;     // Range tugashi (soat)
input int      InpS4_TradeStart  = 23;     // Savdo boshlanishi (soat)
input int      InpS4_TradeEnd    = 2;      // Savdo tugashi (soat, yarim tunni kesishi mumkin)

input group "═══════ Savdo parametrlari (ASL QIYMATLAR) ═══════"
input double   InpLotSize           = 0.10;   // Lot hajmi
input int      InpSL_BufferPoints   = 50;     // SL buffer (punkt)
input double   InpRR_Ratio          = 2.0;    // Risk/Reward nisbati
input int      InpMaxSpreadPoints   = 350;    // Max spread (punkt) — ASL: 350
input int      InpMagicNumber       = 100003; // Magic (har sessiya: magic + N)

input group "═══════ Pozitsiya cheklovlari ═══════"
input int      InpMaxConcurrentPos  = 1;      // Bir vaqtda max pozitsiya (ASL: 1)
input int      InpMaxTradesPerSess  = 0;      // Sessiyaga max savdo (0 = cheksiz, ASL)
input int      InpMaxTradesPerDay   = 0;      // Kuniga max savdo (0 = cheksiz, ASL)

input group "═══════ Himoyalar (natijaga ta'sir qilmaydi) ═══════"
input int      InpSlippagePoints    = 10;     // Slippage (CTrade standarti = 10)
input bool     InpVerifyStops       = true;   // SL o'rnatilganini tekshirish
input bool     InpCloseIfNoSL       = true;   // SL tiklanmasa pozitsiyani yopish
input bool     InpAutoAdjustPoints  = false;  // 3/5-digit brokerda punkt x10 (ASL: false)
input bool     InpVerboseLog        = true;   // Batafsil log

//==================================================================//
//                        SESSIYA HOLATI                            //
//==================================================================//
bool     s_on   [MAX_SESSIONS];
int      s_rs   [MAX_SESSIONS], s_re[MAX_SESSIONS];
int      s_ts   [MAX_SESSIONS], s_te[MAX_SESSIONS];
string   s_name [MAX_SESSIONS];

double   s_high [MAX_SESSIONS], s_low[MAX_SESSIONS], s_width[MAX_SESSIONS];
datetime s_rdate[MAX_SESSIONS];      // range qurilgan kun
int      s_cnt  [MAX_SESSIONS];      // bugungi savdolar (sessiya bo'yicha)
datetime s_cday [MAX_SESSIONS];      // hisoblagich kuni

double   g_pipSize   = 0.0;
double   g_pointMult = 1.0;
int      g_dayTrades = 0;
datetime g_dayStamp  = 0;

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

//--- soat oynasi (yarim tunni kesib o'tishni qo'llab-quvvatlaydi) -----
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

//--- bizning pozitsiyalarimiz soni (barcha sessiyalar) ---------------
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

//--- ma'lum sessiyaning pozitsiyasi ----------------------------------
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

//==================================================================//
//                            OnInit                                //
//==================================================================//
int OnInit()
  {
   g_pointMult = 1.0;
   if(InpAutoAdjustPoints && (_Digits == 3 || _Digits == 5)) g_pointMult = 10.0;
   g_pipSize = _Point * g_pointMult;

//--- sessiya konfiguratsiyasini massivga ko'chirish -------------------
   s_on[0]=InpS1_Enable; s_rs[0]=InpS1_RangeStart; s_re[0]=InpS1_RangeEnd;
   s_ts[0]=InpS1_TradeStart; s_te[0]=InpS1_TradeEnd; s_name[0]="S1-Osiyo/London";

   s_on[1]=InpS2_Enable; s_rs[1]=InpS2_RangeStart; s_re[1]=InpS2_RangeEnd;
   s_ts[1]=InpS2_TradeStart; s_te[1]=InpS2_TradeEnd; s_name[1]="S2-London/NY";

   s_on[2]=InpS3_Enable; s_rs[2]=InpS3_RangeStart; s_re[2]=InpS3_RangeEnd;
   s_ts[2]=InpS3_TradeStart; s_te[2]=InpS3_TradeEnd; s_name[2]="S3-NY";

   s_on[3]=InpS4_Enable; s_rs[3]=InpS4_RangeStart; s_re[3]=InpS4_RangeEnd;
   s_ts[3]=InpS4_TradeStart; s_te[3]=InpS4_TradeEnd; s_name[3]="S4-Qo'shimcha";

   for(int i = 0; i < MAX_SESSIONS; i++)
     {
      s_high[i]=0; s_low[i]=0; s_width[i]=0; s_rdate[i]=0; s_cnt[i]=0; s_cday[i]=0;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints((ulong)MathRound(InpSlippagePoints * g_pointMult));
   if(!trade.SetTypeFillingBySymbol(_Symbol))
      Print("[OGOH] Filling mode aniqlanmadi — CTrade standarti ishlatiladi");

//--- validatsiya (minimal, faqat aniq xatolar) -------------------------
   int active = 0;
   for(int i = 0; i < MAX_SESSIONS; i++)
     {
      if(!s_on[i]) continue;
      active++;
      if(s_rs[i] == s_re[i])
        { Alert(s_name[i] + ": range oynasi bo'sh!"); return(INIT_PARAMETERS_INCORRECT); }
      if(s_ts[i] == s_te[i])
        { Alert(s_name[i] + ": savdo oynasi bo'sh!"); return(INIT_PARAMETERS_INCORRECT); }
     }
   if(active == 0)
     { Alert("Hech bo'lmasa bitta sessiya yoqilsin!"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpRR_Ratio <= 0.0)
     { Alert("InpRR_Ratio > 0 bo'lsin!"); return(INIT_PARAMETERS_INCORRECT); }

//--- hisobot -----------------------------------------------------------
   Print("═══════════════════════════════════════════════════════════");
   Print("  SB MULTI-SESSION v4.00  —  asl v2.00 matematikasi");
   Print("═══════════════════════════════════════════════════════════");
   PrintFormat("  Simvol / TF ....... %s / %s", _Symbol,
               EnumToString((ENUM_TIMEFRAMES)Period()));
   PrintFormat("  Digits / Point .... %d / %s   (punkt x%.0f -> %s)",
               _Digits, DoubleToString(_Point, 5), g_pointMult, PS(g_pipSize));
   PrintFormat("  SL buffer ......... %d punkt = %s",
               InpSL_BufferPoints, PS(InpSL_BufferPoints * g_pipSize));
   PrintFormat("  Max spread ........ %d punkt = %s",
               InpMaxSpreadPoints, PS(InpMaxSpreadPoints * g_pipSize));
   PrintFormat("  Lot / RR .......... %.2f / %.2f", InpLotSize, InpRR_Ratio);
   PrintFormat("  Max pozitsiya ..... %d", InpMaxConcurrentPos);
   PrintFormat("  Savdo limiti ...... sessiyaga %s, kuniga %s",
               (InpMaxTradesPerSess > 0 ? IntegerToString(InpMaxTradesPerSess) : "cheksiz"),
               (InpMaxTradesPerDay  > 0 ? IntegerToString(InpMaxTradesPerDay)  : "cheksiz"));
   Print("  ─────────────── SESSIYALAR ───────────────");
   for(int i = 0; i < MAX_SESSIONS; i++)
      PrintFormat("  %-16s %s  range %02d:00-%02d:00  savdo %02d:00-%02d:00  magic=%d",
                  s_name[i], (s_on[i] ? "[YOQ]" : "[och]"),
                  s_rs[i], s_re[i], s_ts[i], s_te[i], InpMagicNumber + i);
   Print("═══════════════════════════════════════════════════════════");

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { Comment(""); }

//==================================================================//
//              SESSIYA RANGE NI QURISH                             //
//==================================================================//
void BuildSessionRange(const int si)
  {
   datetime today = TodayMidnight();

//--- yangi kun -> eski rangeni tozalash (eski levellar bilan savdo yo'q)
   if(s_rdate[si] != today && s_high[si] > 0.0)
     {
      s_high[si] = 0.0; s_low[si] = 0.0; s_width[si] = 0.0;
      Log(StringFormat("[%s] Yangi kun — eski range tozalandi", s_name[si]));
     }

   if(s_rdate[si] == today) return;

//--- range oynasi (yarim tunni kesishi mumkin) -------------------------
   datetime from, to;
   if(s_re[si] > s_rs[si])
     {
      from = today + s_rs[si] * 3600;
      to   = today + s_re[si] * 3600;
     }
   else
     {
      from = today - 86400 + s_rs[si] * 3600;
      to   = today + s_re[si] * 3600;
     }

   if(TimeCurrent() < to) return;      // oyna hali tugamagan

   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= 0) return;

   double hi = 0.0, lo = 0.0;
   int    n  = 0;

   for(int i = 0; i < bars; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t == 0)     break;
      if(t <  from)  break;
      if(t >= to)    continue;

      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow (_Symbol, PERIOD_CURRENT, i);
      if(h <= 0.0 || l <= 0.0) continue;

      if(n == 0) { hi = h; lo = l; }
      else { if(h > hi) hi = h; if(l < lo) lo = l; }
      n++;
     }

   if(n == 0 || hi <= lo)
     {
      static datetime warned[MAX_SESSIONS];
      if(warned[si] != today)
        {
         warned[si] = today;
         PrintFormat("[%s][XATO] Range qurilmadi (bar: %d, oyna %s-%s)",
                     s_name[si], n,
                     TimeToString(from, TIME_MINUTES), TimeToString(to, TIME_MINUTES));
        }
      return;
     }

   s_high[si]  = hi;
   s_low[si]   = lo;
   s_width[si] = hi - lo;
   s_rdate[si] = today;

   PrintFormat("[%s] RANGE %s  High=%s Low=%s Kenglik=%s  (%d bar)",
               s_name[si], TimeToString(today, TIME_DATE),
               PS(hi), PS(lo), PS(hi - lo), n);
  }

//==================================================================//
//        SL O'RNATILGANINI TEKSHIRISH (bepul himoya)               //
//==================================================================//
void VerifyStops(const int si, const bool isBuy,
                 const double wantedSL, const double wantedTP)
  {
   ulong tk = FindSessionPosition(si);
   if(tk == 0 && !MQLInfoInteger(MQL_TESTER)) { Sleep(200); tk = FindSessionPosition(si); }
   if(tk == 0) { Print("[OGOH] Pozitsiya topilmadi — SL tekshiruvi o'tkazilmadi"); return; }

   double aSL = PositionGetDouble(POSITION_SL);
   double aTP = PositionGetDouble(POSITION_TP);

   if(aSL != 0.0)
     {
      Log(StringFormat("[%s] SL tasdiqlandi: %s  TP: %s", s_name[si], PS(aSL), PS(aTP)));
      return;
     }

//--- broker SL ni tashlab yuborgan --------------------------------------
   Print("╔══════════════════════════════════════════════════════════╗");
   Print("║ [KRITIK] BROKER SL NI QABUL QILMADI — TIKLANMOQDA...     ║");
   Print("╚══════════════════════════════════════════════════════════╝");

   if(trade.PositionModify(tk, wantedSL, wantedTP))
     {
      PrintFormat("[TIKLANDI] SL=%s TP=%s", PS(wantedSL), PS(wantedTP));
      return;
     }

   PrintFormat("[XATO] SL tiklanmadi | retcode=%d | %s",
               trade.ResultRetcode(), trade.ResultRetcodeDescription());

   if(InpCloseIfNoSL)
     {
      Print("[HIMOYA] SL SIZ POZITSIYA — YOPILMOQDA!");
      if(!trade.PositionClose(tk))
         PrintFormat("[XATO] Yopilmadi | retcode=%d — QO'LDA YOPING!", trade.ResultRetcode());
     }
  }

//==================================================================//
//              SAVDO OCHISH — ASL MATEMATIKA                       //
//==================================================================//
void TryTrade(const int si, const bool isBuy)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     { Print("[XATO] Tik ma'lumoti yo'q"); return; }

//--- spread filtri (ASL: 350 punkt) -------------------------------------
   if(InpMaxSpreadPoints > 0)
     {
      double sp    = tick.ask - tick.bid;
      double maxSp = InpMaxSpreadPoints * g_pipSize;
      if(sp > maxSp)
        {
         PrintFormat("[%s][FILTR] Spread keng: %s > %s", s_name[si], PS(sp), PS(maxSp));
         return;
        }
     }

//══════════════════════════════════════════════════════════════════//
//  ASL FORMULA — O'ZGARTIRILMAGAN                                   //
//══════════════════════════════════════════════════════════════════//
   double slDistance = s_width[si] + InpSL_BufferPoints * g_pipSize;

   double entry, slPrice, tpPrice;
   if(isBuy)
     {
      entry   = tick.ask;
      slPrice = entry - slDistance;
      tpPrice = entry + slDistance * InpRR_Ratio;
     }
   else
     {
      entry   = tick.bid;
      slPrice = entry + slDistance;
      tpPrice = entry - slDistance * InpRR_Ratio;
     }
//══════════════════════════════════════════════════════════════════//

//--- normalizatsiya (bepul himoya: "Invalid stops" ga qarshi) ----------
   slPrice = NP(slPrice);
   tpPrice = NP(tpPrice);

   PrintFormat("[%s] SIGNAL %s | range %s-%s (%s) | entry=%s SL=%s TP=%s | lot=%.2f",
               s_name[si], (isBuy ? "BUY" : "SELL"),
               PS(s_low[si]), PS(s_high[si]), PS(s_width[si]),
               PS(entry), PS(slPrice), PS(tpPrice), InpLotSize);

//--- sessiya magic bilan yuborish ---------------------------------------
   trade.SetExpertMagicNumber(InpMagicNumber + si);
   string cmt = StringFormat("SB_S%d_%s", si + 1, (isBuy ? "Buy" : "Sell"));

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

   PrintFormat("[%s][OK] %s ochildi | narx=%s | hajm=%.2f",
               s_name[si], (isBuy ? "BUY" : "SELL"),
               PS(trade.ResultPrice()), trade.ResultVolume());

//--- hisoblagichlar -----------------------------------------------------
   datetime today = TodayMidnight();
   if(s_cday[si] != today) { s_cday[si] = today; s_cnt[si] = 0; }
   s_cnt[si]++;
   if(g_dayStamp != today) { g_dayStamp = today; g_dayTrades = 0; }
   g_dayTrades++;

   if(InpVerifyStops) VerifyStops(si, isBuy, slPrice, tpPrice);
  }

//==================================================================//
//                       BITTA SESSIYANI QAYTA ISHLASH              //
//==================================================================//
void ProcessSession(const int si, const int hour)
  {
   if(!s_on[si]) return;

   BuildSessionRange(si);
   if(s_high[si] <= 0.0 || s_low[si] <= 0.0) return;

//--- savdo oynasidamizmi ------------------------------------------------
   if(!InWindow(hour, s_ts[si], s_te[si])) return;

//--- shu sessiyaning pozitsiyasi ochiqmi --------------------------------
   if(FindSessionPosition(si) != 0) return;

//--- umumiy pozitsiya limiti (ASL: 1) -----------------------------------
   if(InpMaxConcurrentPos > 0 && CountOurPositions() >= InpMaxConcurrentPos) return;

//--- savdo limitlari (ASL: cheksiz) -------------------------------------
   datetime today = TodayMidnight();
   if(s_cday[si] != today) { s_cday[si] = today; s_cnt[si] = 0; }
   if(g_dayStamp != today) { g_dayStamp = today; g_dayTrades = 0; }

   if(InpMaxTradesPerSess > 0 && s_cnt[si]  >= InpMaxTradesPerSess) return;
   if(InpMaxTradesPerDay  > 0 && g_dayTrades >= InpMaxTradesPerDay) return;

//--- signal: YOPILGAN barning close narxi (ASL) -------------------------
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(c1 <= 0.0) return;

   if(c1 > s_high[si])      TryTrade(si, true);
   else if(c1 < s_low[si])  TryTrade(si, false);
  }

//==================================================================//
//                              OnTick                              //
//==================================================================//
void OnTick()
  {
   if(!NewBar()) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   for(int si = 0; si < MAX_SESSIONS; si++)
      ProcessSession(si, tm.hour);
  }
//+------------------------------------------------------------------+
