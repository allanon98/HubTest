//+------------------------------------------------------------------+
//|                                                 AverageSpeed.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3
//--- plot Average1
#property indicator_label1  "Average1"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
//--- input parameters
input int      ppAvg1=21;
//--- indicator buffers
double         Average1Buffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,Average1Buffer);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   
   if (rates_total < ppAvg1) return 0;
   
   
   int limit=rates_total-prev_calculated;
   
   double v1, v2;
   int x = 3;
   for(int i=0; i<limit; i++) {
      if (ppAvg1 > 0) {
         v1 = iMA(NULL,0,ppAvg1,0,MODE_EMA,PRICE_CLOSE,i);
         v2 = iMA(NULL,0,ppAvg1,0,MODE_EMA,PRICE_CLOSE,i+x);
         if (v2 > 0)
         Average1Buffer[i] = -1 * ( 100-(100*(v1/v2)));
      }
   }



   return(rates_total);
}
