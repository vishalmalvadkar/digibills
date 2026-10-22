import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../theme/app_colors.dart';

class ClientAcquisitionLineChart extends StatefulWidget {
  final List<ClientModel> clients;

  const ClientAcquisitionLineChart({super.key, required this.clients});

  @override
  State<ClientAcquisitionLineChart> createState() => _ClientAcquisitionLineChartState();
}

class _ClientAcquisitionLineChartState extends State<ClientAcquisitionLineChart> {
  String _filter = 'Month'; // Day, Month, Year

  @override
  Widget build(BuildContext context) {
    if (widget.clients.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Client Acquisition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Segmented Control / Filters
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ['Day', 'Month', 'Year'].map((f) {
                    final isSelected = _filter == f;
                    return InkWell(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textGrey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          AspectRatio(
            aspectRatio: 1.8,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = _generateSpots();
    if (spots.isEmpty) return const Center(child: Text("No data for selected period"));

    // Find Max Y for scaling
    double maxY = 0;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding
    if (maxY == 0) maxY = 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1, // We control interval via mapping
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index >= 0 && index < _labels.length) {
                  // Show roughly 5-6 labels to avoid crowding
                  int step = (_labels.length / 6).ceil();
                  if (step < 1) step = 1;
                  
                  if (index % step == 0) {
                     return Padding(
                       padding: const EdgeInsets.only(top: 8),
                       child: Text(_labels[index], style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                     );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxY > 5 ? maxY / 5 : 1,
              getTitlesWidget: (value, meta) {
                 if (value == 0) return const SizedBox.shrink(); 
                 return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                 final index = spot.x.toInt();
                 final label = index >= 0 && index < _labels.length ? _labels[index] : '';
                 return LineTooltipItem(
                   '$label\n',
                   const TextStyle(color: Colors.white70, fontSize: 10),
                   children: [
                     TextSpan(text: '${spot.y.toInt()} Clients', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                   ],
                 );
              }).toList();
            },
          ),
        )
      ),
    );
  }

  // To store labels relative to spots indices
  List<String> _labels = [];

  List<FlSpot> _generateSpots() {
    _labels = [];
    final now = DateTime.now();
    final Map<int, int> dataMap = {};
    int count = 0;

    if (_filter == 'Day') {
      // Last 14 Days
      count = 14;
      for (int i = 0; i < count; i++) {
        final d = now.subtract(Duration(days: count - 1 - i));
        _labels.add(DateFormat('d MMM').format(d));
        dataMap[i] = 0;
        
        // Count clients for this day
        // Optimization: Filter list once? No, easy to iterate.
        // Assuming client list is not massive (<10000). 
        for (var c in widget.clients) {
          if (isSameDay(c.createdAt, d)) {
            dataMap[i] = (dataMap[i] ?? 0) + 1;
          }
        }
      }
    } else if (_filter == 'Month') {
      // Last 12 Months
      count = 12;
      for (int i = 0; i < count; i++) {
        final d = DateTime(now.year, now.month - (count - 1 - i), 1);
        _labels.add(DateFormat('MMM yy').format(d));
        dataMap[i] = 0;
        
        for (var c in widget.clients) {
            if (c.createdAt.year == d.year && c.createdAt.month == d.month) {
               dataMap[i] = (dataMap[i] ?? 0) + 1;
            }
        }
      }
    } else {
      // Year (Show last 5 years)
      count = 5;
      for (int i = 0; i < count; i++) {
        final y = now.year - (count - 1 - i);
        _labels.add(y.toString());
        dataMap[i] = 0;
        
        for (var c in widget.clients) {
            if (c.createdAt.year == y) {
               dataMap[i] = (dataMap[i] ?? 0) + 1;
            }
        }
      }
    }

    // Convert map to spots
    List<FlSpot> spots = [];
    for (int i = 0; i < count; i++) {
      spots.add(FlSpot(i.toDouble(), (dataMap[i] ?? 0).toDouble()));
    }
    return spots;
  }
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
