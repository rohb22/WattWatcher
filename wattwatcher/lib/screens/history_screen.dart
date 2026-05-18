import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/watt_provider.dart';
import '../theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WattWatcherProvider>();
    final logs = provider.energyHistory;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Energy History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ─────────────────────────────────────────────────
          Row(
            children: [
              _SummaryCard(
                label: 'Total today',
                value: '${provider.kwhToday.toStringAsFixed(2)} kWh',
                icon: Icons.battery_charging_full,
                color: AppTheme.green,
              ),
              const SizedBox(width: 10),
              _SummaryCard(
                label: 'Peak load',
                value: logs.isEmpty
                    ? '—'
                    : '${logs.map((l) => l.totalWatts).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} W',
                icon: Icons.show_chart,
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Wattage chart ─────────────────────────────────────────────────
          Text(
            'POWER TREND',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: logs.length < 2
                ? Center(
                    child: Text(
                      'Not enough data yet.\nConnect to MQTT broker to start logging.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12, height: 1.6),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppTheme.border,
                          strokeWidth: 0.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}W',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 9),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < logs.length && idx % 8 == 0) {
                                final t = logs[idx].timestamp;
                                return Text(
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 9),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: logs
                              .asMap()
                              .entries
                              .map((e) =>
                                  FlSpot(e.key.toDouble(), e.value.totalWatts))
                              .toList(),
                          isCurved: true,
                          color: AppTheme.accent,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.accent.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // ── Log list ──────────────────────────────────────────────────────
          Text(
            'RECENT LOGS',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ...logs.reversed.take(20).map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Row(
                children: [
                  Text(
                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${log.totalWatts.toStringAsFixed(0)} W  ·  ${log.voltage.toStringAsFixed(0)} V  ·  ${log.current.toStringAsFixed(2)} A',
                      style: TextStyle(
                          color: AppTheme.accent, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${log.kwhToday.toStringAsFixed(3)} kWh',
                    style: TextStyle(color: AppTheme.green, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                Text(label,
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
