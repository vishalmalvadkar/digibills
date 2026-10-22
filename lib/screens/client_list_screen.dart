import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/client_model.dart';
import '../models/bill_model.dart';
import '../models/license_model.dart';
import '../services/client_service.dart';
import '../services/bills_service.dart';
import '../theme/app_colors.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Stream<List<ClientModel>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _combinedStream = _getCombinedClients();
  }
  
  Stream<List<ClientModel>> _getCombinedClients() {
    final controller = StreamController<List<ClientModel>>();
    
    StreamSubscription? clientSub;
    StreamSubscription? billsSub;
    
    List<ClientModel> registeredClients = [];
    List<BillModel> allBills = [];
    
    void emit() {
       if (controller.isClosed) return;

       final Map<String, ClientModel> uniqueClients = {};
       
       // 1. Add Registered Clients
       for (var client in registeredClients) {
          uniqueClients[client.clientId] = client;
       }
       
       // 2. Add Ad-hoc Customers from Bills
       final List<ClientModel> virtualClients = [];
       final Set<String> processedNames = {};

       // Normalize registered names for comparison
       final Set<String> registeredNames = registeredClients.map((c) => c.businessName.trim().toLowerCase()).toSet();
       final Set<String> registeredIds = registeredClients.map((c) => c.clientId).toSet();
       
       for (var bill in allBills) {
          // Skip if linked to a known ID
          if (bill.clientId.isNotEmpty && registeredIds.contains(bill.clientId)) continue;
          
          final billName = bill.customerName.trim();
          final lowerName = billName.toLowerCase();
          
          if (billName.isEmpty) continue;
          if (registeredNames.contains(lowerName)) continue;
          if (processedNames.contains(lowerName)) continue; // Already added as virtual

          // Add to processing set
          processedNames.add(lowerName);

          // Create virtual client
          virtualClients.add(ClientModel(
               clientId: '', // No ID for ad-hoc
               businessName: billName,
               ownerName: '',
               email: '',
               whatsappNumber: bill.whatsappNumber,
               tenantId: '',
               state: bill.clientAddress,
               gstNumber: bill.gstNumber ?? '',
               license: LicenseModel(isActive: true, plan: 'basic', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 3650))), 
               status: 'Active',
               createdAt: bill.createdAt,
               mouAccepted: false,
               amount: 0, 
               paymentMode: '',
               paymentStatus: '',
               taxPercentage: 0,
               advances: []
          ));
       }
       
       final List<ClientModel> result = [...registeredClients, ...virtualClients];
       
       // Filter out self
       final currentUserId = Supabase.instance.client.auth.currentUser?.id;
       if (currentUserId != null) {
          result.removeWhere((c) => c.clientId == currentUserId);
       }
       
       if (!controller.isClosed) controller.add(result);
    }
    
    controller.onCancel = () {
      clientSub?.cancel();
      billsSub?.cancel();
      controller.close();
    };

    // Subscribe
    clientSub = ClientService().streamClients().listen((data) {
       registeredClients = data;
       emit();
    });
    
    billsSub = BillsService().streamBills().listen((data) {
       allBills = data;
       emit();
    });
    
    return controller.stream;
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.selectClient ?? 'Select Client'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.searchClientPlaceholder ?? 'Search Client Name',
                prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                filled: true,
                fillColor: Colors.white,
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
              stream: _combinedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)?.noClientsFound ?? 'No clients found.'));
                }

                var clients = snapshot.data!;
                
                // Filter by Search Query
                if (_searchQuery.isNotEmpty) {
                  clients = clients.where((client) {
                    final name = client.businessName.toLowerCase();
                    final owner = client.ownerName.toLowerCase();
                    return name.contains(_searchQuery) || owner.contains(_searchQuery);
                  }).toList();
                }

                // Sort by Name
                clients.sort((a, b) => a.businessName.compareTo(b.businessName));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _clientCard(context, client);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientCard(BuildContext context, ClientModel client) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(
              clientId: client.clientId,
              clientName: client.businessName,
              clientAddress: client.state.isNotEmpty ? client.state : client.email,
              ownerName: client.ownerName, // Pass owner name for better matching
            ),
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
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 4),
                  if (client.ownerName.isNotEmpty)
                    Text(
                      client.ownerName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }
}
