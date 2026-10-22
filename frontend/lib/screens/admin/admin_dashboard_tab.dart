import 'package:flutter/material.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/payment_status_chart.dart';
import '../../widgets/client_acquisition_line_chart.dart'; 
import 'widgets/usage_quotas_card.dart'; // NEW
import 'widgets/super_admin_analytics.dart'; // NEW


class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  @override
  void initState() {
    super.initState();
    // Healing logic: Recover missing states for analytics in the background
    ClientService().syncMissingStates();
  }

  // All usage state logic moved to UsageQuotasCard
  // This keeps the Dashboard lightweight and prevents scroll jumps

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<ClientModel>>(
            stream: ClientService().streamClients(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final clients = snapshot.data ?? [];
              
              // Calculate Stats
              final total = clients.length;
              final active = clients.where((c) => c.license.isActive && DateTime.now().isBefore(c.license.endDate)).length;
              final expired = clients.where((c) => c.license.isActive && DateTime.now().isAfter(c.license.endDate)).length;
              final blocked = clients.where((c) => !c.license.isActive).length;
              
              // Calculate Revenue (Total collected from all clients)
              final double totalRevenue = clients.fold(0.0, (sum, client) {
                if (client.paymentStatus == 'Paid') {
                  return sum + (client.amount + (client.amount * client.taxPercentage / 100));
                } else {
                  return sum + client.advances.fold(0.0, (s, p) => s + p.amount);
                }
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue Card (Full Width)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Revenue Collected', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _InfoCard(
                        title: 'Total Clients',
                        value: total.toString(),
                        color: Colors.blue,
                        icon: Icons.people,
                      ),
                      _InfoCard(
                        title: 'Active Licenses',
                        value: active.toString(),
                        color: AppColors.success,
                        icon: Icons.check_circle,
                      ),
                      _InfoCard(
                        title: 'Expired Licenses',
                        value: expired.toString(),
                        color: Colors.orange,
                        icon: Icons.history,
                      ),
                      _InfoCard(
                        title: 'Blocked Clients',
                        value: blocked.toString(),
                        color: AppColors.error,
                        icon: Icons.block,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const SizedBox(height: 24),

                  // LICENSE REQUESTS SECTION (REPLACED REVENUE TREND)
                  const LicenseRequestsCard(),
                  const SizedBox(height: 16),
                  ChurnAnalysisCard(clients: clients),
                  const SizedBox(height: 16),
                  StateAdoptionCard(clients: clients),
                  const SizedBox(height: 16),
                  PowerUsersList(clients: clients),
                  const SizedBox(height: 24),
                  
                  // Analytics Section (Legacy Status Charts)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: PaymentStatusChart(clients: clients)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ClientAcquisitionLineChart(clients: clients),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // USAGE STATS SECTION (Now Isolated)
                  const UsageQuotasCard(),
                    
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Unused methods removed
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Subtle shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
