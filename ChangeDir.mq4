//+------------------------------------------------------------------+
//|                                                 AverageSpeed.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "InvertDown"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "InvertUp"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTurquoise
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "ClosePos"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- input parameters
input int      ppAvg1=21; // Periods of the Average

input int      ppMode = 1; // Iedntification mode
const int      MODE_ANY_CROSS = 1;
const int      MODE_ZERO_CROSS = 2;

//--- indicator buffers
double         InvertDownBuffer[];
double         InvertUpBuffer[];
double         CloseBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
   SetIndexArrow(0, 234);
   SetIndexBuffer(0,InvertDownBuffer);
   SetIndexArrow(1, 233);
   SetIndexBuffer(1,InvertUpBuffer);
   SetIndexArrow(2, 74);
   SetIndexBuffer(2,CloseBuffer);
   
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+

double ggDistance = 0;
//bool ggDistCalculated = false;

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
   if (rates_total < 30) return 0;
   
   if (ggDistance==0) {
      int k;
      for (k=0;k<20;k++) {
         ggDistance+=high[k]-low[k];
      }
      ggDistance = ggDistance / k;
   }
   
   int limit=rates_total-prev_calculated;
   
   for(int i=0; i<limit; i++) {
      InvertUpBuffer[i] = 0;
      InvertDownBuffer[i] = 0;
      CloseBuffer[i] = 0;
      if (ppAvg1 > 0) {
         if (ppMode == MODE_ANY_CROSS) {
            
            double b1_a = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 1,i); // linea davanti
            double b1_d = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 1,i+1); // dietro
            double b2_a = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 2,i); // signal davanti
            double b2_d = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 2,i+1); // dietro
            if (b1_a > b2_a && b1_d < b2_d) InvertUpBuffer[i] = low[i] - ggDistance;
            if (b1_a < b2_a && b1_d > b2_d) InvertDownBuffer[i] = high[i] + ggDistance;
         }
         if (ppMode == MODE_ZERO_CROSS) {
            double b1 = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3,1,i); // davanti
            double b2 = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3,1,i+1); // dietro
         
            if (b1 >= 0 && b2 < 0) InvertUpBuffer[i] = low[i] - ggDistance;
            if (b1 <= 0 && b2 > 0) InvertDownBuffer[i] = high[i] + ggDistance;
         }
      }
   }

   return(rates_total);
}