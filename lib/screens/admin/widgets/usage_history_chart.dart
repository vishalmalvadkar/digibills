import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/usage_stats_service.dart';
import '../../../theme/app_colors.dart';

class UsageHistoryChart extends StatelessWidget {
  final List<UsageDataPoint> points;
  final UsageTimeRange range;

  final bool embed; // New parameter to strip container

  const UsageHistoryChart({super.key, required this.points, required this.range, this.embed = false});

  @override
  Widget build(BuildContext context) {
    if (range == UsageTimeRange.daily) return const SizedBox.shrink();

    final chartContent = AspectRatio(
      aspectRatio: 1.5,
      child: range == UsageTimeRange.monthly
          ? _buildLineChart(points)
          : _buildBarChart(points),
    );

    if (embed) {
      return chartContent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
           BoxShadow(
             color: Colors.black12,
             blurRadius: 10,
             offset: Offset(0, 4),
           )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            range == UsageTimeRange.monthly ? 'Daily Interactions' : 'Monthly Interactions',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          chartContent,
        ],
      ),
    );
  }

  Widget _buildLineChart(List<UsageDataPoint> points) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < points.length && index % 2 == 0) {
                     return Text(points[index].label, style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
               return Text(compactNumber(value), style: const TextStyle(fontSize: 10));
            }),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.reads.toDouble())).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.writes.toDouble())).toList(),
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<UsageDataPoint> points) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // tooltipBgColor: Colors.blueGrey, // Use getTooltipColor if available in newer fl_chart, or fallback
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                 int index = value.toInt();
                 if (index >= 0 && index < points.length) {
                    return Text(points[index].label, style: const TextStyle(fontSize: 10));
                 }
                 return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
               return Text(compactNumber(value), style: const TextStyle(fontSize: 10));
            }),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: points.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.reads.toDouble(),
                color: Colors.blue,
                width: 8,
              ),
              BarChartRodData(
                toY: e.value.writes.toDouble(),
                color: Colors.purple,
                width: 8,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  String compactNumber(double value) {
    if (value >= 1000000) return '${(value/1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value/1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}
