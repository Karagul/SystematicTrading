/* 
RANGING BOT
      
ENTRY RULES:
- If Current Volatility (ATR(20)) is less than Volatility (ATR(20)) 10 hours ago:
   1. Enter a long trade when closing price crosses Keltner Channels(20) Lower Bound from bottom
   2. Enter a short trade when closing price crosses Keltner Channels(20) Upper Bound from top
   
EXIT RULES:
- Profit-Taking Exit 1: Exit the long trade when closing price moved up by 2 ATR(20)   
- Profit-Taking Exit 2: Exit the short trade when closing price moved down by 2 ATR(20) 
- Stop Loss Exit: 1 ATR(20) Hard stop
- Generic Exit: Stop after 10 periods
   
POSITION SIZING RULE:
- 2% of Capital risked per trade
      
Assume trading on 1HR Timeframe
*/

#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

#property copyright "QuangKhaTran"
#property link      "quangkhatran@gmail.com"

extern int MagicNumber = 00003;
extern bool SignalMail = False;
extern double Lots = 1.0;
extern int Slippage = 3;
extern bool UseStopLoss = True;
extern int StopLoss = 0;
extern bool UseTakeProfit = True;
extern int TakeProfit = 0;
extern bool UseTrailingStop = False;
extern int TrailingStop = 0;
extern bool isSizingOn = True;
extern int Risk = 2;

// Declare Extern Variables

extern int keltnerPeriod = 20;
extern double tpATR_k = 2; // Take Profit Multiple of ATR
extern double slATR_k = 1; // Stop Loss Multiple of ATR
extern double atr_period = 20;
extern int atr_shift = 11; // Number of bars before current (used for volatility rule)
extern int timeExitPeriod = 10; // Number of bars until trade is exited (used for generic exit rule)
extern double k = 3; // Width of Keltner Channels. Number represents number of ATRs. See Keltner Channels Code.

int P = 1;
int Order = SIGNAL_NONE;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;
bool isYenPair;

// Declare variables
double keltnerUpper1, keltnerUpper2, keltnerLower1, keltnerLower2, close1, close2;
double atr_current, atr_past;
double takeprofit1, takeprofit2;
double timeexit;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   
   if(Digits == 5 || Digits == 3 || Digits == 1)P = 10;else P = 1; // To account for 5 digit brokers
   if(Digits == 3 || Digits == 2) isYenPair = true; // To account for Yen Pairs

   return(0);
}
//+------------------------------------------------------------------+
//| Expert initialization function - END                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   return(0);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function - END                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert start function                                            |
//+------------------------------------------------------------------+
int start() {

   Total = OrdersTotal();
   Order = SIGNAL_NONE;

   //+------------------------------------------------------------------+
   //| Variable Setup                                                   |
   //+------------------------------------------------------------------+

   // Initialise Keltner indicators (Hint: Create 4 variables)
   
   keltnerUpper1 = iCustom(NULL, 0, "Keltner_Channels", keltnerPeriod, 0, 5, 20, k, True, 0, 1);
   keltnerLower1 = iCustom(NULL, 0, "Keltner_Channels", keltnerPeriod, 0, 5, 20, k, True, 2, 1);
   keltnerUpper2 = iCustom(NULL, 0, "Keltner_Channels", keltnerPeriod, 0, 5, 20, k, True, 0, 2);
   keltnerLower2 = iCustom(NULL, 0, "Keltner_Channels", keltnerPeriod, 0, 5, 20, k, True, 2, 2);
   
   // Initialise Closing Price Variables
   
   close1 = iClose(NULL, 0, 1);
   close2 = iClose(NULL, 0, 2);
   
   // Initialise ATRs
   
   atr_current = iATR(NULL, 0, atr_period, 1);    // ATR(20) now
   atr_past = iATR(NULL, 0, atr_period, atr_shift);      // ATR(20) 10 periods ago. Assumption: Trading on 1HR TF
   
   // Declare Stop Loss Exits
   
   StopLoss = slATR_k * atr_current / (P * Point); // Note that StopLoss need to be initialised before the Sizing Algo as we are using this value there
   TakeProfit = (atr_current * tpATR_k) / (P * Point);  // Current ask price + 5 ATR(20);
   
   // Sizing Algo (2% risked per trade)
   if (isSizingOn == true) {
      Lots = Risk * 0.01 * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * StopLoss * P * Point); // Sizing Algo based on account size
      if(isYenPair == true) Lots = Lots * 100; // Adjust for Yen Pairs
      Lots = NormalizeDouble(Lots, 2); // Round to 2 decimal place
   }

   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD)) / P; // Defining minimum StopLevel

   if (StopLoss < StopLevel) StopLoss = StopLevel;
   if (TakeProfit < StopLevel) TakeProfit = StopLevel;

   //+------------------------------------------------------------------+
   //| Variable Setup - END                                             |
   //+------------------------------------------------------------------+

   //Check position
   bool IsTrade = False;

   for (int i = 0; i < Total; i ++) {
      Ticket2 = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = True;
         if(OrderType() == OP_BUY) {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            /* 
            EXIT RULES:
            - Profit-Taking Exit 1: Exit the long trade when closing price moved down by 2 ATR(20)
            - Profit-Taking Exit 2: Exit the short trade when closing price moved up by 2 ATR(20) 
            - Stop Loss Exit: 1 ATR(20) Hard stop
            - Generic Exit: Stop after 10 periods
            */
            
            // Long trade closing rule
            
            if(TimeCurrent() > timeexit) Order = SIGNAL_CLOSEBUY; // Rule to EXIT a Long trade.
            // Note that only the generic exit rule is here. The Profit-Taking Exit 1 rule is considered in the TakeProfti variable 

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSEBUY) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               IsTrade = False;
               
               // Optional TDL 9: Reset the Time Exit value (This is optional as time value will be re-initialised when a buy/sell signal is generated.)
               timeexit = 0;
               
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if(Bid - OrderOpenPrice() > P * Point * TrailingStop) {
                  if(OrderStopLoss() < Bid - P * Point * TrailingStop) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Bid - P * Point * TrailingStop, OrderTakeProfit(), 0, MediumSeaGreen);
                     continue;
                  }
               }
            }
         } else {
            

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+

            // Short trade closing rule

            if (TimeCurrent() > timeexit) Order = SIGNAL_CLOSESELL; // Rule to EXIT a Short trade
             // Note that only the generic exit rule is here. The Profit-Taking Exit 1 rule is considered in the TakeProfti variable

            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSESELL) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");
               IsTrade = False;
               
               // Optional TDL 10: Reset the Time Exit value (This is optional as time value will be re-initialised when a buy/sell signal is generated.)
               timeexit = 0;
               
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if((OrderOpenPrice() - Ask) > (P * Point * TrailingStop)) {
                  if((OrderStopLoss() > (Ask + P * Point * TrailingStop)) || (OrderStopLoss() == 0)) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Ask + P * Point * TrailingStop, OrderTakeProfit(), 0, DarkOrange);
                     continue;
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Signal Begin(Entries)                                            |
   //+------------------------------------------------------------------+

      /*
      ENTRY RULES:
      - If Current Volatility (ATR(20)) is less than Volatility (ATR(20)) 10 hours ago:
         1. Enter a long trade when closing price crosses Keltner Channels(20) Lower Bound from bottom
         2. Enter a short trade when closing price crosses Keltner Channels(20) Upper Bound from top
      */
   
   // Add all entry rules
   
   if (atr_current < atr_past) {
   
      if (close2 < keltnerLower2 && close1 >= keltnerLower1) Order = SIGNAL_BUY; // Rule to ENTER a Long trade
   
      if (close2 > keltnerUpper2 && close1 <= keltnerUpper1) Order = SIGNAL_SELL; // Rule to ENTER a Short trade

   }
   
   //+------------------------------------------------------------------+
   //| Signal End                                                       |
   //+------------------------------------------------------------------+

   //Buy
   if (Order == SIGNAL_BUY) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Ask - StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("BUY order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Open Buy");
			   
         		// Define Time-based Exit
			      timeexit = TimeCurrent() + timeExitPeriod * Period()*60; // Multiply by 60 to convert to seconds
			      
			} else {
				Print("Error opening BUY order : ", GetLastError());
			}
         }
         return(0);
      }
   }

   //Sell
   if (Order == SIGNAL_SELL) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Bid + StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("SELL order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Open Sell");
			      
			      // Define Time-based Exit
			      timeexit = TimeCurrent() + timeExitPeriod * Period()*60; // Multiply by 60 to convert to seconds;
			
			} else {
				Print("Error opening SELL order : ", GetLastError());
			}
         }
         return(0);
      }
   }
   return(0);
}
//+------------------------------------------------------------------+

