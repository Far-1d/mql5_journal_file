//+------------------------------------------------------------------+
//|                                          simple_journal_test.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://github.com/Far-1d"
#property description "Made with ❤️"
#property version   "1.00"

//--- import journal class
#include <journal.mqh>
JournalWatch journal;

//--- import trade class
#include	<Trade\Trade.mqh>
CTrade trade;


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
      journal.TransactionDescription(trans);
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
   
}