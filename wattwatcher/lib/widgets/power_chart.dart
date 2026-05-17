import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/socket_data.dart';
import '../theme.dart';

class PowerChart extends StatelessWidget {
  final List<EnergyLog> logs;

  const PowerChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No data yet',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalWatts);
    }).toList();

    final maxY = logs.map((l) => l.totalWatts).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY * 1.2 + 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.accent,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accent.withOpacity(0.12),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)}W',
                        const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
