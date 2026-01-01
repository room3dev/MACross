//+------------------------------------------------------------------+
//|                                  MACrossSignalsAnalyzer.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Advanced Moving Average Crossover indicator with profit analysis,|
//| trading statistics, and on-chart historical performance tracking.|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MACrossSignalsAnalyzer"
#property version     "1.16"
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

input string      __filter__ = "--- Signal Filter ---"; // [ Filter ]
input bool        UseHTF_Filter = false;     // Use HTF Filter
input ENUM_TIMEFRAMES FilterTimeframe = PERIOD_H4; // Filter Timeframe

input string      __adr__ = "--- ADR Filter ---"; // [ ADR Filter ]
input bool        UseADR_Filter = false;    // Use ADR Filter
input double      MinADR_Upsize = 20.0;     // Min Upsize % for Buy
input double      MinADR_Downsize = 20.0;   // Min Downsize % for Sell
input int         ATRPeriod = 15;           // ATR Period for ADR

input string      __money__ = "--- Risk Analyzer ---"; // [ Money ]
input double      VirtualBalance = 1000;    // Virtual Balance ($)
input double      VirtualLotSize = 0.01;    // Virtual Lot Size
input bool        UseDynamicLot  = false;   // Dynamic Lot (Compounding)

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
    string shortName = "MAAnalyzer(" + IntegerToString(FastPeriod) + "," + IntegerToString(SlowPeriod) + ")";
    if(UseHTF_Filter) shortName += " [F:" + TimeframeToString(FilterTimeframe) + "]";
    if(UseADR_Filter) shortName += " [ADR]";
    
    IndicatorShortName(shortName);
    
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
    double entry_lot = VirtualLotSize;
    
    // Stats variables
    double max_win = 0;
    double max_loss = 0;
    int total_trades = 0;
    int win_trades = 0;
    int loss_trades = 0;
    double total_win_pips = 0;
    double total_loss_pips = 0;
    
    int cur_win_streak = 0;
    int cur_loss_streak = 0;
    int max_win_streak = 0;
    int max_loss_streak = 0;
    
    double cur_streak_pips = 0;
    double max_win_streak_pips = 0;
    double max_loss_streak_pips = 0;
    
    // Drawdown variables
    double current_balance = VirtualBalance;
    double peak_balance = VirtualBalance;
    double max_drawdown_money = 0;
    double max_drawdown_percent = 0;
    
    // Money Params
    double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
    double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
    if(tick_size == 0) tick_size = Point; // Safety
    
    double points_per_tick = tick_size / Point;
    double money_per_point = tick_value / points_per_tick;

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
        
        // 3. Filter Logic (HTF + ADR)
        bool buy_allowed = true;
        bool sell_allowed = true;
        
        // HTF Filter
        if(UseHTF_Filter)
        {
            int htf_bar = iBarShift(NULL, FilterTimeframe, time[i]);
            double htf_fast = iMA(NULL, FilterTimeframe, FastPeriod, 0, FastMethod, FastPrice, htf_bar);
            double htf_slow = iMA(NULL, FilterTimeframe, SlowPeriod, 0, SlowMethod, SlowPrice, htf_bar);
            
            if(htf_fast < htf_slow) buy_allowed = false;
            if(htf_fast > htf_slow) sell_allowed = false;
        }

        // ADR Filter
        if(UseADR_Filter)
        {
             // Determine start of day for bar i
             int day_shift = iBarShift(NULL, PERIOD_D1, time[i]);
             double daily_open = iOpen(NULL, PERIOD_D1, day_shift);
             
             // ADR Calculation (using D1 ATR from 'day_shift + 1' which matches '1' relative to today)
             // Careful: We need the ADR value that was available AT that time.
             // If we are at bar i (say 10:00 AM today), the ADR value comes from yesterday's close.
             double adr_val = iATR(NULL, PERIOD_D1, ATRPeriod, day_shift + 1) * 1.0; // Pips value if ATR returns price diff? iATR returns price diff.
             // Wait, iATR returns value in price units (e.g. 0.0050), not pips.
             
             double adr_high = daily_open + adr_val;
             double adr_low = daily_open - adr_val;
             double range = adr_high - adr_low;
             
             if(range > 0)
             {
                 double up_size = ((adr_high - close[i]) / range) * 100.0;
                 double down_size = ((close[i] - adr_low) / range) * 100.0;
                 
                 if(up_size < MinADR_Upsize) buy_allowed = false;
                 if(down_size < MinADR_Downsize) sell_allowed = false;
             }
        }

        // 4. Trade Simulation & Profit Calculation
        if(buy_cross)
        {
            // ALWAYS check for Exit Signal first (Close Sell)
            if(current_trade_type == 2) 
            {
                double trade_profit_points = (entry_price - close[i]) / Point;
                closed_profit_pips += trade_profit_points;
                total_trades++;
                
                // Money Calc
                double trade_money = trade_profit_points * money_per_point * entry_lot;
                current_balance += trade_money;
                
                // Drawdown Update
                if(current_balance > peak_balance) peak_balance = current_balance;
                double drawdown = peak_balance - current_balance;
                if(drawdown > max_drawdown_money) 
                {
                    max_drawdown_money = drawdown;
                    max_drawdown_percent = (peak_balance > 0) ? (drawdown / peak_balance * 100.0) : 0;
                }
                
                // Update Stats
                if(trade_profit_points > max_win) max_win = trade_profit_points;
                if(trade_profit_points < max_loss) max_loss = trade_profit_points;
                
                if(trade_profit_points > 0)
                {
                    win_trades++;
                    total_win_pips += trade_profit_points;
                    cur_win_streak++;
                    if(cur_loss_streak > 0) cur_streak_pips = 0;
                    cur_loss_streak = 0;
                    cur_streak_pips += trade_profit_points;
                    
                    if(cur_win_streak > max_win_streak) max_win_streak = cur_win_streak;
                    if(cur_streak_pips > max_win_streak_pips) max_win_streak_pips = cur_streak_pips;
                }
                else
                {
                    loss_trades++;
                    total_loss_pips += MathAbs(trade_profit_points);
                    cur_loss_streak++;
                    if(cur_win_streak > 0) cur_streak_pips = 0;
                    cur_win_streak = 0;
                    cur_streak_pips += trade_profit_points;
                    
                    if(cur_loss_streak > max_loss_streak) max_loss_streak = cur_loss_streak;
                    if(cur_streak_pips < max_loss_streak_pips) max_loss_streak_pips = cur_streak_pips;
                }

                if(ShowHistoryProfit) SetProfitText(time[i], low[i], trade_profit_points, 2); // 2 = Sell
            }
            
            // Check Filter for Entry
            if(buy_allowed)
            {
               entry_price = close[i];
               if(UseDynamicLot) entry_lot = MathMax(0.01, NormalizeDouble((current_balance / VirtualBalance) * VirtualLotSize, 2));
               else entry_lot = VirtualLotSize;
               
               current_trade_type = 1; // Open Buy
               SetArrow("Buy", i, time[i], low[i], high[i], BuyColor, ArrowSize, true);
            }
            else
            {
               current_trade_type = 0; // Go Flat if filtered
            }
        }
        else if(sell_cross)
        {
            // ALWAYS check for Exit Signal first (Close Buy)
            if(current_trade_type == 1) 
            {
                double trade_profit_points = (close[i] - entry_price) / Point;
                closed_profit_pips += trade_profit_points;
                total_trades++;
                
                // Money Calc
                double trade_money = trade_profit_points * money_per_point * entry_lot;
                current_balance += trade_money;
                
                // Drawdown Update
                if(current_balance > peak_balance) peak_balance = current_balance;
                double drawdown = peak_balance - current_balance;
                if(drawdown > max_drawdown_money) 
                {
                    max_drawdown_money = drawdown;
                    max_drawdown_percent = (peak_balance > 0) ? (drawdown / peak_balance * 100.0) : 0;
                }
                
                // Update Stats
                if(trade_profit_points > max_win) max_win = trade_profit_points;
                if(trade_profit_points < max_loss) max_loss = trade_profit_points;
                
                if(trade_profit_points > 0)
                {
                    win_trades++;
                    total_win_pips += trade_profit_points;
                    cur_win_streak++;
                    if(cur_loss_streak > 0) cur_streak_pips = 0;
                    cur_loss_streak = 0;
                    cur_streak_pips += trade_profit_points;
                    
                    if(cur_win_streak > max_win_streak) max_win_streak = cur_win_streak;
                    if(cur_streak_pips > max_win_streak_pips) max_win_streak_pips = cur_streak_pips;
                }
                else
                {
                    loss_trades++;
                    total_loss_pips += MathAbs(trade_profit_points);
                    cur_loss_streak++;
                    if(cur_win_streak > 0) cur_streak_pips = 0;
                    cur_win_streak = 0;
                    cur_streak_pips += trade_profit_points;
                    
                    if(cur_loss_streak > max_loss_streak) max_loss_streak = cur_loss_streak;
                    if(cur_streak_pips < max_loss_streak_pips) max_loss_streak_pips = cur_streak_pips;
                }

                if(ShowHistoryProfit) SetProfitText(time[i], high[i], trade_profit_points, 1); // 1 = Buy
            }
            
            // Check Filter for Entry
            if(sell_allowed)
            {
               entry_price = close[i];
               if(UseDynamicLot) entry_lot = MathMax(0.01, NormalizeDouble((current_balance / VirtualBalance) * VirtualLotSize, 2));
               else entry_lot = VirtualLotSize;
               
               current_trade_type = 2; // Open Sell
               SetArrow("Sell", i, time[i], low[i], high[i], SellColor, ArrowSize, false);
            }
            else
            {
               current_trade_type = 0; // Go Flat if filtered
            }
        }
    }

    // 5. Calculate Open Profit
    double open_pips = 0;
    if(current_trade_type == 1) open_pips = (Bid - entry_price) / Point;
    else if(current_trade_type == 2) open_pips = (entry_price - Bid) / Point;
    
    // Add open profit to temporary current balance for display, but don't commit it to stats yet
    double open_money = open_pips * money_per_point * entry_lot;
    double display_balance = current_balance + open_money;

    // Update Dashboard or Cleanup
    if(ShowDashboard)
    {
        string trade_type_str = "None";
        if(current_trade_type == 1) trade_type_str = "BUY";
        if(current_trade_type == 2) trade_type_str = "SELL";

        double win_rate = (total_trades > 0) ? (double)win_trades / total_trades * 100.0 : 0;
        
        // Calculate RR Ratio (Avg Win / Avg Loss)
        double avg_win = (win_trades > 0) ? total_win_pips / win_trades : 0;
        double avg_loss = (loss_trades > 0) ? total_loss_pips / loss_trades : 0;
        double rr_ratio = (avg_loss > 0) ? avg_win / avg_loss : 0;

        // Dashboard positioning
        int header_gap = int(LineSpacing * 0.8);
        int current_y = YMargin;

        SetLabel("Header", "Signals Analyzer Pro", clrWhite, FontSize + 2, XMargin, current_y);
        current_y += LineSpacing + header_gap;
        
        string filter_str = (UseHTF_Filter ? "HTF(" + TimeframeToString(FilterTimeframe) + ")" : "") + (UseADR_Filter ? (UseHTF_Filter ? " + " : "") + "ADR" : "");
        if(!UseHTF_Filter && !UseADR_Filter) filter_str = "OFF";
        
        SetLabel("Line0", "Filter: " + filter_str, ((UseHTF_Filter || UseADR_Filter) ? clrLime : clrGray), FontSize - 1, XMargin, current_y);
        current_y += LineSpacing;

        // Line 1: Closed Pips | Current Pips
        string line1_text = "Closed: " + DoubleToString(closed_profit_pips, 0) + " pips | Current(" + trade_type_str + "): " + DoubleToString(open_pips, 0) + " pips";
        SetLabel("Line1", line1_text, clrWhite, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 2: W / L / ALL (Moved to new line)
        string line2_text = "W: " + IntegerToString(win_trades) + " / L: " + IntegerToString(loss_trades) + " / ALL: " + IntegerToString(total_trades);
        SetLabel("Line2", line2_text, clrYellow, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 3: Total Net | WR
        SetLabel("Line3", "Total Net: " + DoubleToString(closed_profit_pips + open_pips, 0) + " pips | WR: " + DoubleToString(win_rate, 1) + "%", clrWhite, FontSize, XMargin, current_y);
        current_y += LineSpacing + header_gap; // Extra gap before stats
        
        // Line 4: Balance | MaxDD
        double balance_pct = (VirtualBalance > 0) ? ((display_balance - VirtualBalance) / VirtualBalance * 100.0) : 0;
        string bal_str = "Bal: $" + DoubleToString(display_balance, 2) + " (" + (balance_pct >= 0 ? "+" : "") + DoubleToString(balance_pct, 1) + "%)";
        SetLabel("Line4", bal_str + " | MaxDD: $" + DoubleToString(max_drawdown_money, 2) + " (" + DoubleToString(max_drawdown_percent, 1) + "%)", clrAqua, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 5: Avg Win | Avg Loss | RR
        SetLabel("Line5", "Avg Win: " + DoubleToString(avg_win, 0) + " | Avg Loss: " + DoubleToString(avg_loss, 0) + " | RR: " + DoubleToString(rr_ratio, 2), clrWhite, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 6: Max Win | Max Loss
        SetLabel("Line6", "Max Win: " + DoubleToString(max_win, 0) + " | Max Loss: " + DoubleToString(max_loss, 0), clrWhite, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 7: Win Streak
        SetLabel("Line7", "Winning Streak: " + IntegerToString(max_win_streak) + " (" + DoubleToString(max_win_streak_pips, 0) + " pips)", clrLime, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        // Line 8: Loss Streak
        SetLabel("Line8", "Losing Streak: " + IntegerToString(max_loss_streak) + " (" + DoubleToString(max_loss_streak_pips, 0) + " pips)", clrRed, FontSize-1, XMargin, current_y);
        
        Comment("Win Rate: " + DoubleToString(win_rate, 1) + "%\n" +
                "Balance: $" + DoubleToString(display_balance, 2) + "\n" +
                "Max DD: " + DoubleToString(max_drawdown_percent, 1) + "%");
    }
    else
    {
        DeleteDashboard();
        Comment("");
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Get timeframe string representation                              |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return("M1");
        case PERIOD_M5:  return("M5");
        case PERIOD_M15: return("M15");
        case PERIOD_M30: return("M30");
        case PERIOD_H1:  return("H1");
        case PERIOD_H4:  return("H4");
        case PERIOD_D1:  return("D1");
        case PERIOD_W1:  return("W1");
        case PERIOD_MN1: return("MN1");
    }
    return("Current");
}

//+------------------------------------------------------------------+
//| Create or update signal arrow                                    |
//+------------------------------------------------------------------+
void SetArrow(string type, int idx, datetime t, double lowVal, double highVal, color col, int size, bool isBuy)
{
    double price = isBuy ? lowVal - ArrowOffsetPips * Point : highVal + ArrowOffsetPips * Point;
    int code = 108; // Wingdings code for bullet (circle)
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
void SetProfitText(datetime t, double refPrice, double profit, int tradeType)
{
    // tradeType: 1=Buy (Closed), 2=Sell (Closed)
    string typeStr = (tradeType == 1) ? "BUY" : "SELL";
    string text = typeStr + " " + (profit >= 0 ? "+" : "") + DoubleToString(profit, 0) + " pips";
    color textColor = (profit >= 0) ? clrLime : clrRed;
    int textOffset = ArrowOffsetPips + 15;
    
    double price = 0;
    int anchor = 0;
    
    if(tradeType == 2) // Closing Sell (At Buy Arrow)
    {
        price = refPrice - textOffset * Point;
        anchor = 3; // ANCHOR_TOP
    }
    else // Closing Buy (At Sell Arrow)
    {
        price = refPrice + textOffset * Point;
        anchor = 5; // ANCHOR_BOTTOM
    }

    string name = "[MACross] Profit " + TimeToString(t);

    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_TEXT, 0, t, price);
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
    ObjectDelete("[MACross] Dashboard Line0");
    ObjectDelete("[MACross] Dashboard Line1");
    ObjectDelete("[MACross] Dashboard Line2");
    ObjectDelete("[MACross] Dashboard Line3");
    ObjectDelete("[MACross] Dashboard Line4");
    ObjectDelete("[MACross] Dashboard Line5");
    ObjectDelete("[MACross] Dashboard Line6");
    ObjectDelete("[MACross] Dashboard Line7");
    ObjectDelete("[MACross] Dashboard Line8");
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
