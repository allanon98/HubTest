//+------------------------------------------------------------------+
//|                                                  TrendHunter.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                     http://www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "http://www.wannabetrader.com"
#property version   "2.00"
#property strict

//--- input parameters
input int      ppTimeFrame = 5; // Timeframe of the EA
input int      ppAvg1 = 21; // Timeframe of the speed average
// CI ANDREBBERO ANCHE GLI ALTRI PARAMETRI o abolire anche questo
input int      ppStopLoss = 150; // Points for the stop loss
input int      ppTakeProfit = 300; // Points for take profit



input color    ppLabelColor = clrAqua;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


struct s_order_data {
   int ticket;
   double lots;
   double profit;
};



string ggTrend = "X";
string ggTrend_old = "X";

s_order_data ggLong = {0,0,0};
s_order_data ggShort = {0,0,0};

double ggBalance = 0;

string ggLabel = "TH_" + Symbol(); 
int ggMinute = 0;
string varBalance = "Balance_" + ggLabel;

int ggMagic = 1;


int OnInit(){
   //ggLabel = "TH_" + Symbol();
   ggTrend = ggTrend_old = "X";

   Comment(ggLabel);
   int start_at = 20;
   int delta = 15;
   xMakeLabel("Trend","Trend:",20,start_at);
   xMakeLabel("Long","Long:",20,start_at+=delta);
   xMakeLabel("Short","Short:",20,start_at+=delta);
   xMakeLabel("Balance","Balance:",20,start_at+=delta);
   
   MqlDateTime mdt;
   datetime dt = TimeLocal(mdt);
   ggMinute = mdt.min;
   
   if (GlobalVariableCheck(varBalance)) {
      ggBalance = GlobalVariableGet(varBalance);
   } else {
      GlobalVariableSet(varBalance,ggBalance);
   }
   
   // crea il magic number
   for (int y=0; y<StringLen(Symbol()); y++) {
      ggMagic = ggMagic * StringGetChar(Symbol(),y);
   }
   ggMagic = MathAbs(ggMagic);
   //Alert(ggMagic);
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   xCleanUp();
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   ggBalance = GlobalVariableGet(varBalance);
   if (ggBalance > 0) {
      SendMail(StringFormat("TrendHunder %s",Symbol()),StringFormat("Balance stored: %.2f",ggBalance));
      ggBalance = 0;
   }
   zCheckOrders();
   zCheckTrend();
   if (ggTrend_old != ggTrend) {
      zPlaceOrders();
      ggTrend_old = ggTrend;
   }
   GlobalVariableSet(varBalance,ggBalance);
   
}
//+------------------------------------------------------------------+

void zPlaceOrders() {
/*
Posizioni LONG aprono su Ask e chiudono su Bid
Short il contrario
*/
   double PositionSize = 0.01;
   double Target = 0;
   int x;
   double lBalance = ggBalance; // così non interferisce con il calcolo del balance
   
   if (ggTrend == "U" && ggLong.lots == 0) {
      // controllo eventuali ordini short da chiudere
      if (ggShort.ticket != 0 /* && ggShort.profit > 0 */) {
         x = OrderSelect(ggShort.ticket,SELECT_BY_TICKET);
         x = OrderClose(ggShort.ticket,OrderLots(),MarketInfo(Symbol(),MODE_ASK),200,clrRed);
         lBalance += OrderProfit() + OrderCommission() + OrderSwap();
      }
      Target = Ask+ppTakeProfit*Point;
      if (lBalance < 0) {
         PositionSize = xPosSize(Symbol(),MathAbs(lBalance),10000,Ask,Target);
         if (PositionSize < 0.01) PositionSize = 0.01;
      } 
      x = OrderSend(Symbol(),OP_BUY,PositionSize*1.5,Ask,200,Bid-ppStopLoss*Point,Target,ggLabel,ggMagic,0,clrYellow);
      
   }
   if (ggTrend == "D" && ggShort.lots == 0) {
      if (ggLong.ticket != 0 /* && ggLong.profit > 0 */) {
         x = OrderSelect(ggLong.ticket,SELECT_BY_TICKET);
         x = OrderClose(ggLong.ticket,OrderLots(),MarketInfo(Symbol(),MODE_BID),200,clrRed);
         lBalance += OrderProfit() + OrderCommission() + OrderSwap();
      }

      Target = Bid-ppTakeProfit*Point;
      if (lBalance < 0) {
         PositionSize = xPosSize(Symbol(),MathAbs(lBalance),10000,Bid,Target);
         if (PositionSize < 0.01) PositionSize = 0.01;
      } 
      x = OrderSend(Symbol(),OP_SELL,PositionSize*1.5,Bid,200,Ask+ppStopLoss*Point,Target,ggLabel,ggMagic,0,clrYellow);
         
   }

}


void zCheckOrders() {
   /*
   Un ordine potrebbe essere chiuso dall'esterno o a causa
   di stop/profit
   */
   if (ggLong.ticket != 0) {
      if (OrderSelect(ggLong.ticket,SELECT_BY_TICKET)) {
         if (OrderCloseTime() != 0) {
            // è in history, quindi chiuso
            ggBalance += OrderProfit() + OrderCommission() + OrderSwap();
         }
      }
   }
   if (ggShort.ticket != 0) {
      if (OrderSelect(ggShort.ticket,SELECT_BY_TICKET)) {
         if (OrderCloseTime() != 0) {
            ggBalance += OrderProfit() + OrderCommission() + OrderSwap();
         }
      }
   }

   /*
   Analizza le posizioni aperte alla ricerca dei dati Long/Short
   */
   ggLong.lots = ggShort.lots = 0;
   ggLong.ticket = ggShort.ticket = 0;
   ggLong.profit = ggShort.profit = 0;
   for (int k = 0; k<OrdersTotal(); k++) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
         string oc = OrderComment();
         if (OrderSymbol() == Symbol() && oc == ggLabel) {
            switch (OrderType()) {
               case OP_BUY:
                  ggLong.lots = OrderLots();
                  ggLong.ticket = OrderTicket();
                  ggLong.profit = OrderProfit() + OrderCommission() + OrderSwap();
                  break;
               case OP_SELL:
                  ggShort.lots = OrderLots();
                  ggShort.ticket = OrderTicket();
                  ggShort.profit = OrderProfit() + OrderCommission() + OrderSwap();
                  break;
            }
         }
      }
   }
   
   
   
 
   xChangeLabel("Long",StringFormat("Long - Lots: %.2f - Profit: %.2f",ggLong.lots,ggLong.profit));
   xChangeLabel("Short",StringFormat("Short - Lots: %.2f - Profit: %.2f",ggShort.lots,ggShort.profit));
   xChangeLabel("Balance",StringFormat("Balance: %.2f",ggBalance));

}

/*
void zCheckTrend() {
 
   double b1 = iCustom(NULL,ppTimeFrame,"AverageSpeed",ppAvg1,0,1); // davanti
   double b2 = iCustom(NULL,ppTimeFrame,"AverageSpeed",ppAvg1,0,2); // dietro
   if (b1 >= 0 && b2 < 0) ggTrend = "U";
   if (b1 < 0 && b2 >= 0) ggTrend = "D";
   
   xChangeLabel("Trend","Trend: " + ggTrend + " - " + ggTrend_old);   
}

*/

void zCheckTrend() {

   // questo simula la modalità 1 di ChangeDir
   double b1_a = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 1,1); // linea davanti
   double b1_d = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 1,2); // dietro
   double b2_a = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 2,1); // signal davanti
   double b2_d = iCustom(NULL,0,"PZ_Average_Speed",ppAvg1,9,3, 2,2); // dietro
   if (b1_a > b2_a && b1_d < b2_d) ggTrend = "U";
   if (b1_a < b2_a && b1_d > b2_d) ggTrend = "D";
   

  
   xChangeLabel("Trend",StringFormat("%s Trend: %s - %s  - TF: %d" ,ggLabel, ggTrend ,ggTrend_old,ppTimeFrame));   
}


void xMakeLabel(string name,string text,int x,int y) 
  {
   name="Z_"+name;
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,text,10,"Verdana",ppLabelColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
  }

void xChangeLabel(string name,string text) 
  {
   name="Z_"+name;
   ObjectSetText(name,text,10,"Verdana",ppLabelColor);
  }

void xCleanUp() 
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


double xPosSize( string Sym, double RiskAmt, double MarginAmt, double Entry, double StopLoss )
{
   double Lots, Lots1, Lots2;
   double RiskPips;
   double RateToAcc;
   double LotStep;
   double LotSteps;

   // limit according to stop-loss risk
   RiskPips = MathAbs( Entry - StopLoss ) / MarketInfo( Sym, MODE_TICKSIZE ); // or should this be "/ Point"?
   RateToAcc = MarketInfo( Sym, MODE_TICKVALUE );
   Lots1 = RiskAmt / ( RiskPips * RateToAcc );

   // limit according to margin requirement
   Lots2 = MarginAmt / MarketInfo( Sym, MODE_MARGINREQUIRED );  // given margin / margin cost of one lot
   
   // the lower of the two limits
   Lots = MathMin( Lots1, Lots2 );

   // round down to the nearest lot step
   LotStep = MarketInfo( Sym, MODE_LOTSTEP );
   LotSteps = MathFloor( Lots / LotStep );
   Lots = LotSteps * LotStep;
   
   // if too small return -1
   if( Lots < MarketInfo( Sym, MODE_MINLOT ) )
      if( Lots1 < Lots2 ) Lots = -1;
      else Lots = -2;
   
   return( Lots );
}  
  