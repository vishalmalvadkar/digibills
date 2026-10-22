import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import 'client_detail_screen.dart'; // Same directory, so single import is fine if in same dir? No, 'client_detail_screen.dart' is in 'admin'.
// Wait, client_list_screen and client_detail_screen are BOTH in lib/screens/admin.
// So importing 'client_detail_screen.dart' directly is correct.
import '../../widgets/license_scope.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Clients'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1)),
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<ClientModel>>(
        stream: ClientService().streamClients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No clients found.'));
          }

          final clients = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clients.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final client = clients[index];
              return _ClientCard(client: client);
            },
          );
        },
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  const _ClientCard({required this.client});

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
                client.businessName[0].toUpperCase(),
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
                    client.email.isNotEmpty ? client.email : 'No Email',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
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
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
