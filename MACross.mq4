//+------------------------------------------------------------------+
//|                                                      MACross.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Professional 2 Moving Average Crossover indicator with signal    |
//| arrows on chart and configurable profit tracking dashboard.      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MACross"
#property version     "1.08"
#property strict
#property indicator_chart_window

//--- Buffers (Hidden for line plotting only)
#property indicator_buffers 2
#property indicator_color1 clrCyan
#property indicator_color2 clrMagenta
#property indicator_width1 1
#property indicator_width2 1

//--- Input Parameters
input string      __fasta__ = "--- Fast Moving Average ---"; // [ Fast MA ]
input int         FastPeriod = 9;           // Fast MA Period
input ENUM_MA_METHOD FastMethod = MODE_EMA;  // Fast MA Method
input ENUM_APPLIED_PRICE FastPrice = PRICE_CLOSE; // Fast MA Applied Price
input color       FastColor = clrCyan;      // Fast MA Color
input int         FastSize = 1;             // Fast MA Size

input string      __slowa__ = "--- Slow Moving Average ---"; // [ Slow MA ]
input int         SlowPeriod = 21;          // Slow MA Period
input ENUM_MA_METHOD SlowMethod = MODE_EMA;  // Slow MA Method
input ENUM_APPLIED_PRICE SlowPrice = PRICE_CLOSE; // Slow MA Applied Price
input color       SlowColor = clrMagenta;   // Slow MA Color
input int         SlowSize = 1;             // Slow MA Size

input string      __signals__ = "--- Signal Visuals ---"; // [ Signals ]
input color       BuyColor = clrLime;       // Buy Arrow Color
input color       SellColor = clrRed;        // Sell Arrow Color
input int         ArrowSize = 2;            // Arrow Size
input int         ArrowOffsetPips = 10;     // Arrow Offset (Pips)
input bool        ShowHistoryProfit = true; // Show Profit on Chart

input string      __ui__ = "--- Dashboard Settings ---"; // [ Dashboard ]
input bool        ShowDashboard = true;     // Show Profit Dashboard
input int         XMargin = 10;             // Text Margin X (Pixels)
input int         YMargin = 10;             // Text Margin Y (Pixels)
input int         FontSize = 10;            // Dashboard Font Size
input int         LineSpacing = 18;         // Vertical Line Spacing

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
    IndicatorShortName("MACross(" + IntegerToString(FastPeriod) + "," + IntegerToString(SlowPeriod) + ")");
    
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
    int current_trade_type = 0; // 0=None, 1=Buy, 2=Sell
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
                double trade_profit = (entry_price - close[i]) / Point;
                closed_profit_pips += trade_profit;
                if(ShowHistoryProfit) SetProfitText(i, time[i], low[i], trade_profit, 2); // 2 = Sell
            }
            entry_price = close[i];
            current_trade_type = 1;
            SetArrow("Buy", i, time[i], low[i], high[i], BuyColor, ArrowSize, true);
        }
        else if(sell_cross)
        {
            if(current_trade_type == 1) // Close Buy
            {
                double trade_profit = (close[i] - entry_price) / Point;
                closed_profit_pips += trade_profit;
                if(ShowHistoryProfit) SetProfitText(i, time[i], high[i], trade_profit, 1); // 1 = Buy
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

    // Update Dashboard or Cleanup
    if(ShowDashboard)
    {
        string trade_type_str = "None";
        if(current_trade_type == 1) trade_type_str = "BUY";
        if(current_trade_type == 2) trade_type_str = "SELL";

        // Add extra vertical gap after the header
        int header_gap = int(LineSpacing * 0.8);

        SetLabel("Header", "MACross Signals Profit", clrWhite, FontSize + 2, XMargin, YMargin);
        SetLabel("Line1", "Closed: " + DoubleToString(closed_profit_pips, 0) + " pips", clrWhite, FontSize, XMargin, YMargin + LineSpacing + header_gap);
        SetLabel("Line2", "Current(" + trade_type_str + "): " + DoubleToString(open_pips, 0) + " pips", clrWhite, FontSize, XMargin, YMargin + (LineSpacing * 2) + header_gap);
        SetLabel("Line3", "Total Net: " + DoubleToString(closed_profit_pips + open_pips, 0) + " pips", clrWhite, FontSize, XMargin, YMargin + (LineSpacing * 3) + header_gap);
        
        Comment("Closed: " + DoubleToString(closed_profit_pips, 0) + "\n" +
                "Current: " + DoubleToString(open_pips, 0) + "\n" +
                "Total: " + DoubleToString(closed_profit_pips + open_pips, 0));
    }
    else
    {
        DeleteDashboard();
        Comment("");
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Create or update signal arrow                                    |
//+------------------------------------------------------------------+
void SetArrow(string type, int idx, datetime t, double lowVal, double highVal, color col, int size, bool isBuy)
{
    double price = isBuy ? lowVal - ArrowOffsetPips * Point : highVal + ArrowOffsetPips * Point;
    int code = isBuy ? 233 : 234; // Wingdings codes for up/down arrows
    string name = "[MACross] " + type + " signal @ " + TimeToString(t);

    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_ARROW, 0, t, price);
        ObjectSet(name, OBJPROP_ARROWCODE, code);
        ObjectSet(name, OBJPROP_ANCHOR, isBuy ? 3 : 5); // 3=ANCHOR_TOP, 5=ANCHOR_BOTTOM
    }

    ObjectSet(name, OBJPROP_COLOR, col);
    ObjectSet(name, OBJPROP_WIDTH, size);
    ObjectMove(name, 0, t, price);
}

//+------------------------------------------------------------------+
//| Create or update profit text                                     |
//+------------------------------------------------------------------+
void SetProfitText(int idx, datetime t, double refPrice, double profit, int tradeType)
{
    // tradeType: 1=Buy (Closed), 2=Sell (Closed)
    // If tradeType=2 (Sell closed), we are at a Buy Arrow. Text goes BELOW.
    // If tradeType=1 (Buy closed), we are at a Sell Arrow. Text goes ABOVE.
    
    // Format: "TYPE +Pips"
    string typeStr = (tradeType == 1) ? "BUY" : "SELL";
    string text = typeStr + " " + (profit >= 0 ? "+" : "") + DoubleToString(profit, 0) + " pips";
    
    // Color
    color textColor = (profit >= 0) ? clrLime : clrRed;
    
    // Position
    // ArrowOffsetPips is distance from High/Low to Arrow center/tip.
    // We want text further out. Let's add another 15 pips or so? Or scale with ArrowOffset.
    int textOffset = ArrowOffsetPips + 15;
    
    double price = 0;
    int anchor = 0;
    
    if(tradeType == 2) // Closing Sell (At Buy Arrow - Bottom)
    {
        // Arrow is at Low - ArrowOffset. Text goes below that.
        price = refPrice - textOffset * Point;
        anchor = 3; // ANCHOR_TOP (So text hangs down from this point? No, standard text anchor behavior)
        // For OBJ_TEXT, ANCHOR_TOP means the text is physically below the point.
    }
    else // Closing Buy (At Sell Arrow - Top)
    {
        price = refPrice + textOffset * Point;
        anchor = 5; // ANCHOR_BOTTOM (Text sits on top of this point)
    }

    string name = "[MACross] Profit " + TimeToString(t);

    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_TEXT, 0, t, price);
        ObjectSet(name, OBJPROP_FONT, "Arial");
        ObjectSet(name, OBJPROP_FONTSIZE, 8);
    }

    ObjectSetText(name, text, 8, "Arial", textColor);
    ObjectSet(name, OBJPROP_ANCHOR, anchor);
    ObjectMove(name, 0, t, price);
}

//+------------------------------------------------------------------+
//| Create or update text label in corner                            |
//+------------------------------------------------------------------+
void SetLabel(string text, string val, color col, int size, int x, int y)
{
    string name = "[MACross] Dashboard " + text;
    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
        ObjectSet(name, OBJPROP_CORNER, 1); // 1 = CORNER_RIGHT_UPPER
        ObjectSet(name, OBJPROP_ANCHOR, 6); // 6 = ANCHOR_RIGHT_UPPER
    }
   
    ObjectSetText(name, val, size, "Arial Bold", col);
    ObjectSet(name, OBJPROP_XDISTANCE, x);
    ObjectSet(name, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| Delete dashboard labels                                          |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
    ObjectDelete("[MACross] Dashboard Header");
    ObjectDelete("[MACross] Dashboard Line1");
    ObjectDelete("[MACross] Dashboard Line2");
    ObjectDelete("[MACross] Dashboard Line3");
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
