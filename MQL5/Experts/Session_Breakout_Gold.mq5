//+------------------------------------------------------------------+
//|                                  Session_Breakout_Gold.mq5        |
//|  Breakout strategy: Asian session range breakout at London open  |
//+------------------------------------------------------------------+
#property copyright "Generated for educational/testing purposes"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input int      InpAsianStartHour   = 0;
input int      InpAsianEndHour     = 7;
input int      InpSessionHour      = 8;
input int      InpSessionEndHour   = 11;
input double   InpLotSize          = 0.10;
input int      InpSL_BufferPoints  = 50;
input double   InpRR_Ratio         = 2.0;
input int      InpMaxSpreadPoints  = 350;
input int      InpMagicNumber      = 100003;

double   rangeHigh     = 0;
double   rangeLow      = 0;
datetime lastRangeDate = 0;

//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
bool NewBar()
  {
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void BuildAsianRange()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   datetime todayMidnight = TimeCurrent() - (tm.hour * 3600 + tm.min * 60 + tm.sec);
   if(lastRangeDate == todayMidnight) return;

   datetime rangeStart = todayMidnight + InpAsianStartHour * 3600;
   datetime rangeEnd   = todayMidnight + InpAsianEndHour   * 3600;
   if(TimeCurrent() < rangeEnd) return;

   double highest = -1, lowest = -1;
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   for(int i = 0; i < bars; i++)
     {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t < rangeStart) break;
      if(t >= rangeStart && t < rangeEnd)
        {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i);
         double l = iLow(_Symbol, PERIOD_CURRENT, i);
         if(highest < 0 || h > highest) highest = h;
         if(lowest  < 0 || l < lowest)  lowest  = l;
        }
     }

   if(highest > 0 && lowest > 0)
     {
      rangeHigh     = highest;
      rangeLow      = lowest;
      lastRangeDate = todayMidnight;
      Print("Asian range: High=", rangeHigh, " Low=", rangeLow);
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(!NewBar()) return;
   BuildAsianRange();

   if(rangeHigh <= 0 || rangeLow <= 0) return;
   if(HasOpenPosition()) return;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour < InpSessionHour || tm.hour >= InpSessionEndHour) return;

   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double point  = _Point;

   if(close1 > rangeHigh)
     {
      double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double slDistance = (rangeHigh - rangeLow) + InpSL_BufferPoints * point;
      trade.Buy(InpLotSize, _Symbol, ask, ask - slDistance, ask + slDistance * InpRR_Ratio, "SB_Buy");
     }
   else if(close1 < rangeLow)
     {
      double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slDistance = (rangeHigh - rangeLow) + InpSL_BufferPoints * point;
      trade.Sell(InpLotSize, _Symbol, bid, bid + slDistance, bid - slDistance * InpRR_Ratio, "SB_Sell");
     }
  }
//+------------------------------------------------------------------+
