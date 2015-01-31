//+------------------------------------------------------------------+
//|                                                    SuperGrid.mq4 |
//|                                 Lorenzo Pedrotti & Simone Forini |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti & Simone Forini"
#property link      "www.wannabetrader.com"
#property version   "1.01"
#property strict
//--- input parameters
input string      ppSignature = "YAGT_0001"; // Session initial signature
input bool        ppChangeSig = false; // Change signature at trend change
input bool        ppHedging = false; // Place a hedging order at trend change

input int         ppInitDiff = 300; // Points up/down of the first pending orders
input int         ppMaxPos = 10; // Max allowed positions (per trend)

input int         ppStep = 300; // Points before open a new position
input double      ppInitVolume = 0.01; // Size of the first lot
input double      ppIncrease = 0.003; // Size of the increment lot


input double      ppCloseProfit = 2; // Close when profit is at least (euro)
input bool        ppChopMode = true; // Close only the newsest orders
input bool        ppStopEven = false; // Close ALL at profit and STOP

input color       ppLabelColor = clrWhite; // Labels color
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

string ggTrend = "n/a"; // il trend calcolato
string ggOrderTrend = "n/a"; // il trend degli ordini

string ggSignature = ppSignature; // questo succede solo quando parte EA per la prima volta

struct orders_data {
   int positions;
   double lots;
   double profit;
   double average;
   double worst; // prezzo dell'ultimo ordine
   int last_ticket; // ticket dell'ultimo ordine eseguito
};

orders_data ggLongs = {0,0,0,0,0,0};
orders_data ggShorts = {0,0,0,0,0,0};

bool ggStopped = false;
bool ggPending = false; // ci sono ancora gli ordini pending

double ggBalance = 0; // contabilità interna del sistema

int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   ggStopped = false;
   
   int start_at = 20;
   int delta = 15;
   MakeLabel("Trend","Trend",20,start_at);
   MakeLabel("Shorts","Shorts:",20,start_at+=delta);
   MakeLabel("Longs","Longs:",20,start_at+=delta);
   MakeLabel("Infos",ggSignature,20,start_at+=delta);
   MakeLabel("Active","ACTIVE",150,start_at);
   MakeLabel("Balance","Profit: XX",250,start_at);
   
   MakeLine("SellEven",STYLE_DASHDOTDOT,clrYellow,1);
   MakeLine("BuyEven",STYLE_DASHDOTDOT,clrYellow,1);
   MakeLine("NextEntry",STYLE_DOT,clrRed,1);
   
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
   DeletePending();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   CheckRunningOrders();
   CheckProfits();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
      CheckTrend();
      PlaceNewOrders();
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
void DeletePending() {
   for (int k = OrdersTotal()-1; k>=0; k--) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) 
         //if ((OrderSymbol() == Symbol()) && (OrderComment() == ggSignature)) {
         if ((OrderSymbol() == Symbol()) && (StartsWith(OrderComment(),ggSignature))) {
            switch (OrderType()) {
               case OP_BUYLIMIT:
               case OP_BUYSTOP:
               case OP_SELLLIMIT:
               case OP_SELLSTOP: {
                  int o=OrderDelete(OrderTicket()); 
                  ggOrderTrend = ggTrend;
                  ggPending = false;
                  ChangeLabel("Trend","Trend: " + ggTrend + " - " + ggOrderTrend);
               }
            }
         }
   }
}

void PlaceNewOrders() {
   if (ggStopped) return;
   if (ggPending) return;
// determina se inserire un nuovo ordine
   int o=0;
   double bid_price = ggShorts.worst+ppStep*Point;
   double ask_price = ggLongs.worst-ppStep*Point;

   if (ggOrderTrend == "DOWN") {
      MoveLine("NextEntry",bid_price);
   }
   if (ggOrderTrend == "UP") {
      MoveLine("NextEntry",ask_price);
   }

   if (ggOrderTrend == ggTrend) {
      if ((ggOrderTrend == "DOWN") && (Bid > bid_price) && (ggShorts.positions < ppMaxPos)  ) {
         //Alert("ordine");
         double vol = ggShorts.positions * ppIncrease + ppInitVolume;
         o=OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_S");
      }
      
      if ((ggOrderTrend == "UP") && (Ask < ask_price) && (ggLongs.positions < ppMaxPos)) {
         double vol = ggLongs.positions * ppIncrease + ppInitVolume;
         o=OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_L");
      }
   } else {
      /*
      Piazzo un ordine contrario al precedente trend composto dalla somma dei lotti investiti
      Poi procedo normalmente
      */
	   if (ppHedging) {
	      // Chiude le posizioni hedging precedenti
         for (int k = OrdersTotal()-1; k>=0; k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) 
               if ((OrderSymbol() == Symbol()) && (OrderComment() == ggSignature + "_H")) {
                  // dovrebbe essercene solo una
                  int mode = 0;
                  if (OrderType() == OP_BUY) mode = MODE_BID; 
                  if (OrderType() == OP_SELL) mode = MODE_ASK;
                  int rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),mode),200);
                  ggBalance+=OrderProfit();
                  ChangeLabel("Balance",StringFormat("Profit: %.2f" ,ggBalance));
                  string subj = StringFormat("YAGT. Chiuso HEDGING su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
                  string mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                          Symbol(),OrderLots(),OrderProfit());
                  SendMail(subj,mex);     
               }
         }
	   
         ggOrderTrend = ggTrend;
         if (ggOrderTrend == "DOWN")  {
            double vol = ggLongs.lots;
            o=OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_H");
            o=OrderSend(Symbol(),OP_SELL,ppInitVolume,Bid,200,0,0,ggSignature + "_S");
         }
         if (ggOrderTrend == "UP") {
            double vol = ggShorts.lots;
            o=OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_H");
            o=OrderSend(Symbol(),OP_BUY,ppInitVolume,Ask,200,0,0,ggSignature + "_L");
         }
      }
	  
   }
}

void CheckProfits() {
   if (ggPending) return;

   int rt;
   string subj,mex;
   if (ggShorts.profit > ppCloseProfit) {
      if ((ppChopMode) && (!ppStopEven)) {
         // Chiudo solo l'ultimo ordine
         if (OrderSelect(ggShorts.last_ticket,SELECT_BY_TICKET)) {
            rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),200);
            ggBalance += OrderProfit();
            subj = StringFormat("YAGT. Chiuso SHORT su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
            mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                    Symbol(),OrderLots(),OrderProfit());
            SendMail(subj,mex);     
         }
      } else {
         // Chiudo tutti gli ordini short
         for (int k=OrdersTotal()-1;k>=0;k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
               if ((OrderSymbol() == Symbol()) && (OrderType() == OP_SELL) && (OrderComment() == ggSignature + "_S")) {
                  rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),200);
                  ggBalance += OrderProfit();
                  subj = StringFormat("YAGT. Chiuso SHORT su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
                  mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                          Symbol(),OrderLots(),OrderProfit());
                  SendMail(subj,mex);     
               }
            }
         }
         if (ppStopEven) {
            ggStopped = true;
            ChangeLabel("Active","STOPPED");
         }
      }
   }
   if (ggLongs.profit > ppCloseProfit) {
      if (ppChopMode) {
         // Chiudo solo l'ultimo ordine
         if (OrderSelect(ggLongs.last_ticket,SELECT_BY_TICKET)) {
            rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),200);
            ggBalance += OrderProfit();
            subj = StringFormat("YAGT. Chiuso LONG su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
            mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                    Symbol(),OrderLots(),OrderProfit());
            SendMail(subj,mex);     
         }
      } else {
         // Chiudo tutti gli ordini long
         for (int k=OrdersTotal()-1;k>=0;k--) {
            if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
               if ((OrderSymbol() == Symbol()) && (OrderType() == OP_BUY) && (OrderComment() == ggSignature + "_L")) {
                  rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),200);
                  ggBalance += OrderProfit();
                  subj = StringFormat("YAGT. Chiuso LONG su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
                  mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                          Symbol(),OrderLots(),OrderProfit());
                  SendMail(subj,mex);     
               }
            }
         }
      }
   }
   ChangeLabel("Balance",StringFormat("Profit: %.2f" ,ggBalance));
}

void CheckRunningOrders() {
   if (ggStopped) return;


   bool already_created = false;
   bool already_open = false;
   
   ggLongs.positions = ggShorts.positions =0;
   ggLongs.lots = ggShorts.lots = 0;
   ggLongs.profit = ggShorts.profit = 0;
   ggLongs.average = ggShorts.average = 0;
   ggLongs.last_ticket = ggShorts.last_ticket = 0;
   
   ggLongs.worst = DBL_MAX;
   ggShorts.worst = 0;

   int last_short = 0;
   int last_long = 0;
   int otime = 0;
   
   // Analizza gli ordini aperti
   for (int k = 0; k<OrdersTotal(); k++) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
         if ((OrderSymbol() == Symbol()) && 
            ((OrderComment() == ggSignature + "_S") || (OrderComment() == ggSignature + "_L"))) {
         //if ((OrderSymbol() == Symbol()) && (StartsWith(OrderComment(),ggSignature))) { // Non conto hedging in questo modo
            already_created = true; 
            if ((OrderType() == OP_BUY) || (OrderType() == OP_SELL))  {
               already_open = true;
               switch (OrderType()) {
                  case OP_BUY:
                     ggLongs.positions++;
                     ggLongs.lots+=OrderLots();
                     ggLongs.profit+=OrderProfit() + OrderCommission() + OrderSwap();
                     ggLongs.average+=OrderOpenPrice()*OrderLots();
                     otime = int(OrderOpenTime());
                     if (OrderOpenPrice() < ggLongs.worst) ggLongs.worst = OrderOpenPrice();
                     if (otime > last_long) {
                        last_long = otime;
                        ggLongs.last_ticket = OrderTicket();
                     } 
                     break;
                  case OP_SELL:
                     ggShorts.positions++;
                     ggShorts.lots+=OrderLots();
                     ggShorts.profit+=OrderProfit() + OrderCommission() + OrderSwap();
                     ggShorts.average+=OrderOpenPrice()*OrderLots();
                     otime = int(OrderOpenTime());
                     if (OrderOpenPrice() > ggShorts.worst) ggShorts.worst = OrderOpenPrice();
                     if (otime > last_short) {
                        last_short = otime;
                        ggShorts.last_ticket = OrderTicket();
                     } 
                     break;
               } 
            }
         }
      }
   }
   // Visualizza i dati sugli ordini aperti
   // ESCE se esistono già ordini aperti o pendenti con questa Signature
   if (already_open) { 
      DeletePending();
      if (ggLongs.positions >0) {
         ggLongs.average = ggLongs.average / ggLongs.lots;
         ChangeLabel("Longs",StringFormat("LONGS - Pos: %d - Lots: %.2f - Prof: %.2f - Avg: %.2f",
                                          ggLongs.positions,ggLongs.lots,ggLongs.profit,ggLongs.average));
         MoveLine("BuyEven",ggLongs.average);
      } else {
         ChangeLabel("Longs","No long positions");
         MoveLine("BuyEven",0);
      }
      if (ggShorts.positions >0) {
         ggShorts.average = ggShorts.average / ggShorts.lots;
         ChangeLabel("Shorts",StringFormat("SHORTS - Pos: %d - Lots: %.2f - Prof: %.2f - Avg: %.2f",
                                          ggShorts.positions,ggShorts.lots,ggShorts.profit,ggShorts.average));
         MoveLine("SellEven",ggShorts.average);
      }else {
         ChangeLabel("Shorts","No short positions");
         MoveLine("SellEven",0);
      }
   }
   
   if (already_created) return;
 
   int o = 0;
   double dist = Point*ppInitDiff;
   if (ggTrend == "UP") {
      if (!TryOpenOrder(OrderSend(Symbol(),OP_BUYLIMIT, ppInitVolume,Ask-dist,200,0,0,ggSignature + "_L",0))) return;
      if (!TryOpenOrder(OrderSend(Symbol(),OP_BUYSTOP, ppInitVolume,Ask+dist,200,0,0,ggSignature+ "_L",0))) return;
      ggPending = true;
   }
   if (ggTrend == "DOWN") {
      if (!TryOpenOrder(OrderSend(Symbol(),OP_SELLLIMIT, ppInitVolume,Bid+dist,200,0,0,ggSignature + "_S",0))) return;
      if (!TryOpenOrder(OrderSend(Symbol(),OP_SELLSTOP, ppInitVolume,Bid-dist,200,0,0,ggSignature + "_S",0))) return;
      ggPending = true;
   }
   
}

bool TryOpenOrder(int result) {
   if (result == -1) {
      Alert("Error code: " + string(GetLastError()));
      Alert("Stopped");
      ggStopped = true;
      ChangeLabel("Active","STOPPED");
      DeletePending();
      return false;
   } else {
      return true;
   }

}

void CheckTrend() {
   /*
   double c_fast = iMA(Symbol(),PERIOD_M15,21,0,MODE_EMA,PRICE_CLOSE,0);
   double c_slow = iMA(Symbol(),PERIOD_M15,43,0,MODE_EMA,PRICE_CLOSE,0);
   */

   double c_fast = iMA(NULL,0,21,0,MODE_EMA,PRICE_CLOSE,0);
   double c_slow = iMA(NULL,0,43,0,MODE_EMA,PRICE_CLOSE,0);

   ggTrend = "n/a";
   
   
   if ((c_fast > c_slow)) ggTrend = "UP";
   if ((c_fast < c_slow)) ggTrend = "DOWN";
   
   if (ggOrderTrend == "n/a") ggOrderTrend = ggTrend; // questo per le ripartenze
   
   ChangeLabel("Trend","Trend: " + ggTrend + " - " + ggOrderTrend);
   
}

void MakeLine(string name,int style,int colour,int width) {
   name="Z_"+name;
   ObjectCreate(name,OBJ_HLINE,0,0,0);
   ObjectSet(name, OBJPROP_STYLE, style); 
   ObjectSet(name, OBJPROP_COLOR, colour); 
   ObjectSet(name, OBJPROP_WIDTH, width);
}

void MoveLine(string name, double level) {
   name="Z_"+name;
   ObjectMove(name,0,0,level);
}

void MakeLabel(string name,string text,int x,int y) 
  {
   name="Z_"+name;
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,text,10,"Verdana",ppLabelColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
  }

void ChangeLabel(string name,string text) 
  {
   name="Z_"+name;
   ObjectSetText(name,text,10,"Verdana",ppLabelColor);
  }

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

bool StartsWith(string what, string with) {
   int l = StringLen(with);
   string s = StringSubstr(what,0,l);
   if (s == with) return true; else return false;
}
