# MA Cross Signals Analyzer

Professional Moving Average Crossover indicator for MetaTrader 4 that provides not only signal arrows but a comprehensive performance breakdown.

## Features

- **Dual Moving Averages**: Customizable Fast and Slow MA periods (SMA, EMA, etc.).
- **Signal Bullets**: Automatic Buy (Green) and Sell (Red) bullets plotted at crossover points.
- **Signals Analyzer Dashboard**: Real-time display of closed, open, and total net profit in pips, with Win Rate percentage and RR Ratio.
- **Risk Analyzer**: Simulate 'Virtual Balance' and 'Lot Size' (including **Dynamic Compounding** mode) to track Account Balance and Maximum Drawdown (Money & %) historically directly on the chart.
- **HTF Filtering**: Option to filter current timeframe signals by the trend of a Higher Timeframe (e.g., only buy on M15 if H4 trend is up).
- **ADR Filter**: Option to filter trades based on remaining Average Daily Range (Upsize/Downsize %) to avoid buying at the top or selling at the bottom.
- **Trading History Statistics**: View record Winning/Losing Streaks (count and total pips) and biggest individual trade win/loss.
- **On-Chart Performance Labels**: Historical trade profit displayed directly near signal arrows for easy verification and backtesting.
- **Efficient Calculation**: Optimized to process only new data on each tick and simulate historical "trades".
- **Clean Cleanup**: Automatically removes all chart objects when the indicator is removed.

## Installation

1. Open your MetaTrader 4 terminal.
2. Go to `File` > `Open Data Folder`.
3. Navigate to `MQL4/Indicators`.
4. Create a folder named `MACross` and copy the `MACross.mq4` file into it.
5. Restart MetaTrader 4 or right-click `Indicators` in the Navigator and select `Refresh`.

## Parameters

- **Fast MA**: Period, Method, Applied Price, Color, Size.
- **Slow MA**: Period, Method, Applied Price, Color, Size.
- **Signals**: Buy/Sell Arrow Colors, Arrow Size, Arrow Offset (Pips).
- **Dashboard**: Toggle Visibility, X/Y Margins, Font Size.

## License

[MIT License](LICENSE)
