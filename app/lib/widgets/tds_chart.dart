import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';

/// Line chart of TDS (with the alert limit as a dashed line) or temperature.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.points,
    required this.metric,
    this.limit,
    this.dark = false,
    this.height = 110,
    this.showAxis = false,
  });

  final List<HistoryPoint> points;
  final String metric; // 'tds' | 'temp'
  final double? limit;
  final bool dark;
  final double height;
  final bool showAxis;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (final p in points)
        if ((metric == 'tds' ? p.tds : p.temp) != null)
          FlSpot(p.t.millisecondsSinceEpoch.toDouble(), (metric == 'tds' ? p.tds : p.temp)!),
    ];
    if (spots.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Not enough data yet', style: TextStyle(color: dark ? AppColors.onDarkMuted : AppColors.muted)),
        ),
      );
    }
    final values = spots.map((s) => s.y).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (metric == 'tds' && limit != null && limit! > maxY) maxY = limit!;
    final double pad = ((maxY - minY).abs() * 0.15).clamp(2.0, double.infinity).toDouble();
    minY = (minY - pad).clamp(0.0, double.infinity).toDouble();
    maxY = maxY + pad;

    final lineColor = dark ? AppColors.lightBlue : AppColors.primary;
    final gridColor = dark ? const Color(0xFF2A4478) : AppColors.line;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: showAxis,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: showAxis,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showAxis,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: showAxis,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) => [
                for (final i in items)
                  LineTooltipItem(
                    '${i.y.toStringAsFixed(metric == 'tds' ? 0 : 1)} ${metric == 'tds' ? 'ppm' : '°C'}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (metric == 'tds' && limit != null)
              HorizontalLine(y: limit!, color: dark ? const Color(0xFF4A6396) : AppColors.warn, strokeWidth: 1.5, dashArray: [5, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: lineColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
