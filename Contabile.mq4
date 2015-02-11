//+------------------------------------------------------------------+
//|                                                    Contabile.mq4 |
//|                                                 Lorenzo Pedrotti |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti"
#property link      "www.wannabetrader.com"
#property version   "1.00"
#property strict

//#include <OrderReliable_V1_1_1.mqh>

//--- input parameters
input bool     AutoClose=false; // Chiudi gli ordini all'obiettivo indicato
input bool     OnlyProfit=false; // Chiudi solo gli ordini in profit
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

const string the_box = "cnt_the_box";

int OnInit()
{
//---
   ObjectCreate(the_box, OBJ_LABEL, 0, 0, 0, 0, 0);
   ObjectSetText(the_box, "gggggggggg",35, "Webdings");      
   ObjectSet(the_box, OBJPROP_CORNER, 2);
   ObjectSet(the_box, OBJPROP_BACK, false);
   ObjectSet(the_box, OBJPROP_XDISTANCE, 5);
   ObjectSet(the_box, OBJPROP_YDISTANCE, 15 );    
   ObjectSet(the_box, OBJPROP_COLOR, clrWheat);   
 
 
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
   
   ObjectCreate(sell_even,OBJ_HLINE,0,0,0);
   ObjectSet(sell_even, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   ObjectSet(sell_even, OBJPROP_COLOR, clrYellow); 
   ObjectSet(sell_even, OBJPROP_WIDTH, 1);

   ObjectCreate(buy_even,OBJ_HLINE,0,0,0);
   ObjectSet(buy_even, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   ObjectSet(buy_even, OBJPROP_COLOR, clrYellow); 
   ObjectSet(buy_even, OBJPROP_WIDTH, 1);

   ObjectCreate(sell_target,OBJ_HLINE,0,0,0);
   ObjectSet(sell_target, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   ObjectSet(sell_target, OBJPROP_COLOR, clrBlue); 
   ObjectSet(sell_target, OBJPROP_WIDTH, 1);

   ObjectCreate(buy_target,OBJ_HLINE,0,0,0);
   ObjectSet(buy_target, OBJPROP_STYLE, STYLE_DASHDOTDOT); 
   //ObjectSet(buy_target, OBJPROP_COLOR, clrBlue); 
   //ObjectSet(buy_target, OBJPROP_WIDTH, 1);
 
   
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
                  color_short = clrGreen;
               else
                  color_short = clrRed;
            }
            if (OrderType() == OP_BUY) {
               tot_long += OrderProfit() + OrderCommission() + OrderSwap();
               num_long ++;
               lot_long += OrderLots();
               avg_long += OrderOpenPrice()*OrderLots();
               if (tot_long > 0)
                  color_long = clrGreen;
               else
                  color_long = clrRed;
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
   //ObjectMove(sell_target,0,0,tg_short);
   //ObjectMove(buy_target,0,0,tg_long);

   string auto = "";
   if (AutoClose) { auto = "*"; }
   ObjectSetText(sell_label,StringFormat("Short: (O: %d) (L: %.2f) (A: %.2f) (T: %.2f) %.2f ",num_short,lot_short,avg_short,ShortCloseAt,tot_short),10,"Verdana",color_short);
   ObjectSetText(buy_label,StringFormat("%sLong: (O: %d) (L: %.2f) (A: %.2f) (T: %.2f) %.2f",auto,num_long,lot_long,avg_long,LongCloseAt,tot_long),10,"Verdana",color_long);

   if (AutoClose) {
      long r = MathRand();
      
      if (tot_short >= ShortCloseAt) {
         for (int k=OrdersTotal()-1;k>=0;k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
               if ((OrderSymbol() == Symbol()) && (OrderType() == OP_SELL)) {
                  if (((OnlyProfit) && (OrderProfit() > 0)) || (!OnlyProfit) ){ 
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
                  if (((OnlyProfit) && (OrderProfit() > 0)) || (!OnlyProfit) ){                
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
