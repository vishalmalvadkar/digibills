import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/purchase_order_model.dart';
import '../../services/purchase_order_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/license_scope.dart';
import 'create_po_screen.dart';
import 'po_view_screen.dart'; // Will create next
import '../../utils/pdf_po_helper.dart';

import '../../models/user_model.dart'; // NEW
import '../mou_screen.dart'; // NEW

class POListScreen extends StatefulWidget {
  final UserModel? user; // NEW
  final VoidCallback? onRefresh;
  final String searchQuery; // NEW
  const POListScreen({super.key, this.user, this.onRefresh, this.searchQuery = ''});


  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  void _checkMou(VoidCallback onAllowed) async {
    if (widget.user != null && !widget.user!.mouAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept Terms & Conditions'),
          content: const Text('You must read and sign the MOU & Terms before creating purchase orders.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('Review & Sign'),
            ),
          ],
        ),
      );

      if (accepted == true && mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const MouScreen()),
        );
        if (result == true && widget.onRefresh != null) {
          widget.onRefresh!();
        }
      }
    } else {
      onAllowed();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to blend with tab bg
      body: StreamBuilder<List<PurchaseOrderModel>>(
        stream: PurchaseOrderService().getPOsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final pos = snapshot.data!.where((po) {
            final query = widget.searchQuery.toLowerCase();
            return po.vendorName.toLowerCase().contains(query) ||
                   po.poNumber.toLowerCase().contains(query) ||
                   po.totalAmount.toStringAsFixed(0).contains(query);
          }).toList();

          if (pos.isEmpty) return _buildEmptyState();

          // Group POs by month/year
          final groupedPOs = <String, List<PurchaseOrderModel>>{};
          final now = DateTime.now();
          final currentMonthKey = DateFormat('MMMM yyyy').format(now);

          for (var po in pos) {
            final key = DateFormat('MMMM yyyy').format(po.date);
            groupedPOs.putIfAbsent(key, () => []).add(po);
          }

          final sortedKeys = groupedPOs.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final monthPOs = groupedPOs[key]!;
              final monthTotal = monthPOs.fold(0.0, (sum, po) => sum + po.totalAmount);
              final isCurrentMonth = key == currentMonthKey;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
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
                    children: monthPOs.map((po) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPOCard(context, po),
                    )).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: LicenseScope.isReadOnlyMode(context) ? null : FloatingActionButton(
        heroTag: 'add_po',
        onPressed: () {
           _checkMou(() {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePOScreen()));
           });
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
           const SizedBox(height: 16),
           Text('No Purchase Orders Yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
         ],
       ),
     );
  }

  Widget _buildPOCard(BuildContext context, PurchaseOrderModel po) {
    Color statusColor = Colors.grey;
    if (po.status == 'Sent') statusColor = Colors.blue;
    if (po.status == 'Received') statusColor = Colors.green;
    if (po.status == 'Cancelled') statusColor = Colors.red;

    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => POViewScreen(po: po)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(po.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(po.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 Text('₹${po.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Expected: ${DateFormat('dd MMM').format(po.expectedDeliveryDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => PdfPOHelper.openWhatsApp(context, po),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
