//+------------------------------------------------------------------+
//|                                          simple_journal_test.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://github.com/Far-1d"
#property description "Made with ❤️"
#property version   "1.20"

//--- import journal class
#include <journal.mqh>
JournalWatch journal;

//--- import trade class
#include	<Trade\Trade.mqh>
CTrade trade;

//------------------------------------------ update 1.20
//--- import Array class (used for storing reverse price for each position)
#include <Generic\HashMap.mqh>
CHashMap<ulong, double> positionPrices;
CHashMap<ulong, datetime> positionTime;
//------------------------------------------

//--- add input
input group "Config";
input int rsi_period          = 14;                // RSI Period
input double lot_size         = 0.2;               // Lot size
input int sl_distance         = 200;               // SL distance in points
input int tp_distance         = 300;               // TP distance in points
input int Magic               = 234;               // Magic Number

input group "Journal Config";
input string journal_filename = "Journal.csv";

//--- define global variables
int rsiHandle;
int jhandle;
//------------------------------------------ update 1.20
double max_reverse_price;
datetime max_reverse_time;
//------------------------------------------


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
   //--- initiate file handle and give handle to journal file
   jhandle = FileOpen(journal_filename, FILE_COMMON|FILE_WRITE|FILE_READ|FILE_ANSI|FILE_SHARE_READ, ',');
   journal.UpdateFileHandle(jhandle);
   
   //--- initiate rsi
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
   
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- close file handle
   FileClose(jhandle);
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static int totalbars = iBars(_Symbol, PERIOD_CURRENT);
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   
   double rsiArray[ ];
   ArraySetAsSeries(rsiArray, true);
   
   if (totalbars != bars){
      CopyBuffer(rsiHandle, 0, 1,2, rsiArray);   
      
      //--- sell if rsi move below 70
      if (rsiArray[0]<70 && rsiArray[1]>=70){
         open_position("SELL");
      }
      
      //--- buy if rsi move above 30
      if (rsiArray[0]>30 && rsiArray[1]<=30){
         open_position("BUY");
      }
      
      totalbars = bars;
   }
   
//------------------------------------------ update 1.2
   if (PositionsTotal()>0)
   {
      for (int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong tikt = PositionGetTicket(i);
         if (PositionSelectByTicket(tikt))
         {
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            long pos_type = PositionGetInteger(POSITION_TYPE);
            double
               ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK),
               bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
            
            GetPositionPrice(tikt);
            double reversePrice = max_reverse_price;

            if (pos_type == POSITION_TYPE_BUY)
            {
               if (reversePrice > bid || reversePrice == 0) // bid is used because you get out of buy at bid
               {
                  UpdateArray(tikt, bid);
               }
            }
            else 
            {
               if (reversePrice != 0)
               {
                  if (ask > reversePrice)
                  {
                     UpdateArray(tikt, ask);
                  }
               }
            }
            
         }
      }
   }
//------------------------------------------

}

//+------------------------------------------------------------------+ 
//| TradeTransaction function                                        | 
//+------------------------------------------------------------------+ 
void OnTradeTransaction(const MqlTradeTransaction &trans, 
                        const MqlTradeRequest &request, 
                        const MqlTradeResult &result) 
{ 
   ENUM_TRADE_TRANSACTION_TYPE type=(ENUM_TRADE_TRANSACTION_TYPE)trans.type; 
   
   if(type == TRADE_TRANSACTION_DEAL_ADD || type==TRADE_TRANSACTION_REQUEST) 
   {  
      Print("----- sending transaction -----");
      GetPositionPrice(trans.position);
      Print(max_reverse_price, "      ", max_reverse_time);
      journal.TransactionDescription(trans, max_reverse_price, max_reverse_time );
      Print("----- sending request -----");
      journal.RequestDescription(request);
   }
     
}


//+------------------------------------------------------------------+
//    custom functions
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+ 
//| open positions based on input data                               | 
//+------------------------------------------------------------------+ 
void open_position(string type){
   double lots = NormalizeDouble(lot_size, 2);
   
   if (type == "BUY"){
      double sl   = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK)-sl_distance*_Point, _Digits); 
      double tp   = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK)+tp_distance*_Point, _Digits); 
      
      trade.Buy(lots, _Symbol, 0, sl, tp);
   }
   
   if (type == "SELL"){
      double sl   = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID)+sl_distance*_Point, _Digits); 
      double tp   = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID)-tp_distance*_Point, _Digits); 
      
      trade.Sell(lots, _Symbol, 0, sl, tp, "selling");
   }
   
//------------------------------------------ update 1.2
   ulong tikt = trade.ResultDeal();
   double entry = trade.ResultPrice();
   Print("result deal tikt: ", tikt);
   positionPrices.Add(tikt, entry);
//------------------------------------------

}

//------------------------------------------ update 1.2

//+------------------------------------------------------------------+ 
// Update position price in the associative array                    |
//+------------------------------------------------------------------+ 
void UpdateArray(ulong ticket, double price)
{
   if (positionPrices.ContainsKey(ticket))
   {
      positionPrices.TrySetValue(ticket, price);
      positionTime.TrySetValue(ticket, TimeCurrent());
   }
   else 
   {
      positionPrices.Add(ticket, price);
      positionTime.Add(ticket, TimeCurrent());
   }
}

//+------------------------------------------------------------------+
// Retrieve current price for a given position ticket                |
//+------------------------------------------------------------------+
void GetPositionPrice(ulong ticket)
{
    if (positionPrices.ContainsKey(ticket))
    {
      positionPrices.TryGetValue(ticket, max_reverse_price);
      positionTime.TryGetValue(ticket, max_reverse_time);
    }
   
}

//------------------------------------------