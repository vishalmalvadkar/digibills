import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../theme/app_colors.dart';

class PaymentStatusChart extends StatelessWidget {
  final List<ClientModel> clients;

  const PaymentStatusChart({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Data
    int paid = clients.where((c) => c.paymentStatus == 'Paid').length;
    int partial = clients.where((c) => c.paymentStatus == 'Partial').length;
    int pending = clients.where((c) => c.paymentStatus == 'Pending').length;
    
    // Handle case where status might be empty (legacy) -> count as Pending
    pending += clients.where((c) => c.paymentStatus.isEmpty).length;

    final total = paid + partial + pending;
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
          const Text(
            'Payment Status Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Chart
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: AppColors.success,
                          value: paid.toDouble(),
                          title: '${((paid/total)*100).toStringAsFixed(1)}%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.orange,
                          value: partial.toDouble(),
                          title: '${((partial/total)*100).toStringAsFixed(1)}%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: AppColors.error,
                          value: pending.toDouble(),
                          title: '${((pending/total)*100).toStringAsFixed(1)}%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Legend
                const SizedBox(width: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Indicator(color: AppColors.success, text: 'Paid ($paid)'),
                    const SizedBox(height: 8),
                    _Indicator(color: Colors.orange, text: 'Partial ($partial)'),
                    const SizedBox(height: 8),
                    _Indicator(color: AppColors.error, text: 'Pending ($pending)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGrey)),
      ],
    );
  }
}
