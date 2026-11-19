import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/status_stat.dart';
import '../../../domain/models/trend_point.dart';

const _statusColors = {
  ComplaintStatus.pending: Color(0xFFE0A100),
  ComplaintStatus.inProgress: Color(0xFF2F62E0),
  ComplaintStatus.resolved: Color(0xFF2E9E57),
  ComplaintStatus.rejected: Color(0xFFD14343),
};

final class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

/// Donut chart of complaints per status, with a legend.
final class StatusDonutChart extends StatelessWidget {
  const StatusDonutChart({super.key, required this.stats});
  final List<StatusStat> stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.fold<int>(0, (sum, item) => sum + item.count);
    return _ChartCard(
      title: 'Complaints by status',
      child: total == 0
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No complaints to display yet.'),
            )
          : Semantics(
              label: [
                for (final item in stats) '${item.status.label} ${item.count}',
              ].join(', '),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 40,
                        sectionsSpace: 3,
                        sections: [
                          for (final item in stats)
                            if (item.count > 0)
                              PieChartSectionData(
                                value: item.count.toDouble(),
                                color: _statusColors[item.status],
                                radius: 28,
                                showTitle: false,
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in stats)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _statusColors[item.status],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.status.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.count}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Line chart of complaints created per day.
final class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxY = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    return _ChartCard(
      title: 'Complaints over the last ${points.length} days',
      child: points.isEmpty || maxY == 0
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No recent complaints.'),
            )
          : Semantics(
              label:
                  'Line chart of complaints per day, peak $maxY in a single day',
              child: SizedBox(
                height: 170,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: (maxY + 1).toDouble(),
                    gridData: const FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: maxY > 6 ? (maxY / 4).ceilToDouble() : 1,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (points.length / 4).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final d = points[i].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${d.day}/${d.month}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].count.toDouble()),
                        ],
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: .12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
