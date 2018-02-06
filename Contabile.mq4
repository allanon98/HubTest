//+------------------------------------------------------------------+
//|                                                    Contabile.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "2.00"
#property strict

// modificato per vedere se arriva nella versione forked

//--- input parameters
input bool     AutoClose=false; // Chiudi gli ordini all'obiettivo indicato
input bool     OnlyProfit=false; // Chiudi solo gli ordini in profit
input double   MinProfit = 0.0; // Solo se singolo profit maggiore di
input double   ShortCloseAt=0.0; // Obiettivo di guadagno short
input double   LongCloseAt=0.0; // Obiettivo di guadagno long

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

const string buy_label = "cnt_buy_label";
const string sell_label = "cnt_sell_label";

const string buy_even = "cnt_buy_even";
const string sell_even = "cnt_sell_even";

const string buy_target = "cnt_buy_target";
const string sell_target = "cnt_sell_target";

const string info_label = "cnt_infos";

const string the_box = "cnt_the_box";

int OnInit()
{
//---
/*
   ObjectCreate(the_box, OBJ_LABEL, 0, 0, 0, 0, 0);
   ObjectSetText(the_box, "ggggg",65, "Webdings");      
   ObjectSet(the_box, OBJPROP_CORNER, 2);
   ObjectSet(the_box, OBJPROP_BACK, false);
   ObjectSet(the_box, OBJPROP_XDISTANCE, 5);
   ObjectSet(the_box, OBJPROP_YDISTANCE, 15 );    
   ObjectSet(the_box, OBJPROP_COLOR, clrWheat);   
*/
 
   ObjectCreate(buy_label,OBJ_LABEL,0,0,0);
   ObjectSetText(buy_label,"Long: 0",10,"Verdana",clrBlack);
   ObjectSet(buy_label,OBJPROP_CORNER,2);
   ObjectSet(buy_label,OBJPROP_XDISTANCE,20);
   ObjectSet(buy_label,OBJPROP_YDISTANCE,20);
   
   ObjectCreate(sell_label,OBJ_LABEL,0,0,0);
   ObjectSetText(sell_label,"Short: 0",10,"Verdana",clrBlack);
   ObjectSet(sell_label,OBJPROP_CORNER,2);
   ObjectSet(sell_label,OBJPROP_XDISTANCE,20);
   ObjectSet(sell_label,OBJPROP_YDISTANCE,40);
 
   ObjectCreate(info_label,OBJ_LABEL,0,0,0);
   ObjectSetText(info_label,"Info: ?",10,"Verdana",clrYellow);
   ObjectSet(info_label,OBJPROP_CORNER,2);
   ObjectSet(info_label,OBJPROP_XDISTANCE,20);
   ObjectSet(info_label,OBJPROP_YDISTANCE,60);
 
 
   
   ObjectCreate(sell_even,OBJ_HLINE,0,0,0);
   ObjectSet(sell_even, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   ObjectSet(sell_even, OBJPROP_COLOR, clrYellow); 
   ObjectSet(sell_even, OBJPROP_WIDTH, 1);

   ObjectCreate(buy_even,OBJ_HLINE,0,0,0);
   ObjectSet(buy_even, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   ObjectSet(buy_even, OBJPROP_COLOR, clrYellow); 
   ObjectSet(buy_even, OBJPROP_WIDTH, 1);
   
   MathSrand(GetTickCount());
//---
return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   ObjectDelete(buy_label);
   ObjectDelete(sell_label);
   ObjectDelete(buy_even);
   ObjectDelete(sell_even);
   ObjectDelete(the_box);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   // perdita/guadagno in ogni direzione
   double tot_long = 0;
   double tot_short = 0;
   
   // numero di posizioni in ogni direzione
   int num_long = 0;
   int num_short = 0;
   
   // somma dei lotti investiti in ogni direzione
   double lot_long = 0;
   double lot_short = 0; 
   
   // prezzo medio di acquisto/vendita
   double avg_long = 0;
   double avg_short = 0;
   
   double tg_long = 0;
   double tg_short = 0;
   
   bool rt;
   
   int color_short = clrBlack;
   int color_long = clrBlack;

   for (int k = 0; k<OrdersTotal(); k++) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
         if (OrderSymbol() == Symbol()) {
            if (OrderType() == OP_SELL) {
               tot_short += OrderProfit() + OrderCommission() + OrderSwap();
               num_short ++;
               lot_short += OrderLots();
               avg_short += OrderOpenPrice()*OrderLots();
               if (tot_short > 0)
                  color_short = clrLightGreen;
               else
                  color_short = clrPink;
            }
            if (OrderType() == OP_BUY) {
               tot_long += OrderProfit() + OrderCommission() + OrderSwap();
               num_long ++;
               lot_long += OrderLots();
               avg_long += OrderOpenPrice()*OrderLots();
               if (tot_long > 0)
                  color_long = clrLightGreen;
               else
                  color_long = clrPink;
            }
         }
      }
   }
   
   if (num_short>0) {
      avg_short = avg_short / lot_short;
   }
   if (num_long>0) {
      avg_long = avg_long / lot_long;
   }
   
   ObjectMove(sell_even,0,0,avg_short);
   ObjectMove(buy_even,0,0,avg_long);

   string auto = "";
   if (AutoClose) { auto = "TRADING"; }
   ObjectSetText(sell_label,StringFormat("Short: (O: %d) (L: %.2f) (A: %.2f) (T: %.2f) %.2f ",num_short,lot_short,avg_short,ShortCloseAt,tot_short),10,"Verdana",color_short);
   ObjectSetText(buy_label,StringFormat("Long: (O: %d) (L: %.2f) (A: %.2f) (T: %.2f) %.2f",num_long,lot_long,avg_long,LongCloseAt,tot_long),10,"Verdana",color_long);
   
   // per chiudere in pari in 200 punti
   double ps_short = xPosSize(Symbol(),MathAbs(tot_short),10000,Bid,Bid-200*Point);
   double ps_long =  xPosSize(Symbol(),MathAbs(tot_long),10000,Ask,Ask-200*Point);
   if (ps_short < 0) ps_short=0;
   if (ps_long < 0) ps_long = 0;
   ObjectSetText(info_label,StringFormat("%s - Ln: %.2f - Sh: %.2f",auto,ps_long,ps_short),10,"Verdana",clrYellow);
   
   if (AutoClose) {
      long r = MathRand();
      
      if (tot_short >= ShortCloseAt) {
         for (int k=OrdersTotal()-1;k>=0;k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
               if ((OrderSymbol() == Symbol()) && (OrderType() == OP_SELL)) {
                  if ((OnlyProfit && OrderProfit() >= MinProfit) || (!OnlyProfit) ){ 
                     rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),200,clrYellowGreen);
                     // mail di conferma
                     string subj = StringFormat("CONTABILE. (%.2f) Chiuso SHORT su %s - %d",OrderProfit(),Symbol(),r);
                     string mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                             Symbol(),OrderLots(),OrderProfit());
                     SendMail(subj,mex);
                  }
               }
            }
         }
      }
      if (tot_long >= LongCloseAt) {
         for (int k=OrdersTotal()-1;k>=0;k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
               if ((OrderSymbol() == Symbol()) && (OrderType() == OP_BUY)) {
                  if ((OnlyProfit && OrderProfit() >= MinProfit) || (!OnlyProfit) ){                
                     rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),200,clrYellowGreen);
                     // mail di conferma
                     string subj = StringFormat("CONTABILE. (%.2f) Chiuso LONG su %s __%d",OrderProfit(),Symbol(),r);
                     string mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                             Symbol(),OrderLots(),OrderProfit());
                     SendMail(subj,mex);
                  }
               }
            }
         }
      }
      
   }
   
      

}
//+------------------------------------------------------------------+

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
