//+------------------------------------------------------------------+
//|                                                  TrendHunter.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                     http://www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "http://www.wannabetrader.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      ppTimeFrame = 1; // Timeframe of the EA
input int      ppAvg1 = 21; // Timeframe of the speed average


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

string ggLabel = "TH_"; 

int OnInit(){
   ggLabel = "TH_" + Symbol();
   ggTrend = ggTrend_old = "X";

   Comment(ggLabel);
   int start_at = 20;
   int delta = 15;
   xMakeLabel("Trend","Trend:",20,start_at);
   xMakeLabel("Long","Long:",20,start_at+=delta);
   xMakeLabel("Short","Short:",20,start_at+=delta);
   xMakeLabel("Balance","Balance:",20,start_at+=delta);
   
   
   
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
   
   zCheckOrders();
   zCheckTrend();
   zPlaceOrders();
   if (ggTrend_old != ggTrend) {
      zPlaceOrders();
      ggTrend_old = ggTrend;
   }
   
   
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
   if (ggTrend == "U" && ggLong.lots == 0) {
   //if ( ggLong.lots == 0) {
      Target = Ask+300*Point;
      if (ggBalance < 0) {
         PositionSize = xPosSize(Symbol(),MathAbs(ggBalance),1000,Ask,Target);
         if (PositionSize < 0.01) PositionSize = 0.01;
      } 
      x = OrderSend(Symbol(),OP_BUY,PositionSize,Ask,200,Bid-200*Point,Target,ggLabel,123456,0,clrYellow);
      // controllo eventuali ordini short da chiudere
      if (ggShort.ticket != 0 && ggShort.profit > 0) {
         x = OrderSelect(ggShort.ticket,SELECT_BY_TICKET);
         x = OrderClose(ggShort.ticket,OrderLots(),MarketInfo(Symbol(),MODE_ASK),200,clrRed);
      }
   }
   if (ggTrend == "D" && ggShort.lots == 0) {
      Target = Bid-300*Point;
      if (ggBalance < 0) {
         PositionSize = xPosSize(Symbol(),MathAbs(ggBalance),1000,Bid,Target);
         if (PositionSize < 0.01) PositionSize = 0.01;
      } 
      x = OrderSend(Symbol(),OP_SELL,PositionSize,Bid,200,Ask+200*Point,Target,ggLabel,123456,0,clrYellow);
      if (ggLong.ticket != 0 && ggLong.profit > 0) {
         x = OrderSelect(ggLong.ticket,SELECT_BY_TICKET);
         x = OrderClose(ggLong.ticket,OrderLots(),MarketInfo(Symbol(),MODE_BID),200,clrRed);
      }
         
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



void zCheckTrend() {
 
/*
   double t_down = iCustom(NULL,ppTimeFrame,"ChangeDir",avg,mode,0,1); 
   double t_up = iCustom(NULL,ppTimeFrame,"ChangeDir",avg,mode,1,1); 
   if (t_down != 0) ggTrend = "D";
   if (t_up != 0) ggTrend = "U";
*/   
   double b1 = iCustom(NULL,ppTimeFrame,"AverageSpeed",ppAvg1,0,1); // davanti
   double b2 = iCustom(NULL,ppTimeFrame,"AverageSpeed",ppAvg1,0,2); // dietro
   if (b1 >= 0 && b2 < 0) ggTrend = "U";
   if (b1 < 0 && b2 >= 0) ggTrend = "D";
   
   xChangeLabel("Trend","Trend: " + ggTrend + " - " + ggTrend_old);   
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
  