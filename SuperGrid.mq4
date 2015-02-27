//+------------------------------------------------------------------+
//|                                                    SuperGrid.mq4 |
//|                                 Lorenzo Pedrotti & Simone Forini |
//|                                            www.wannabetrader.com |
//+------------------------------------------------------------------+
#property copyright "Lorenzo Pedrotti & Simone Forini"
#property link      "www.wannabetrader.com"
#property version   "3.04"
#property strict
//--- input parameters

const string VERSION = "3.04";


input string      ppSignature = "cambiami"; // Session initial signature
input bool        ppChangeSig = false; // Change signature at trend change

input int         ppCoverMode = 0; // Place cover orders at trend change
const int COVER_NONE = 0;
const int COVER_SINGLE = 1;
const int COVER_MULTI = 2;

input string      ppAverages = "21;43;130"; // Averages to calculate trend direction
input int         ppPeriod = 15; // Period of the averages (1,5,15,30,60)
input int         ppInitDiff = 300; // Points up/down of the first pending orders
input int         ppMaxPos = 10; // Max allowed positions (per trend/signature)

input int         ppStep = 300; // Points before open a new position
input int         ppStepCover = 600; // Points before open a new cover position
input double      ppInitVolume = 0.01; // Size of the first lot
input double      ppIncrease = 0.0; // Size of the increment lot

input double      ppCloseProfitLong = 5.0; // Close LONG when profit is at least (euro)
input double      ppCloseProfitShort = 5.0; // Close SHORT when profit is at least (euro)

input bool        ppCloseCoverProfit = true; // Close cover orders (mode=1) only if in profit

input bool        ppChopModeLong = true; // Close only the newest LONG positions
input bool        ppChopModeShort = true; // Close only the newest SHORT positions

input bool        ppStopEven = false; // Close ALL at profit and STOP

input color       ppLabelColor = clrWhite; // Labels color


string ggTrend = "n/a"; // il trend calcolato
string ggOrderTrend = "n/a"; // il trend degli ordini

string ggSignature = ppSignature; // questo succede solo quando parte EA per la prima volta
int ggSigNum = 0; // numero sequenziale delle signatures

struct orders_data {
   int positions;
   double lots;
   double profit;
   double average;
   double worst; // prezzo dell'ultimo ordine
   int last_ticket; // ticket dell'ultimo ordine eseguito
   bool hedged; // è aperto un hedging
};

orders_data ggLongs = {0,0,0,0,0,0,false};
orders_data ggShorts = {0,0,0,0,0,0,false};

bool ggStopped = false;
bool ggPending = false; // ci sono ancora gli ordini pending

bool ggLongPos = true; // Open long positions
bool ggShortPos = true; // Open short positions

string ggAverages[];
int ggNumAverages = 0; // numero di medie da usare per il cambio di trend 

double ggBalance = 0; // contabilità interna del sistema

string varBalance = "grid_Balance_" + ppSignature;

// Colors
const int C_BREAKEVEN = clrYellow;
const int C_NEXTENTRY = clrRed;
const int C_NEXTCOVER = clrBlueViolet;

int ggMinute = 0;

int OnInit() {

//--- create timer
   EventSetTimer(60);
   ggStopped = false;
   ggPending = false;
   ggLongPos = true; 
   ggShortPos = true; 

   MqlDateTime mdt;
   datetime dt = TimeLocal(mdt);
   ggMinute = mdt.min;
   
   ggNumAverages = StringSplit(ppAverages,';',ggAverages);
   int start_at = 20;
   int delta = 15;
   MakeLabel("Trend","Trend",20,start_at);
   MakeLabel("Shorts","Shorts:",20,start_at+=delta);
   MakeLabel("Longs","Longs:",20,start_at+=delta);
   MakeLabel("Infos",ggSignature,20,start_at+=delta);
   MakeLabel("Active","ACTIVE",150,start_at);
   MakeLabel("Balance","Profit: XX",250,start_at);
   
   MakeLine("SellEven",STYLE_DASHDOTDOT,C_BREAKEVEN,1);
   MakeLine("BuyEven",STYLE_DASHDOTDOT,C_BREAKEVEN,1);
   MakeLine("NextEntry",STYLE_DOT,C_NEXTENTRY,1);
   MakeLine("NextCover",STYLE_DOT,C_NEXTCOVER,1);

   if (GlobalVariableCheck(varBalance)) {
      ggBalance = GlobalVariableGet(varBalance);
   } else {
      GlobalVariableSet(varBalance,ggBalance);
   }

   Comment(StringFormat("Supergrid %s",VERSION));

   CheckTrend();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   CleanUp();
   DeletePending();
}


void OnTick() {
   ggBalance = GlobalVariableGet(varBalance);
   CheckRunningOrders();
   CheckProfits();
   //if ((ggShorts.positions==0) && (ggLongs.positions==0))
   if ( ((ggShorts.positions==0) && (ggTrend == "DOWN")) ||
        ((ggLongs.positions==0) && (ggTrend == "UP")) ) 
            OpenPendingOrders();
   GlobalVariableSet(varBalance,ggBalance);
   
   CheckPending();
   
   MqlDateTime mdt;
   datetime dt = TimeLocal(mdt);
   if (mdt.min != ggMinute && MathMod(mdt.min,Period())==0 ) {
      ggMinute = mdt.min;
      ON_CandleChange();
   }
   
}

void ON_CandleChange() {
   ggBalance = GlobalVariableGet(varBalance);
   
   CheckTrend();
   OpenNewOrders();
   GlobalVariableSet(varBalance,ggBalance);
}

void OnTimer() {
}

double OnTester() {
   double ret=0.0;
   return(ret);
}

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
                  string t = "n/a";
                  if (ggOrderTrend == "UP") t = "LONG"; 
                  if (ggOrderTrend == "DOWN") t = "SHORT";
                  ChangeLabel("Trend","Trend: " + ggTrend + " - " + t);
               }
            }
         }
   }
}


void CheckPending() {
   int pending = 0;
   int ticket = 0;
   for (int k = OrdersTotal()-1; k>=0; k--) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) 
         if ((OrderSymbol() == Symbol()) && (StartsWith(OrderComment(),ggSignature))) {
            switch (OrderType()) {
               case OP_BUYLIMIT:
               case OP_BUYSTOP:
               case OP_SELLLIMIT:
               case OP_SELLSTOP: {
                  pending++;
                  ticket = OrderTicket();
               }
            }
         }
   }
   if (pending == 1) {
      int o=OrderDelete(ticket); 
      ggOrderTrend = ggTrend;
      ggPending = false;
      string t = "n/a";
      if (ggOrderTrend == "UP") t = "LONG"; 
      if (ggOrderTrend == "DOWN") t = "SHORT";
      ChangeLabel("Trend","Trend: " + ggTrend + " - " + t);
   }
   
}

void OpenNewOrders() {
   
   int o=0;
   double bid_price = ggShorts.worst+ppStep*Point;
   double ask_price = ggLongs.worst-ppStep*Point;   
   double bid_cover = 0;
   double ask_cover = 0;

   if (ppCoverMode == 2) {
      bid_cover = ggShorts.worst+ppStepCover*Point;
      ask_cover = ggLongs.worst-ppStepCover*Point;
   }

   if (ggOrderTrend == "DOWN") {
      MoveLine("NextEntry",bid_price);
      MoveLine("NextCover",ask_cover);
   }
   if (ggOrderTrend == "UP") {
      MoveLine("NextEntry",ask_price);
      MoveLine("NextCover",bid_cover);
   }

   if (ggStopped) return;
   if (ggPending) return;
   
   // condizione generale per eseguire un trade
   if ((ggOrderTrend == ggTrend) || ((ggTrend=="n/a") && (ggOrderTrend!="n/a") )  ) {
      if ((ggOrderTrend == "DOWN") && (Bid > bid_price) && (ggShorts.positions < ppMaxPos) && (ggShortPos) ) {
         double vol = ggShorts.positions * ppIncrease + ppInitVolume;
         o=TryOpenOrder(OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_S"));
         ggShorts.positions++;
      }
      if ((ggOrderTrend == "UP") && (Ask < ask_price) && (ggLongs.positions < ppMaxPos) && (ggLongPos) ) {
         double vol = ggLongs.positions * ppIncrease + ppInitVolume;
         o=TryOpenOrder(OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_L"));
         ggLongs.positions++;
      }
      /*
      determina se inserire un ordine di copertura
      
      Inserisco l'ordine se ci sono posizioni aperte contro il trend corrente
      e se il prezzo è alla corretta distanza
      */
      if (ppCoverMode == COVER_MULTI) {
         if  ((ggOrderTrend == "DOWN") && (ggLongs.positions > 0) && 
               (ggLongs.positions < ppMaxPos) && (ggLongPos) && (Ask < ask_cover)) {
                  double vol = ggLongs.positions * ppIncrease + ppInitVolume;
                  o=TryOpenOrder(OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_L"));
                  ggLongs.positions++;
                 
         }
         if  ((ggOrderTrend == "UP") && (ggShorts.positions > 0) && 
               (ggShorts.positions < ppMaxPos) && (ggShortPos) && (Bid > bid_cover)) {
                  double vol = ggShorts.positions * ppIncrease + ppInitVolume;
                  o=TryOpenOrder(OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_S"));
                  ggShorts.positions++;
                 
         }
      }
   
   } 
   
   // questa condizione si verifica se il trend viene invertito da CheckTrend
   if (ggOrderTrend != ggTrend && ggTrend != "n/a")  {
      CloseHedging();
      	   
	   double vol;
      ggOrderTrend = ggTrend; // inversione del trend di investimento
      if (ggOrderTrend == "DOWN" && ggShortPos) {
         if (ppCoverMode == COVER_SINGLE && !ggShorts.hedged)  {
            vol = ggLongs.lots;
            o=TryOpenOrder(OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_HS"));
            ggShorts.hedged = true;
         }
		 /*
         vol = ggShorts.positions * ppIncrease + ppInitVolume;
         o=TryOpenOrder(OrderSend(Symbol(),OP_SELL,vol,Bid,200,0,0,ggSignature + "_S"));
		 */
      }
      if ((ggOrderTrend == "UP") && (ggLongPos)) {
         if (ppCoverMode == COVER_SINGLE && !ggLongs.hedged)  {
            vol = ggShorts.lots;
            o=TryOpenOrder(OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_HL"));
            ggLongs.hedged = true;
         }
		 /*
         vol = ggLongs.positions * ppIncrease + ppInitVolume;
         o=TryOpenOrder(OrderSend(Symbol(),OP_BUY,vol,Ask,200,0,0,ggSignature + "_L"));
		 */
      }
   }
}

void CloseHedging() {
   /*
   Inverto il trend ed inserisco il primo ordine nel nuovo trend
   Piazzo un ordine contrario al precedente trend composto dalla somma dei lotti investiti
   */
   string h_sufx = "_HS";
   if (ggOrderTrend == "UP") h_sufx = "_HL";
    
   for (int k = OrdersTotal()-1; k>=0; k--) {
      // Chiude le posizioni COVER precedenti
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) 
         if (OrderSymbol() == Symbol() && OrderComment() == ggSignature + h_sufx) {
            // dovrebbe essercene solo una
            int mode = 0;
            if (OrderType() == OP_BUY) {
               mode = MODE_BID; 
               ggLongs.hedged = false;
            }
            if (OrderType() == OP_SELL) {
               mode = MODE_ASK;
               ggShorts.hedged = false;
            }
            if (ppCloseCoverProfit==false || (ppCloseCoverProfit==true && OrderProfit()>0)) {
               int rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),mode),200);
               ggBalance+=OrderProfit();
               ChangeLabel("Balance",StringFormat("Profit: %.2f" ,ggBalance));
               string subj = StringFormat("Chiuso HEDGING su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
               string mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                       Symbol(),OrderLots(),OrderProfit());
               SendMail(subj,mex);     
            }
         }
   }
}



void CheckProfits() {
   if (ggPending) return;

   int rt;
   string subj,mex;
   double real_profit;
   
   if (ggShorts.profit > ppCloseProfitShort) {
      if ((ppChopModeShort) && (!ppStopEven)) {
         // Chiudo solo l'ultimo ordine
         if (OrderSelect(ggShorts.last_ticket,SELECT_BY_TICKET)) {
            rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),200);
            ggBalance += OrderProfit();
            subj = StringFormat("Chiuso SHORT su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
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
                  subj = StringFormat("Chiuso SHORT su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
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
   if (ggLongs.profit > ppCloseProfitLong) {
      if ((ppChopModeLong) && (!ppStopEven)) {
         // Chiudo solo l'ultimo ordine
         if (OrderSelect(ggLongs.last_ticket,SELECT_BY_TICKET)) {
            rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),200);
            ggBalance += OrderProfit();
            subj = StringFormat("Chiuso LONG su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
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
                  subj = StringFormat("Chiuso LONG su %s - %s a %.2f",Symbol(),OrderComment(),OrderProfit());
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
   
   if (ggLongs.hedged) {
      for (int k=OrdersTotal()-1;k>=0;k--) {
         if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
            real_profit = OrderProfit() + OrderCommission() + OrderSwap();
            if (OrderSymbol() == Symbol() && OrderType() == OP_BUY 
                  && (OrderComment() == ggSignature + "_HL") && real_profit > 15) {
               rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),200);
               ggBalance += real_profit;
               subj = StringFormat("Chiuso HEDGING su %s - %s a %.2f",Symbol(),OrderComment(),real_profit);
               mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                       Symbol(),OrderLots(),real_profit);
               SendMail(subj,mex);   
               ggLongs.hedged = false;  
            }
         }
      }
   }
   if (ggShorts.hedged) {
      for (int k=OrdersTotal()-1;k>=0;k--) {
         if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
            real_profit = OrderProfit() + OrderCommission() + OrderSwap();
            if (OrderSymbol() == Symbol() && OrderType() == OP_SELL
                  && (OrderComment() == ggSignature + "_HS") && real_profit > 15) {
               rt = OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),200);
               ggBalance += real_profit;
               subj = StringFormat("Chiuso HEDGING su %s - %s a %.2f",Symbol(),OrderComment(),real_profit);
               mex = StringFormat("ORDINE CHIUSO\n\nSimbolo: %s\nLotti: %.2f\nProfit: %.2f\n",
                                       Symbol(),OrderLots(),real_profit);
               SendMail(subj,mex); 
               ggShorts.hedged = false;    
            }
         }
      }
   }
      
   
   
   ChangeLabel("Balance",StringFormat("Profit: %.2f" ,ggBalance));
}

void CheckRunningOrders() {
   ggLongs.positions = ggShorts.positions =0;
   ggLongs.lots = ggShorts.lots = 0;
   ggLongs.profit = ggShorts.profit = 0;
   ggLongs.average = ggShorts.average = 0;
   ggLongs.last_ticket = ggShorts.last_ticket = 0;
   ggLongs.hedged = ggShorts.hedged = false;
   
   ggLongs.worst = DBL_MAX;
   ggShorts.worst = 0;

   int last_short = 0;
   int last_long = 0;
   int otime = 0;
   
   // Analizza gli ordini aperti
   for (int k = 0; k<OrdersTotal(); k++) {
      if (OrderSelect(k,SELECT_BY_POS,MODE_TRADES)) {
         string oc = OrderComment();
         if (OrderSymbol() == Symbol() && 
            (oc == ggSignature + "_S" || oc == ggSignature + "_L") &&
             (OrderType() == OP_BUY || OrderType() == OP_SELL) ) {
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
         // Controllo se ci sono hedging appesi
         if (OrderSymbol() == Symbol() && 
            (oc == ggSignature + "_HS" || oc == ggSignature + "_HL") && 
            (OrderType() == OP_BUY || OrderType() == OP_SELL) ) {
            switch (OrderType()) {
               case OP_BUY:
                  ggLongs.hedged = true;
                  break;
               case OP_SELL:
                  ggShorts.hedged = true;
                  break;
            }
         }
      }
   }
   // Visualizza i dati sugli ordini aperti
   if ((ggShorts.positions > 0) || (ggLongs.positions > 0)) { 
      if (ggLongs.positions >0) {
         ggLongs.average = ggLongs.average / ggLongs.lots;
         ChangeLabel("Longs",StringFormat("L - Pos: %d - Lots: %.2f - Prof: %.2f - Avg: %.4f - Cv: %s",
                                          ggLongs.positions,ggLongs.lots,ggLongs.profit,ggLongs.average,Bool2YesNo(ggLongs.hedged)));
         MoveLine("BuyEven",ggLongs.average);
      } else {
         ChangeLabel("Longs","No long positions");
         MoveLine("BuyEven",0);
      }
      if (ggShorts.positions >0) {
         ggShorts.average = ggShorts.average / ggShorts.lots;
         ChangeLabel("Shorts",StringFormat("S - Pos: %d - Lots: %.2f - Prof: %.2f - Avg: %.4f - Cv: %s",
                                          ggShorts.positions,ggShorts.lots,ggShorts.profit,ggShorts.average,Bool2YesNo(ggShorts.hedged)));
         MoveLine("SellEven",ggShorts.average);
      }else {
         ChangeLabel("Shorts","No short positions");
         MoveLine("SellEven",0);
      }
   }
   
}

void OpenPendingOrders() { 
   if (ggPending) return;
   
   if (ppChangeSig) {
      ggSigNum++;
      ggSignature = ggSignature + "_" + string(ggSigNum);
   }
   
   double dist = Point*ppInitDiff;
   if ((ggTrend == "UP") && (ggLongPos)) {
      if (!TryOpenOrder(OrderSend(Symbol(),OP_BUYLIMIT, ppInitVolume,Ask-dist,200,0,0,ggSignature + "_L",0))) return;
      if (!TryOpenOrder(OrderSend(Symbol(),OP_BUYSTOP, ppInitVolume,Ask+dist,200,0,0,ggSignature+ "_L",0))) return;
      ggPending = true;
   }
   if ((ggTrend == "DOWN") && (ggShortPos)) {
      if (!TryOpenOrder(OrderSend(Symbol(),OP_SELLLIMIT, ppInitVolume,Bid+dist,200,0,0,ggSignature + "_S",0))) return;
      if (!TryOpenOrder(OrderSend(Symbol(),OP_SELLSTOP, ppInitVolume,Bid-dist,200,0,0,ggSignature + "_S",0))) return;
      ggPending = true;
   }
}

bool TryOpenOrder(int result) {
   if (result == -1) {
      int err = GetLastError();
      Alert("Error code: " + string(err));
      if (err == ERR_LONGS_NOT_ALLOWED) {
         Alert("No long positions");
         ggLongPos = false;
         return false;
      }
      if (err == ERR_SHORTS_NOT_ALLOWED) {
         Alert("No short positions");
         ggShortPos = false;
         return false;
      }     
      //Print("Stopped");
      //ggStopped = true;
      ChangeLabel("Active","STOPPED");
      DeletePending();
      return false;
   } else {
      return true;
   }

}

void CheckTrend() {
   //ggTrend = "n/a";  

   double c_fast = iMA(NULL,ppPeriod,int(ggAverages[0]),0,MODE_EMA,PRICE_CLOSE,0);
   double c_slow = iMA(NULL,ppPeriod,int(ggAverages[1]),0,MODE_EMA,PRICE_CLOSE,0);

   if (ggNumAverages == 2) {
      if (c_fast > c_slow) ggTrend = "UP";
      if (c_fast < c_slow ) ggTrend = "DOWN";   
   }
   if (ggNumAverages == 3) {
      double c_test = iMA(NULL,ppPeriod,int(ggAverages[2]),0,MODE_EMA,PRICE_CLOSE,0); // media di test
      /*
      Con trend indefinito controllo l'incrocio con le 3 medie.
      Con trend definito controllo solo le 2 veloci. Se incrociano in direzione opposta 
         il trend diventa indefinito fino all'incrocio con la media di test
         oppure se incrociano nuovamente
      */
      if (ggTrend == "n/a") {
         if (c_fast > c_slow && c_slow > c_test) ggTrend = "UP";
         if (c_fast < c_slow && c_slow < c_test) ggTrend = "DOWN";
      } 
      if (ggTrend == "UP" && c_fast < c_slow) {
         ggTrend = "n/a"; // controllerà al prossimo giro la terza media
      }
      if (ggTrend == "DOWN" && c_fast > c_slow) {
         ggTrend = "n/a";
      }
   }
   
   if (ggOrderTrend == "n/a") ggOrderTrend = ggTrend; // questo per le ripartenze
   
   //if (ggTrend != "n/a") ggOrderTrend = ggTrend; // il trend viene cambiato in OpenNewOrders
   
   string t = "n/a";
   if (ggOrderTrend == "UP") t = "LONG"; 
   if (ggOrderTrend == "DOWN") t = "SHORT";
   ChangeLabel("Trend","Trend: " + ggTrend + " - " + t);
}

//// UTILITIES

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
   ObjectSetText(name,text,8,"Verdana",ppLabelColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
  }

void ChangeLabel(string name,string text) 
  {
   name="Z_"+name;
   ObjectSetText(name,text,8,"Verdana",ppLabelColor);
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

string Bool2YesNo(bool v) {
   if (v) return "Yes";
   return "No";
}