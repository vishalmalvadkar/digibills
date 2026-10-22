import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../client_detail_screen.dart';
import '../../../services/client_service.dart';
import 'package:intl/intl.dart';
import '../../../models/client_model.dart';
import '../../../theme/app_colors.dart';

/// 1. Monthly Recurring Revenue (MRR) Trend
class RevenueTrendChart extends StatelessWidget {
  final List<ClientModel> clients;
  const RevenueTrendChart({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    final spots = _generateSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = (maxY * 1.25).ceilToDouble();
    if (maxY == 0) maxY = 10000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      'Revenue Growth Trend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Subscription collections by month',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 32),
          AspectRatio(
            aspectRatio: 1.8,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _labels.length) {
                          if (_labels.length > 6 && index % 2 != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_labels[index], style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        if (value >= 1000) return Text('${(value/1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
                        return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeColor: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '₹${spot.y.toInt()}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _labels = [];
  List<FlSpot> _generateSpots() {
    _labels = [];
    final now = DateTime.now();
    final Map<String, double> dataMap = {};
    
    // Last 6 months
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM yy').format(d);
      _labels.add(key);
      dataMap[key] = 0;
      
      for (var c in clients) {
        if (c.license.startDate.year == d.year && c.license.startDate.month == d.month) {
          dataMap[key] = (dataMap[key] ?? 0) + c.amount;
        }
      }
    }

    return List.generate(_labels.length, (i) {
      return FlSpot(i.toDouble(), dataMap[_labels[i]] ?? 0);
    });
  }
}

/// 2. Retention & Churn Analysis
class ChurnAnalysisCard extends StatelessWidget {
  final List<ClientModel> clients;
  const ChurnAnalysisCard({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = clients.where((c) => c.license.isActive && now.isBefore(c.license.endDate)).length;
    final expired = clients.where((c) => c.license.isActive && now.isAfter(c.license.endDate)).length;
    final blocked = clients.where((c) => !c.license.isActive).length;
    final total = clients.length;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Retention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(color: AppColors.success, value: active.toDouble(), title: '', radius: 30),
                        PieChartSectionData(color: Colors.orange, value: expired.toDouble(), title: '', radius: 30),
                        PieChartSectionData(color: AppColors.error, value: blocked.toDouble(), title: '', radius: 30),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatRow(label: 'Healthy', value: active, total: total, color: AppColors.success),
                    const Divider(height: 16),
                    _StatRow(label: 'At Risk (Expired)', value: expired, total: total, color: Colors.orange),
                    const Divider(height: 16),
                    _StatRow(label: 'Churned (Blocked)', value: blocked, total: total, color: AppColors.error),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _StatRow({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = (value / total * 100).toStringAsFixed(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
        Text('$percent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 3. State-wise Adoption
class StateAdoptionCard extends StatelessWidget {
  final List<ClientModel> clients;
  const StateAdoptionCard({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> stateCounts = {};
    for (var c in clients) {
      final s = c.state.isEmpty ? 'Unknown' : c.state;
      stateCounts[s] = (stateCounts[s] ?? 0) + 1;
    }

    final sortedEntries = stateCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedEntries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Performing States', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...top5.map((e) {
            final progress = e.value / clients.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      Text('${e.value} Clients', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.background,
                      color: AppColors.primary,
                      minHeight: 6,
                    ),
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

/// 4. Power User Leaderboard (Top Businesses)
class PowerUsersList extends StatelessWidget {
  final List<ClientModel> clients;
  const PowerUsersList({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    // Calculate total life-time value for each client
    final List<Map<String, dynamic>> leaderBoard = clients.map((c) {
      double totalContribution = c.amount;
      totalContribution += c.advances.fold(0.0, (sum, adv) => sum + adv.amount);
      
      return {
        'name': c.businessName,
        'owner': c.ownerName,
        'value': totalContribution,
        'plan': c.license.plan.toUpperCase(),
      };
    }).toList();

    // Sort by value
    leaderBoard.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    final top5 = leaderBoard.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text('Top Business Partners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               Icon(Icons.star, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          ...top5.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(data['owner'], style: const TextStyle(color: AppColors.textGrey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${(data['value'] as double).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text(data['plan'], style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ],
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

/// 5. Pending License Renewal Requests
class LicenseRequestsCard extends StatelessWidget {
  const LicenseRequestsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License Renewal Requests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Clients waiting for renewal',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.autorenew, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('tenant_id', 'superadmin')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter for renewal_requests manually since stream only supports one filter
              final allNotifications = snapshot.data ?? [];
              final requests = allNotifications.where((n) => n['type'] == 'renewal_request').toList();
              if (requests.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'All caught up!',
                        style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'No pending renewal requests.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: requests.take(5).map((data) {
                  final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
                  final dt = (DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal();
                  final timeStr = DateFormat('MMM d, h:mm a').format(dt);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metadata['name'] ?? 'Unknown User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                              onPressed: () => _navigateToEdit(context, metadata['uid'], notificationId: data['id']),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.phone_android, size: 14, color: AppColors.textGrey),
                            const SizedBox(width: 8),
                            Text(metadata['whatsapp'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => _navigateToEdit(context, metadata['uid'], notificationId: data['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Renew', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEdit(BuildContext context, String? uid, {String? notificationId}) async {
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = await ClientService().getClient(uid);
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        if (client != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(client: client, notificationId: notificationId),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client record not found')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
