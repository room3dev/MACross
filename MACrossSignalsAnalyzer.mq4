//+------------------------------------------------------------------+
//|                                  MACrossSignalsAnalyzer.mq4 |
//|                   Copyright 2026, MarketRange. All rights reserved. |
//|                                                                  |
//| Advanced Moving Average Crossover indicator with profit analysis,|
//| trading statistics, and on-chart historical performance tracking.|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, MarketRange"
#property link        "https://github.com/room3dev/MACrossSignalsAnalyzer"
#property version     "1.17"
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

input string      __ichimoku__ = "--- Ichimoku Filter ---"; // [ Ichimoku ]
input bool        UseIchimokuFilter = false;  // Use Ichimoku Filter
input ENUM_TIMEFRAMES IchimokuTimeframe = PERIOD_H4; // Ichimoku Timeframe

input string      __adr__ = "--- ADR Filter ---"; // [ ADR Filter ]
input bool        UseADR_Filter = false;    // Use ADR Filter
input double      MinADR_Upsize = 20.0;     // Min Upsize % for Buy
input double      MinADR_Downsize = 20.0;   // Min Downsize % for Sell
input int         ATRPeriod = 15;           // ATR Period for ADR

input string      __money__ = "--- Risk Analyzer ---"; // [ Money ]
input double      VirtualBalance = 1000;    // Virtual Balance ($)
input double      VirtualLotSize = 0.01;    // Virtual Lot Size
input bool        UseDynamicLot  = false;   // Dynamic Lot (Compounding)
input int         FixedStopLoss  = 0;       // Fixed Stop Loss (Pips, 0=Off)
input int         MaxTradesToAnalyze = 100; // Last X orders for Stats

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
    if(UseIchimokuFilter) shortName += " [Ichimoku]";
    
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
    int current_trade_type = 0; // 0=None, 1=Buy, 2=Sell
    double entry_price = 0;
    double entry_lot = VirtualLotSize;
    
    // History Tracking
    double trade_history[];
    ArrayResize(trade_history, 0);
    int total_buy_signals = 0;
    int total_sell_signals = 0;
    int total_trades_all = 0;
    
    // Money Params
    double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
    double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
    if(tick_size == 0) tick_size = Point; // Safety
    
    double points_per_tick = tick_size / Point;
    double money_per_point = tick_value / points_per_tick;

    // Simulation Loop (Backward: oldest to newest)
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
        
        // 2.1 Stop Loss Check (At Bar Close)
        if(FixedStopLoss > 0 && current_trade_type != 0)
        {
            double floating_pips = 0;
            if(current_trade_type == 1) floating_pips = (close[i] - entry_price) / Point;
            else if(current_trade_type == 2) floating_pips = (entry_price - close[i]) / Point;
            
            if(floating_pips <= -FixedStopLoss)
            {
                int sz = ArraySize(trade_history);
                ArrayResize(trade_history, sz + 1);
                trade_history[sz] = floating_pips;
                total_trades_all++;

                if(ShowHistoryProfit) SetProfitText(time[i], close[i], floating_pips, (current_trade_type == 1 ? 3 : 4));
                current_trade_type = 0;
            }
        }
        
        // 3. Filter Logic (HTF + ADR + Ichimoku)
        bool buy_allowed = true;
        bool sell_allowed = true;
        
        if(UseHTF_Filter)
        {
            int htf_bar = iBarShift(NULL, FilterTimeframe, time[i]);
            double htf_fast = iMA(NULL, FilterTimeframe, FastPeriod, 0, FastMethod, FastPrice, htf_bar);
            double htf_slow = iMA(NULL, FilterTimeframe, SlowPeriod, 0, SlowMethod, SlowPrice, htf_bar);
            if(htf_fast < htf_slow) buy_allowed = false;
            if(htf_fast > htf_slow) sell_allowed = false;
        }

        if(UseADR_Filter)
        {
             int day_shift = iBarShift(NULL, PERIOD_D1, time[i]);
             double daily_open = iOpen(NULL, PERIOD_D1, day_shift);
             double adr_val = iATR(NULL, PERIOD_D1, ATRPeriod, day_shift + 1);
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
        
        if(UseIchimokuFilter)
        {
             int ichi_bar = iBarShift(NULL, IchimokuTimeframe, time[i]);
             double spanA = iIchimoku(NULL, IchimokuTimeframe, 9, 26, 52, MODE_SENKOUSPANA, ichi_bar);
             double spanB = iIchimoku(NULL, IchimokuTimeframe, 9, 26, 52, MODE_SENKOUSPANB, ichi_bar);
             if(close[i] <= MathMax(spanA, spanB)) buy_allowed = false;
             if(close[i] >= MathMin(spanA, spanB)) sell_allowed = false;
        }

        // 4. Trade Simulation
        if(buy_cross)
        {
            if(current_trade_type == 2) 
            {
                double pips = (entry_price - close[i]) / Point;
                int sz = ArraySize(trade_history);
                ArrayResize(trade_history, sz + 1);
                trade_history[sz] = pips;
                total_trades_all++;
                if(ShowHistoryProfit) SetProfitText(time[i], low[i], pips, 2);
            }
            if(buy_allowed)
            {
               entry_price = close[i];
               total_buy_signals++;
               current_trade_type = 1; 
               SetArrow("Buy", i, time[i], low[i], high[i], BuyColor, ArrowSize, true);
            }
            else current_trade_type = 0;
        }
        else if(sell_cross)
        {
            if(current_trade_type == 1) 
            {
                double pips = (close[i] - entry_price) / Point;
                int sz = ArraySize(trade_history);
                ArrayResize(trade_history, sz + 1);
                trade_history[sz] = pips;
                total_trades_all++;
                if(ShowHistoryProfit) SetProfitText(time[i], high[i], pips, 1);
            }
            if(sell_allowed)
            {
               entry_price = close[i];
               total_sell_signals++;
               current_trade_type = 2; 
               SetArrow("Sell", i, time[i], low[i], high[i], SellColor, ArrowSize, false);
            }
            else current_trade_type = 0;
        }
    }

    // 5. Statistics Calculation (Last X Only)
    double closed_profit_pips = 0;
    int win_trades = 0;
    int loss_trades = 0;
    double total_win_pips = 0;
    double total_loss_pips = 0;
    double max_win = 0, max_loss = 0;
    int cur_win_streak = 0, cur_loss_streak = 0;
    int max_win_streak = 0, max_loss_streak = 0;
    double cur_streak_pips = 0;
    double max_win_streak_pips = 0, max_loss_streak_pips = 0;
    
    // Drawdown Calculation (Always full history simulation to be accurate, but stats display limit?)
    // Actually, user wants stats for last X. So let's simulate money ONLY for the last X.
    double current_balance = VirtualBalance;
    double peak_balance = VirtualBalance;
    double max_drawdown_money = 0;
    double max_drawdown_percent = 0;

    int total_history = ArraySize(trade_history);
    int startIndex = 0;
    if(MaxTradesToAnalyze > 0) startIndex = MathMax(0, total_history - MaxTradesToAnalyze);
    
    int analyzed_count = 0;

    for(int j = startIndex; j < total_history; j++)
    {
        double pips = trade_history[j];
        closed_profit_pips += pips;
        analyzed_count++;
        
        // Money Analysis (Compounding respects analyzed start)
        double current_lot = VirtualLotSize;
        if(UseDynamicLot) current_lot = MathMax(0.01, NormalizeDouble((current_balance / VirtualBalance) * VirtualLotSize, 2));
        
        double trade_money = pips * money_per_point * current_lot;
        current_balance += trade_money;
        if(current_balance > peak_balance) peak_balance = current_balance;
        double dd = peak_balance - current_balance;
        if(dd > max_drawdown_money)
        {
            max_drawdown_money = dd;
            max_drawdown_percent = (peak_balance > 0) ? (dd / peak_balance * 100.0) : 0;
        }

        // Stats
        if(pips > max_win) max_win = pips;
        if(pips < max_loss) max_loss = pips;

        if(pips > 0)
        {
            win_trades++;
            total_win_pips += pips;
            cur_win_streak++;
            if(cur_loss_streak > 0) cur_streak_pips = 0;
            cur_loss_streak = 0;
            cur_streak_pips += pips;
            if(cur_win_streak > max_win_streak) max_win_streak = cur_win_streak;
            if(cur_streak_pips > max_win_streak_pips) max_win_streak_pips = cur_streak_pips;
        }
        else
        {
            loss_trades++;
            total_loss_pips += MathAbs(pips);
            cur_loss_streak++;
            if(cur_win_streak > 0) cur_streak_pips = 0;
            cur_win_streak = 0;
            cur_streak_pips += pips;
            if(cur_loss_streak > max_loss_streak) max_loss_streak = cur_loss_streak;
            if(cur_streak_pips < max_loss_streak_pips) max_loss_streak_pips = cur_streak_pips;
        }
    }

    // 6. Current Open Trade
    double open_pips = 0;
    if(current_trade_type == 1) open_pips = (Bid - entry_price) / Point;
    else if(current_trade_type == 2) open_pips = (entry_price - Bid) / Point;
    
    double entry_lot_final = VirtualLotSize;
    if(UseDynamicLot) entry_lot_final = MathMax(0.01, NormalizeDouble((current_balance / VirtualBalance) * VirtualLotSize, 2));
    
    double open_money = open_pips * money_per_point * entry_lot_final;
    double display_balance = current_balance + open_money;

    // 7. Dashboard
    if(ShowDashboard)
    {
        string trade_type_str = "None";
        if(current_trade_type == 1) trade_type_str = "BUY";
        if(current_trade_type == 2) trade_type_str = "SELL";

        double win_rate = (analyzed_count > 0) ? (double)win_trades / analyzed_count * 100.0 : 0;
        double avg_win = (win_trades > 0) ? total_win_pips / win_trades : 0;
        double avg_loss = (loss_trades > 0) ? total_loss_pips / loss_trades : 0;
        double rr_ratio = (avg_loss > 0) ? avg_win / avg_loss : 0;

        int header_gap = int(LineSpacing * 0.8);
        int current_y = YMargin;

        string limit_str = (MaxTradesToAnalyze > 0) ? " [" + IntegerToString(MaxTradesToAnalyze) + "]" : "";
        SetLabel("Header", "Signals Analyzer Pro" + limit_str, clrWhite, FontSize + 2, XMargin, current_y);
        current_y += LineSpacing + header_gap;
        
        string ichi_tf = TimeframeToString(IchimokuTimeframe);
        string filter_str = (UseHTF_Filter ? "HTF(" + TimeframeToString(FilterTimeframe) + ")" : "") + 
                           (UseADR_Filter ? (UseHTF_Filter ? " + " : "") + "ADR" : "") +
                           (UseIchimokuFilter ? (UseHTF_Filter || UseADR_Filter ? " + " : "") + "Ichimoku(" + ichi_tf + ")" : "");
        if(!UseHTF_Filter && !UseADR_Filter && !UseIchimokuFilter) filter_str = "OFF";
        
        SetLabel("Line0", "Filter: " + filter_str, ((UseHTF_Filter || UseADR_Filter || UseIchimokuFilter) ? clrLime : clrGray), FontSize - 1, XMargin, current_y);
        current_y += LineSpacing;

        string line1_text = "Closed: " + DoubleToString(closed_profit_pips, 0) + " pips | Current(" + trade_type_str + "): " + DoubleToString(open_pips, 0) + " pips";
        SetLabel("Line1", line1_text, clrWhite, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        string line2_text = "W: " + IntegerToString(win_trades) + " / L: " + IntegerToString(loss_trades) + " / ALL: " + IntegerToString(analyzed_count);
        SetLabel("Line2", line2_text, clrYellow, FontSize, XMargin, current_y);
        current_y += LineSpacing;

        string line3_text = "TOTAL BUYS: " + IntegerToString(total_buy_signals) + " / SELLS: " + IntegerToString(total_sell_signals);
        SetLabel("Line3", line3_text, clrAqua, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        SetLabel("Line4", "Total Net: " + DoubleToString(closed_profit_pips + open_pips, 0) + " pips | WR: " + DoubleToString(win_rate, 1) + "%", clrWhite, FontSize, XMargin, current_y);
        current_y += LineSpacing + header_gap; 
        
        double balance_pct = (VirtualBalance > 0) ? ((display_balance - VirtualBalance) / VirtualBalance * 100.0) : 0;
        string bal_str = "Bal: $" + DoubleToString(display_balance, 2) + " (" + (balance_pct >= 0 ? "+" : "") + DoubleToString(balance_pct, 1) + "%)";
        string sl_str = (FixedStopLoss > 0) ? " | SL: " + IntegerToString(FixedStopLoss) + " pips" : "";
        SetLabel("Line5", bal_str + " | MaxDD: $" + DoubleToString(max_drawdown_money, 2) + " (" + DoubleToString(max_drawdown_percent, 1) + "%)" + sl_str, clrAqua, FontSize, XMargin, current_y);
        current_y += LineSpacing;
        
        SetLabel("Line6", "Avg Win: " + DoubleToString(avg_win, 0) + " | Avg Loss: " + DoubleToString(avg_loss, 0) + " | RR: " + DoubleToString(rr_ratio, 2), clrWhite, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        SetLabel("Line7", "Max Win: " + DoubleToString(max_win, 0) + " | Max Loss: " + DoubleToString(max_loss, 0), clrWhite, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        SetLabel("Line8", "Winning Streak: " + IntegerToString(max_win_streak) + " (" + DoubleToString(max_win_streak_pips, 0) + " pips)", clrLime, FontSize-1, XMargin, current_y);
        current_y += LineSpacing;
        
        SetLabel("Line9", "Losing Streak: " + IntegerToString(max_loss_streak) + " (" + DoubleToString(max_loss_streak_pips, 0) + " pips)", clrRed, FontSize-1, XMargin, current_y);
    }
    else DeleteDashboard();

    return(rates_total);
}

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

void SetArrow(string type, int idx, datetime t, double lowVal, double highVal, color col, int size, bool isBuy)
{
    double price = isBuy ? lowVal - ArrowOffsetPips * Point : highVal + ArrowOffsetPips * Point;
    int code = 108; 
    string name = "[MACross] " + type + " signal @ " + TimeToString(t);
    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_ARROW, 0, t, price);
        ObjectSet(name, OBJPROP_ARROWCODE, code);
        ObjectSet(name, OBJPROP_ANCHOR, isBuy ? 3 : 5);
    }
    ObjectSet(name, OBJPROP_COLOR, col);
    ObjectSet(name, OBJPROP_WIDTH, size);
    ObjectMove(name, 0, t, price);
}

void SetProfitText(datetime t, double refPrice, double profit, int tradeType)
{
    string typeStr = "BUY";
    if(tradeType == 2 || tradeType == 4) typeStr = "SELL";
    string prefix = (tradeType > 2) ? "SL " : "";
    string text = prefix + typeStr + " " + (profit >= 0 ? "+" : "") + DoubleToString(profit, 0) + " pips";
    color textColor = (profit >= 0) ? clrLime : clrRed;
    int textOffset = ArrowOffsetPips + 15;
    double price = (tradeType == 2 || tradeType == 3) ? refPrice - textOffset * Point : refPrice + textOffset * Point;
    int anchor = (tradeType == 2 || tradeType == 3) ? 3 : 5;
    string name = "[MACross] Profit " + TimeToString(t);
    if(ObjectFind(name) == -1) ObjectCreate(name, OBJ_TEXT, 0, t, price);
    ObjectSetText(name, text, 8, "Arial", textColor);
    ObjectSet(name, OBJPROP_ANCHOR, anchor);
    ObjectMove(name, 0, t, price);
}

void SetLabel(string text, string val, color col, int size, int x, int y)
{
    string name = "[MACross] Dashboard " + text;
    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
        ObjectSet(name, OBJPROP_CORNER, 1); 
        ObjectSet(name, OBJPROP_ANCHOR, 6); 
    }
    ObjectSetText(name, val, size, "Arial Bold", col);
    ObjectSet(name, OBJPROP_XDISTANCE, x);
    ObjectSet(name, OBJPROP_YDISTANCE, y);
}

void DeleteDashboard()
{
    for(int i=0; i<15; i++) ObjectDelete("[MACross] Dashboard Line" + IntegerToString(i));
    ObjectDelete("[MACross] Dashboard Header");
}

void DeleteAllObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(StringFind(name, "[MACross]") == 0) ObjectDelete(name);
    }
}
