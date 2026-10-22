import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../services/usage_stats_service.dart';

class UsageMeterCard extends StatelessWidget {
  final UsageStats stats;
  
  const UsageMeterCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Colors based on Status
    Color statusColor = AppColors.success;
    IconData statusIcon = Icons.check_circle;
    String statusText = 'SAFE';

    if (stats.status == 'CRITICAL') {
      statusColor = AppColors.error;
      statusIcon = Icons.warning_rounded;
      statusText = 'CRITICAL';
    } else if (stats.status == 'WARNING') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'WARNING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
             color: statusColor.withOpacity(0.1),
             blurRadius: 12,
             offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                   Icon(Icons.speed, color: AppColors.textDark),
                   SizedBox(width: 8),
                   Text('Usage Meter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          // METERS
          _buildMeterRow(
            context, 
            'Estimated Reads', 
            stats.estimatedReads, 
            stats.limitReads, 
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildMeterRow(
            context, 
            'Estimated Writes', 
            stats.estimatedWrites, 
            stats.limitWrites, 
            Colors.purple,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // RAW STATS
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceAround,
             children: [
                _buildMiniStat('Bills', stats.billsCount.toString()),
                _buildMiniStat('Expenses', stats.expensesCount.toString()),
                _buildMiniStat('Notifications', stats.notificationsCount.toString()),
             ],
          ),

          const SizedBox(height: 16),
          // DISCLAIMER
          Center(
            child: Text(
              'Usage values are estimated based on application activity and are intended for monitoring purposes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterRow(BuildContext context, String label, int value, int limit, Color color) {
    double percent = value / limit;
    if (percent > 1.0) percent = 1.0;
    
    // Formatting numbers with K/M
    String formatNumber(int num) {
      if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
      if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
      return num.toString();
    }
    
    Color barColor = color;
    if (percent > 0.8) barColor = AppColors.error;
    else if (percent > 0.6) barColor = Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
             Text('${formatNumber(value)} / ${formatNumber(limit)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[200],
            color: barColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
         Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
         Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ],
    );
  }
}
