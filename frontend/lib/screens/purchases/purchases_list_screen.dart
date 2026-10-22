import 'package:flutter/material.dart';
import '../../models/purchase_model.dart';
import '../../services/purchase_service.dart';
import '../../theme/app_colors.dart';
import 'create_purchase_screen.dart';
import 'purchase_view_screen.dart';
import 'package:intl/intl.dart';

class PurchasesListScreen extends StatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  final PurchasesService _purchasesService = PurchasesService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: AppColors.background,
        child: FutureBuilder<List<PurchaseModel>>(
          future: _purchasesService.getPurchases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
  
            final purchases = snapshot.data ?? [];
            
            if (purchases.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No Purchases Yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _navigateToCreate(),
                      child: const Text('Add Your First Purchase'),
                    ),
                  ],
                ),
              );
            }
  
            // Group purchases by month/year
            final groupedPurchases = <String, List<PurchaseModel>>{};
            final now = DateTime.now();
            final currentMonthKey = DateFormat('MMMM yyyy').format(now);
  
            for (var purchase in purchases) {
              final key = DateFormat('MMMM yyyy').format(purchase.date);
              groupedPurchases.putIfAbsent(key, () => []).add(purchase);
            }
  
            final sortedKeys = groupedPurchases.keys.toList();
  
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final key = sortedKeys[index];
                    final monthPurchases = groupedPurchases[key]!;
                    final monthTotal = monthPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
                    final isCurrentMonth = key == currentMonthKey;
  
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isCurrentMonth,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                key,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '₹${monthTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
                          children: monthPurchases.map((purchase) => _buildPurchaseCard(purchase)).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _navigateToCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePurchaseScreen()),
    );
    setState(() {}); // Refresh list
  }

  Widget _buildPurchaseCard(PurchaseModel purchase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withAlpha(127)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                purchase.supplierName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₹${purchase.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Inv: ${purchase.invoiceNumber ?? "N/A"} • ${DateFormat('dd MMM yyyy').format(purchase.date)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('${purchase.city ?? ""}, ${purchase.state ?? ""}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseViewScreen(purchaseId: purchase.purchaseId),
            ),
          );
          if (result == true) setState(() {}); // Refresh if deleted
        },
      ),
    );
  }
}
