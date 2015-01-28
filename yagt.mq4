//+------------------------------------------------------------------+
//|                                                    SuperGrid.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "1.00"
#property strict
//--- input parameters
input int      ciccio=1;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int big_timeframe = PERIOD_H1;
string trend = "n/a";

struct zigzag {
   double p0;
   double p1;
   double midway;
};


int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   const string the_box="Z_Box";
   ObjectCreate(the_box,OBJ_LABEL,0,0,0,0,0);
   ObjectSetText(the_box,"gggg",60,"Webdings");
   ObjectSet(the_box,OBJPROP_CORNER,2);
   ObjectSet(the_box,OBJPROP_BACK,false);
   ObjectSet(the_box,OBJPROP_XDISTANCE,5);
   ObjectSet(the_box,OBJPROP_YDISTANCE,15);
   ObjectSet(the_box,OBJPROP_COLOR,clrWhite);

/*
   switch(Period()) {
      case PERIOD_M1: big_timeframe = PERIOD_M5; break;
      case PERIOD_M5: big_timeframe = PERIOD_M15; break;
      case PERIOD_M15: big_timeframe = PERIOD_H1; break;
   }
*/
   MakeLabel("Trend","Trend",20,20);
   MakeLabel("Zig","Zig",20,35);
   CheckTrend();

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   CleanUp();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   zigzag zz = ZigZag();
   ChangeLabel("Zig",string(zz.p0) + " - " + string(zz.p1) + " mid " + string(zz.midway));

}


zigzag ZigZag() {
   // restituisce i due punti di zigzag validi
   
   zigzag zz = {0,0,0};
   int k=1; // se è sulla candela corrente non mi interessa
   
   while (zz.p0 == 0) {
      zz.p0 = iCustom(NULL,0,"ZigZag",12,5,3,0,k);
      k++;
   }
   
   while (zz.p1 == 0) {
      zz.p1 = iCustom(NULL,0,"ZigZag",12,5,3,0,k);
      k++;
   }
   
   zz.midway = MathAbs((zz.p0 + zz.p1)/2);
   
   return zz;
}


void CheckTrend() {
   double c_fast = iMA(Symbol(),PERIOD_CURRENT,21,0,MODE_EMA,PRICE_CLOSE,0);
   double c_slow = iMA(Symbol(),PERIOD_CURRENT,43,0,MODE_EMA,PRICE_CLOSE,0);
   /*
   double u_fast = iMA(Symbol(),big_timeframe,21,0,MODE_EMA,PRICE_CLOSE,0);
   double u_slow = iMA(Symbol(),big_timeframe,43,0,MODE_EMA,PRICE_CLOSE,0);
   */
   trend = "n/a";
   
   
//   if ((u_fast > u_slow) && (c_fast > c_slow)) trend = "UP";
//   if ((u_fast < u_slow) && (c_fast < c_slow)) trend = "DOWN";
   if ((c_fast > c_slow)) trend = "UP";
   if ((c_fast < c_slow)) trend = "DOWN";
   ChangeLabel("Trend","Trend: " + trend);
   
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
      CheckTrend();
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+

void MakeLabel(string name,string text,int x,int y) 
  {
   name="Z_"+name;
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,text,10,"Verdana",clrBlack);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChangeLabel(string name,string text) 
  {
   name="Z_"+name;
   ObjectSetText(name,text,10,"Verdana",clrBlack);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CleanUp() 
  {
   int obj_total=ObjectsTotal();
   string name="";
   for(int i=obj_total-1;i>=0;i--) 
     {
      name=ObjectName(i);
      if(StringSubstr(name,0,2)=="Z_") 
        {
         ObjectDelete(name);
        }
     }
  }
//+------------------------------------------------------------------+
