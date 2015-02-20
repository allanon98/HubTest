//+------------------------------------------------------------------+
//|                                                TrendFinderEA.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "1.00"
#property strict
//--- input parameters
input string   ppSourceFile = "symbols.txt"; // File with the symbols
input int      ppAverage1 = 21; // First average
input int      ppAverage2 = 43; // Second average


struct s_symbol {
   string symname;
   //bool mailsent;
   int trend;
};

s_symbol ggSymbols[];
int ggTimeFrames[3] = {PERIOD_M15,PERIOD_H1,PERIOD_D1};

const int TREND_UP = 1;
const int TREND_DOWN = 2;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   int handle=FileOpen(ppSourceFile,FILE_READ|FILE_TXT);
   string symbols[];
   if (handle != INVALID_HANDLE) {
      FileReadArray(handle,symbols);
      Print("File caricato correttamente");
      FileClose(handle);
      ArrayResize(ggSymbols,ArraySize(symbols));
      for(int j=0; j<ArraySize(symbols); j++) {
         ggSymbols[j].symname = symbols[j];
         //ggSymbols[j].mailsent = false;
         ggSymbols[j].trend = 0;
      }
   } else {
      Alert("Impossibile aprire il file " + ppSourceFile);
      return (INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int ggLastMinute = -1;
MqlDateTime mdt;

void OnTick() {
   
   datetime dt = TimeLocal(mdt);
   if ((mdt.min == 0 || mdt.min == 15 || mdt.min == 30 || mdt.min == 45) &&
         (ggLastMinute != mdt.min)) {
      Print("Minuto: ", mdt.min);
      ggLastMinute = mdt.min;
      ON_CandleChange();
   }

   
}
//+------------------------------------------------------------------+

void ON_CandleChange() {
   double c_fast, c_slow;
   int candle;
   string sy;
   int lPeriod = 0;
   int trends[3] = {0,0,0};
   
   for(int j=0; j<ArraySize(ggSymbols); j++) {
      Print ("Symbol: ", ggSymbols[j].symname);
      for (int t=0; t<ArraySize(ggTimeFrames);t++) {
         sy = ggSymbols[j].symname;
         lPeriod = ggTimeFrames[t];
         c_fast = iMA(sy,lPeriod,21,0,MODE_EMA,PRICE_CLOSE,0);
         c_slow = iMA(sy,lPeriod,43,0,MODE_EMA,PRICE_CLOSE,0);
         candle = 0;
         if (c_fast > c_slow) {
            trends[t] = TREND_UP;
            while (c_fast > c_slow) {
               candle++;
               c_fast = iMA(sy,lPeriod,21,0,MODE_EMA,PRICE_CLOSE,candle);
               c_slow = iMA(sy,lPeriod,43,0,MODE_EMA,PRICE_CLOSE,candle);
            }
            c_fast=c_slow=0; // questo serve solo a far fallire l'IF seguente
         } 
         if (c_fast < c_slow) {
            trends[t] = TREND_DOWN;
            while (c_fast < c_slow) {
               candle++;
               c_fast = iMA(sy,lPeriod,21,0,MODE_EMA,PRICE_CLOSE,candle);
               c_slow = iMA(sy,lPeriod,43,0,MODE_EMA,PRICE_CLOSE,candle);
            }
         }
      }
      // CONTROLLO DEI TREND
      if (trends[0] == trends[1] && trends[1] == trends[2]) {
         string tr = "UP";
         if (trends[0] == TREND_DOWN) tr = "DOWN";
         if (ggSymbols[j].trend != trends[0]) {
            SendMail(StringFormat("NewTrend %s -> %s @ %d:%d",sy,tr,mdt.hour,mdt.min),"New trend detected!");
            ggSymbols[j].trend = trends[0];
         }
      }
   }


}