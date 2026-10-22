import 'package:flutter/material.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import 'client_detail_screen.dart';
import 'add_client_screen.dart'; // NEW
import 'package:url_launcher/url_launcher.dart'; // NEW
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // NEW

class AdminClientsTab extends StatefulWidget {
  const AdminClientsTab({super.key});

  @override
  State<AdminClientsTab> createState() => _AdminClientsTabState();
}

class _AdminClientsTabState extends State<AdminClientsTab> {
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
          // Search Field
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, business, or status...',
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
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddClientScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Client List
          Expanded(
            child: StreamBuilder<List<ClientModel>>(
              stream: ClientService().streamClients(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var clients = snapshot.data ?? [];

                // Filter Logic
                if (_searchQuery.isNotEmpty) {
                  clients = clients.where((client) {
                    final business = client.businessName.toLowerCase();
                    final owner = client.ownerName.toLowerCase();
                    
                    // Determine Status String
                    final isExpired = DateTime.now().isAfter(client.license.endDate);
                    final isActive = client.license.isActive;
                    String status = isActive 
                        ? (isExpired ? 'expired' : 'active') 
                        : 'blocked';

                    return business.contains(_searchQuery) || 
                           owner.contains(_searchQuery) ||
                           status.contains(_searchQuery);
                  }).toList();
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No clients found.' : 'No matching clients found.',
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _ClientListCard(client: client);
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



class _ClientListCard extends StatelessWidget {
  final ClientModel client;
  const _ClientListCard({required this.client});

  Future<void> _shareInvoice(BuildContext context) async {
    final phone = client.whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp number available')));
      return;
    }

    // Construct the URL
    final invoiceUrl = 'https://digibills-c97a9.web.app/#/license-invoice/${client.clientId}';
    final message = 'Dear ${client.businessName},\n\nHere is your invoice for your DigiInvi Annual Plan.\n\nView & Download: $invoiceUrl\n\nThank you for your business!';
    
    final whatsappUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = DateTime.now().isAfter(client.license.endDate);
    final isActive = client.license.isActive;
    
    Color statusColor;
    String statusText;

    if (!isActive) {
      statusColor = AppColors.error;
      statusText = 'Blocked';
    } else if (isExpired) {
      statusColor = Colors.orange;
      statusText = 'Expired';
    } else {
      statusColor = AppColors.success;
      statusText = 'Active';
    }

    // Payment Status Logic
    double totalPaid = client.advances.fold(0, (sum, item) => sum + item.amount);
    
    String payStatus = client.paymentStatus.isNotEmpty ? client.paymentStatus : 'Pending';
    Color payColor;
    
    if (payStatus == 'Paid') {
      payColor = Colors.green;
    } else if (payStatus == 'Partial') {
      payColor = Colors.orange;
    } else {
      payColor = Colors.red;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(client: client),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                client.businessName.isNotEmpty ? client.businessName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.businessName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Owner: ${client.ownerName}',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: payColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: payColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        payStatus,
                        style: TextStyle(
                          color: payColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                      onPressed: () => _shareInvoice(context),
                      tooltip: 'Share Invoice',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _confirmDelete(context, client),
                      tooltip: 'Delete Client',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client?'),
        content: Text(
          'Are you sure you want to delete "${client.businessName}"? This action cannot be undone and will remove all data associated with this client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await ClientService().deleteClient(client.clientId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Client deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting client: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
