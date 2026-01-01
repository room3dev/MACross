//+------------------------------------------------------------------+
//|                                                      MACross.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Professional 2 Moving Average Crossover indicator with signal    |
//| arrows on chart.                                                 |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MarketRange-ADR"
#property version     "1.00"
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

    // Limit calculation to new bars or initial run
    int limit = rates_total - prev_calculated;
    if(limit > 1) limit = rates_total - SlowPeriod - 1;
    if(limit < 0) limit = 0;

    for(int i = limit; i >= 0; i--)
    {
        // 1. Calculate MA Values
        double fast0 = iMA(NULL, 0, FastPeriod, 0, FastMethod, FastPrice, i);
        double slow0 = iMA(NULL, 0, SlowPeriod, 0, SlowMethod, SlowPrice, i);
        double fast1 = iMA(NULL, 0, FastPeriod, 0, FastMethod, FastPrice, i + 1);
        double slow1 = iMA(NULL, 0, SlowPeriod, 0, SlowMethod, SlowPrice, i + 1);

        FastBuffer[i] = fast0;
        SlowBuffer[i] = slow0;

        // 2. Cross Detection (only on closed bars or current bar)
        bool buy_signal = (fast1 <= slow1 && fast0 > slow0);
        bool sell_signal = (fast1 >= slow1 && fast0 < slow0);

        // 3. Signal Placement (Objects)
        if(buy_signal)
        {
            SetArrow("Buy", i, time[i], low[i], high[i], BuyColor, ArrowSize, true);
        }
        else if(sell_signal)
        {
            SetArrow("Sell", i, time[i], low[i], high[i], SellColor, ArrowSize, false);
        }
    }

    // Update Status Label
    double current_diff = (FastBuffer[0] - SlowBuffer[0]) / Point;
    string infoStr = "MACross(" + IntegerToString(FastPeriod) + " / " + IntegerToString(SlowPeriod) + ")\n" +
    "Diff: " + DoubleToString(current_diff, 1) + " pips";
    
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
