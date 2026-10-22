import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';
import '../../models/license_model.dart';
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import 'license_invoice_screen.dart'; // NEW

class AdminLicensesTab extends StatefulWidget {
  const AdminLicensesTab({super.key});

  @override
  State<AdminLicensesTab> createState() => _AdminLicensesTabState();
}

class _AdminLicensesTabState extends State<AdminLicensesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search licenses...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ClientModel>>(
              stream: ClientService().streamClients(),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var clients = snapshot.data ?? [];
                
                // Filter Logic
                if (_searchQuery.isNotEmpty) {
                  clients = clients.where((c) {
                    final business = c.businessName.toLowerCase();
                    final owner = c.ownerName.toLowerCase();
                    
                    final now = DateTime.now();
                    final end = c.license.endDate;
                    final daysLeft = end.difference(now).inDays;
                    
                    String statusText = '';
                    if (!c.license.isActive) statusText = 'blocked';
                    else if (daysLeft < 0) statusText = 'expired';
                    else if (daysLeft < 30) statusText = 'expiring';
                    else statusText = 'active';

                    return business.contains(_searchQuery) ||
                           owner.contains(_searchQuery) ||
                           statusText.contains(_searchQuery);
                  }).toList();
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No licenses found.' : 'No matching licenses found.',
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  );
                }

                // Sort by expiration date (soonest first)
                clients.sort((a, b) => a.license.endDate.compareTo(b.license.endDate));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _LicenseCard(client: client);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final ClientModel client;
  const _LicenseCard({required this.client});

  void _renew(BuildContext context) {
     // Quick renew for 1 year
     final newLicense = LicenseModel(
       isActive: true,
       plan: client.license.plan,
       startDate: DateTime.now(),
       endDate: DateTime.now().add(const Duration(days: 365)),
     );

     ClientService().updateClient(
       clientId: client.clientId, 
       businessName: client.businessName, 
       ownerName: client.ownerName, 
       email: client.email, 
       whatsappNumber: client.whatsappNumber, 
       license: newLicense,
       state: client.state,
       gstNumber: client.gstNumber,
     );

     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renewed ${client.businessName} for 1 year')));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = client.license.endDate;
    final daysLeft = end.difference(now).inDays;
    
    Color statusColor;
    String statusText;

    if (!client.license.isActive) {
      statusColor = AppColors.error;
      statusText = 'Blocked';
    } else if (daysLeft < 0) {
      statusColor = AppColors.error;
      statusText = 'Expired';
    } else if (daysLeft < 30) {
      statusColor = Colors.orange;
      statusText = 'Expiring Soon ($daysLeft days)';
    } else {
      statusColor = AppColors.success;
      statusText = 'Active ($daysLeft days)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                client.businessName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date', style: TextStyle(color: AppColors.textGrey, fontSize: 10)),
                    Text(DateFormat('dd MMM yyyy').format(client.license.startDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('End Date', style: TextStyle(color: AppColors.textGrey, fontSize: 10)),
                    Text(DateFormat('dd MMM yyyy').format(client.license.endDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _renew(context),
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Renew 1 Yr'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (_) => LicenseInvoiceScreen(clientId: client.clientId),
                         ),
                       );
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textDark,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
