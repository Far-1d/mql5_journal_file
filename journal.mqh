//+------------------------------------------------------------------+
//|                                                      journal.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://github.com/Far-1d"
#property description "Made with ❤️"
#property version   "1.30"

//-----------------------+
class JournalWatch
{
protected:
   string   dataArray[ ][ 20 ];                                      // array to store journal data
   int      file_handle;                                             // csv file handle
private:
   void     Write2csv( string& _arr[] );                             // write data to csv journal

public:
	void		JournalWatch( );								                  // constructor
	void		~JournalWatch( );							                     // destructor
   void     UpdateFileHandle( int _handle );                         // change file handle to write data in it
//------------------------------------------ update 1.30
   void     TransactionDescription(                                  // receive and store trade transaction data and adverse and favorable price and time
      const MqlTradeTransaction &trans, 
      double adverse_price, 
      datetime adverse_time,
      double favorable_price,
      datetime favorable_time
   );
//------------------------------------------
   void     RequestDescription(const MqlTradeRequest  &req);         // receive and store trade request data
   int      CheckMatch( string& _arr[][20], string _position );      // check whether the new position number exists in array
   void     ExtractAndOperateOnInnerArray(string& myArray[][20], int index); //seperate inner array
};


//--------------------------------------------------------------------+
//	constructor:
//--------------------------------------------------------------------+
void
JournalWatch::JournalWatch( )
{
}


//--------------------------------------------------------------------+
//	Destructor:
//--------------------------------------------------------------------+
void
JournalWatch::~JournalWatch( )
{
}


//--------------------------------------------------------------------+
//	change file handle to write data in it
//--------------------------------------------------------------------+
void
JournalWatch::UpdateFileHandle( int _handle )
{
   this.file_handle = _handle;
   FileSeek(this.file_handle, 0, SEEK_SET);
   FileWrite(this.file_handle,"Symbol", "Type", "Start time", "End time", 
      "Result", "Profit", "Open price", "Close price", "Volume", "Stop loss", "Take Profit", 
      "max adverse Price", "max adverse price time", "max favorable price", "max favorable price time",
      "Modified Stop loss", "Swap", "Comission", "Comment");
}

//------------------------------------------ update 1.20
//+------------------------------------------------------------------+ 
//| Store transaction textual description                           
//+------------------------------------------------------------------+ 
void 
JournalWatch::TransactionDescription(
   const MqlTradeTransaction &trans, 
   double adverse_price, 
   datetime adverse_time,
   double favorable_price,
   datetime favorable_time 
) 
{ 
   //---  check if transaction is deal-related
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {  
      int pos = this.CheckMatch(this.dataArray, (string)trans.position);
      if (pos == -1)
      {
         string type = "NAN";
         if (trans.deal_type == DEAL_TYPE_BUY) type = "BUY";
         else if (trans.deal_type == DEAL_TYPE_SELL) type = "SELL";
         
         ulong tikt = trans.deal;
         HistoryDealSelect(tikt);
         string comment    = HistoryDealGetString(tikt, DEAL_COMMENT);
         Print("*************** comment is ", comment);
         int size = ArraySize(this.dataArray)/20;
         ArrayResize(this.dataArray, size+1);
      
         this.dataArray[size][0] = (string)trans.position;             // position number
         this.dataArray[size][1] = trans.symbol;                       // symbol
         this.dataArray[size][2] = type;                               // position type
         this.dataArray[size][3] = TimeToString(TimeCurrent());        // start time
         this.dataArray[size][4] = "";                                 // end time             filled on position close
         this.dataArray[size][5] = "";                                 // result (tp, sl, rf)  filled on position close
         this.dataArray[size][6] = "";                                 // profit or loss       filled on position close
         this.dataArray[size][7] = StringFormat("%G",trans.price);     // open price
         this.dataArray[size][8] = "";                                 // close price
         this.dataArray[size][9] = StringFormat("%G",trans.volume);    // volume
         this.dataArray[size][10] = StringFormat("%G",trans.price_sl); // initial stop loss
         this.dataArray[size][11] = StringFormat("%G",trans.price_tp); // take profit
         this.dataArray[size][12] = "";                                // max adverse price
         this.dataArray[size][13] = "";                                // max adverse time
         this.dataArray[size][14] = "";                                // max favorable price
         this.dataArray[size][15] = "";                                // max favorable time
         this.dataArray[size][16] = "";                                // modified stop loss
         this.dataArray[size][17] = "";                                // swap
         this.dataArray[size][18] = "";                                // comission
         this.dataArray[size][19] = comment;                           // comment
         
      }
      else 
      {  
         //--- get profit, comission and swap data
         ulong tikt = trans.deal;
         HistoryDealSelect(tikt);
         double profit     = HistoryDealGetDouble(tikt, DEAL_PROFIT);
         double comission  = HistoryDealGetDouble(tikt, DEAL_COMMISSION)*2;
         double swap       = HistoryDealGetDouble(tikt, DEAL_SWAP);
         
         //--- get result data
         string result = "";
         if (trans.price == trans.price_sl) result = "SL";
         if (trans.price == trans.price_tp) result = "TP";
         if (trans.price == (double)this.dataArray[pos][7] ||
             trans.price == (double)this.dataArray[pos][14]) result = "RF or Trail";
         
         if (result == "" || result == "RF or Trail"){
            if (this.dataArray[pos][16] == "" && profit>0) result = "TP";
            if (this.dataArray[pos][16] == "" && profit<0) result = "SL";
            if (this.dataArray[pos][16] != "" && MathAbs(profit) < MathAbs(comission)) result = "RF";
            if (this.dataArray[pos][16] != "" && MathAbs(profit) > MathAbs(comission)) result = "Trail";
         }
         
         this.dataArray[pos][4] = TimeToString(TimeCurrent());
         this.dataArray[pos][5] = result;
         this.dataArray[pos][6] = ( string )profit;
         
         this.dataArray[pos][8] = ( string )SymbolInfoDouble(this.dataArray[pos][1], SYMBOL_ASK);
         if (this.dataArray[pos][2] == "BUY")
         {
            this.dataArray[pos][8] = ( string )SymbolInfoDouble(this.dataArray[pos][1], SYMBOL_BID);
         }
         
         this.dataArray[pos][12] = DoubleToString(adverse_price);
         this.dataArray[pos][13] = TimeToString(adverse_time);
         this.dataArray[pos][14] = DoubleToString(favorable_price);
         this.dataArray[pos][15] = TimeToString(favorable_time);
         
         this.dataArray[pos][17] = DoubleToString(swap, 2);
         this.dataArray[pos][18] = DoubleToString(comission, 2);
         
         this.ExtractAndOperateOnInnerArray(this.dataArray, pos);
      }
   }
}
//------------------------------------------

//+------------------------------------------------------------------+ 
//| Store request textual description                           
//+------------------------------------------------------------------+ 
void 
JournalWatch::RequestDescription(const MqlTradeRequest  &req) 
{  
   //--- if a sl/tp modification request is sent to server 
   if (req.action == TRADE_ACTION_SLTP)
   {
      int pos = this.CheckMatch(this.dataArray, (string)req.position);
      if (pos != -1)
      {  
         //--- save modified sl to data array
         this.dataArray[pos][16] = ( string )req.sl;
      }
   }
}


//---------------------------------------------------------------------
// check whether the new position number exists in array
//---------------------------------------------------------------------
int
JournalWatch::CheckMatch( string& _arr[][20], string _position )
{  
   int size = ( int )ArraySize(this.dataArray)/20;
   for (int i=0; i<size; i++)
   {
      if (this.dataArray[i][0] == _position)
      {
         return i;
      }
   }
   return -1;
} 


//---------------------------------------------------------------------
// seperate inner array from dataArray and send it to write2csv func
//---------------------------------------------------------------------
void 
JournalWatch::ExtractAndOperateOnInnerArray(string& myArray[][20], int index) {
    if(index >= 0 && index < ArraySize(myArray)/20) {
        string innerArray[20]; // Define an array to store the inner array

        // Copy the inner array from myArray to innerArray
        for(int i = 0; i < ArraySize(innerArray); i++) {
            innerArray[i] = myArray[index][i];
        }
        // Call the function to operate on the inner array
        this.Write2csv(innerArray);
    } else {
        Print("Invalid index provided.");
    }
}


//---------------------------------------------------------------------
// write equity data to csv file
//---------------------------------------------------------------------
void
JournalWatch::Write2csv( string& _arr[] )
{  
   FileSeek(this.file_handle, 0, SEEK_END);
   FileWrite(this.file_handle, 
      _arr[1], _arr[2], _arr[3], _arr[4], _arr[5],
      _arr[6], _arr[7], _arr[8], _arr[9], _arr[10],
      _arr[11], _arr[12], _arr[13], _arr[14], _arr[15], 
      _arr[16], _arr[17], _arr[18], _arr[19]);
}
