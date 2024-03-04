trade journal in mt5
------------------------
JournalWatch class in journal.mqh receives transaction and request data from each trade user or EA send to server and makes a copy of necessary data needed.

returned file has following columns:
Symbol,Type,Start time,End time,Result,Profit,Open price,Volume,Stop loss,Take Profit,Modified Stop loss,Swap,Comission,Comment

also file is stored in Common folder.

-----------------------
as for trade strategy there is a simple EA that uses RSI to trade and demonstrate the use of JournalWatch class.

-----------------------
created 3/4/2024