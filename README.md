# MACross

Professional 2 Moving Average Crossover indicator with signal arrows on chart.

## Features

- **Dual Moving Averages**: Customizable Fast and Slow MA periods (SMA, EMA, etc.).
- **Signal Arrows**: Automatic Buy (Up) and Sell (Down) arrows plotted at crossover points.
- **Visual Customization**: Individual color and size settings for both MA lines and signal arrows.
- **Status Dashboard**: An on-chart label and comment showing the current MA status and distance in pips.
- **Efficient Calculation**: Optimized to process only new data on each tick.
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

## License

[MIT License](LICENSE)
