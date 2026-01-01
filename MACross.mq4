//+------------------------------------------------------------------+
//|                                                      MACross.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Professional 2 Moving Average Crossover indicator with signal    |
//| arrows on chart and profit tracking.                             |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MarketRange-ADR"
#property version     "1.01"
#property strict
#property indicator_chart_window

//--- Buffers (Hidden for line plotting only)
#property indicator_buffers 2
#property indicator_color1 clrCyan
#property indicator_color2 clrMagenta
#property indicator_width1 1
#property indicator_width2 1

//--- Input Parameters
input string __fasta__ = "--- Fast Moving Average ---"; // [ Fast MA ]
input int FastPeriod = 12; // Fast MA Period
input ENUM_MA_METHOD FastMethod = MODE_EMA; // Fast MA Method
input ENUM_APPLIED_PRICE FastPrice = PRICE_CLOSE; // Fast MA Applied Price
input color FastColor = clrCyan; // Fast MA Color
input int FastSize = 1; // Fast MA Size

input string __slowa__ = "--- Slow Moving Average ---"; // [ Slow MA ]
input int SlowPeriod = 26; // Slow MA Period
input ENUM_MA_METHOD SlowMethod = MODE_SMA; // Slow MA Method
input ENUM_APPLIED_PRICE SlowPrice = PRICE_CLOSE; // Slow MA Applied Price
input color SlowColor = clrMagenta; // Slow MA Color
input int SlowSize = 1; // Slow MA Size

input string __signals__ = "--- Signal Visuals ---"; // [ Signals ]
input color BuyColor = clrLime; // Buy Arrow Color
input color SellColor = clrRed; // Sell Arrow Color
input int ArrowSize = 2; // Arrow Size
input int ArrowOffsetPips = 10; // Arrow Offset(Pips)

//--- Buffers
double FastBuffer[];
double SlowBuffer[];

//--- Global Variables
datetime timelastupdate = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorShortName("MACross(" + IntegerToString(FastPeriod) + ", " + IntegerToString(SlowPeriod) + ")");
    
    // Setup Buffers
    SetIndexBuffer(0, FastBuffer);
    SetIndexBuffer(1, SlowBuffer);
    
    SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, FastSize, FastColor);
    SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, SlowSize, SlowColor);
    
    SetIndexLabel(0, "Fast MA(" + IntegerToString(FastPeriod) + ")");
    SetIndexLabel(1, "Slow MA(" + IntegerToString(SlowPeriod) + ")");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
const int prev_calculated,
const datetime &time[],
const double &open[],
const double &high[],
const double &low[],
const double &close[],
const long &tick_volume[],
const long &volume[],
const int &spread[])
{
    if(rates_total < SlowPeriod + 1) return(rates_total);

    // Ensure arrays are treated as series (index 0 is latest bar)
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    // Reset indicator variables for full re-calculation
    double closed_profit_pips = 0;
    int current_trade_type = 0; // 0 = None, 1 = Buy, 2 = Sell
    double entry_price = 0;
    
    // We calculate from oldest to newest to track "trades"
    for(int i = rates_total - SlowPeriod - 2; i >= 0; i--)
    {
        // 1. Calculate MA Values
        double fast0 = iMA(NULL, 0, FastPeriod, 0, FastMethod, FastPrice, i);
        double slow0 = iMA(NULL, 0, SlowPeriod, 0, SlowMethod, SlowPrice, i);
        double fast1 = iMA(NULL, 0, FastPeriod, 0, FastMethod, FastPrice, i + 1);
        double slow1 = iMA(NULL, 0, SlowPeriod, 0, SlowMethod, SlowPrice, i + 1);

        FastBuffer[i] = fast0;
        SlowBuffer[i] = slow0;

        // 2. Cross Detection
        bool buy_cross = (fast1 <= slow1 && fast0 > slow0);
        bool sell_cross = (fast1 >= slow1 && fast0 < slow0);

        // 3. Trade Simulation & Profit Calculation
        if(buy_cross)
        {
            if(current_trade_type == 2) // Close Sell
            {
                closed_profit_pips + = (entry_price - close[i]) / Point;
            }
            entry_price = close[i];
            current_trade_type = 1;
            SetArrow("Buy", i, time[i], low[i], high[i], BuyColor, ArrowSize, true);
        }
        else if(sell_cross)
        {
            if(current_trade_type == 1) // Close Buy
            {
                closed_profit_pips + = (close[i] - entry_price) / Point;
            }
            entry_price = close[i];
            current_trade_type = 2;
            SetArrow("Sell", i, time[i], low[i], high[i], SellColor, ArrowSize, false);
        }
    }

    // 4. Calculate Open Profit
    double open_pips = 0;
    if(current_trade_type == 1) open_pips = (Bid - entry_price) / Point;
    else if(current_trade_type == 2) open_pips = (entry_price - Bid) / Point;

    // Update Status Label
    string trade_type_str = "None";
    if(current_trade_type == 1) trade_type_str = "BUY";
    if(current_trade_type == 2) trade_type_str = "SELL";

    string infoStr = "MACross Signals Profit\n" +
    "Closed: " + DoubleToString(closed_profit_pips, 1) + " pips\n" +
    "Current(" + trade_type_str + "): " + DoubleToString(open_pips, 1) + " pips\n" +
    "Total Net: " + DoubleToString(closed_profit_pips + open_pips, 1) + " pips";
    
    SetLabel("Status", infoStr, clrWhite, 10, 10, 10);
    Comment(infoStr);

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Create or update signal arrow                                    |
//+------------------------------------------------------------------+
void SetArrow(string type, int idx, datetime t, double lowVal, double highVal, color col, int size, bool isBuy)
{
    double price = isBuy ? lowVal - ArrowOffsetPips * Point : highVal + ArrowOffsetPips * Point;
    int code = isBuy ? 233 : 234; // Wingdings codes for up / down arrows
    string name = "[MACross] " + type + " signal @ " + TimeToString(t);

    if(ObjectFind(name) == - 1)
    {
        ObjectCreate(name, OBJ_ARROW, 0, t, price);
        ObjectSet(name, OBJPROP_ARROWCODE, code);
        ObjectSet(name, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
    }

    ObjectSet(name, OBJPROP_COLOR, col);
    ObjectSet(name, OBJPROP_WIDTH, size);
    ObjectMove(name, 0, t, price);
}

//+------------------------------------------------------------------+
//| Create or update text label in corner                            |
//+------------------------------------------------------------------+
void SetLabel(string text, string val, color col, int size, int x, int y)
{
    string name = "[MACross] " + text + " Label";
    if(ObjectFind(name) == - 1)
    {
        ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
        ObjectSet(name, OBJPROP_CORNER, 1); // Top Right
        ObjectSet(name, OBJPROP_ANCHOR, 6); // ANCHOR_RIGHT_UP
    }
   
    ObjectSetText(name, val, size, "Arial Bold", col);
    ObjectSet(name, OBJPROP_XDISTANCE, x);
    ObjectSet(name, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                     |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(StringFind(name, "[MACross]") == 0)
        ObjectDelete(name);
    }
}
