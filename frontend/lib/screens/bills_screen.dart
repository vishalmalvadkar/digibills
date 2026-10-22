import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../services/bills_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

import '../utils/snackbar_helper.dart';
import '../theme/app_colors.dart';
import '../widgets/license_scope.dart';
import 'bill_view_screen.dart';
import '../utils/pdf_invoice_helper.dart';
import 'create_bill_screen.dart';
import 'quotes_list_screen.dart'; // RESTORED
import 'purchases/purchases_list_screen.dart';
import 'mou_screen.dart'; // NEW
import 'sales_return_list_screen.dart'; // NEW
import '../utils/responsive.dart';
import '../core/responsive/breakpoints.dart';
import '../core/responsive/max_width_container.dart';
import '../l10n/app_localizations.dart'; // NEW
import 'reports/supplier_bills_screen.dart';

class BillsScreen extends StatefulWidget {
  final int initialIndex; // NEW
  final String? initialFilterStatus; // NEW

  const BillsScreen({super.key, this.initialIndex = 0, this.initialFilterStatus});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final BillsService _billsService = BillsService();
  Stream<List<BillModel>>? _billsStream; // Stream is back
  UserModel? _currentUser;
  bool _loadingUser = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = AuthService().currentUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final user = await UserService().getUser(uid);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _initBillsStream(uid); // Initialize Stream
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _billsStream = _billsService.streamBills();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user in BillsScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingUser = false);
      }
    }
  }

  // Helper to initialize or reset stream
  void _initBillsStream(String uid) {
    if (_currentUser?.role == 'client') {
      _billsStream = _billsService.streamUserRelevantBills(uid);
    } else if (_currentUser?.role == 'staff') {
      _billsStream = _billsService.streamBills(staffId: uid);
    } else {
      _billsStream = _billsService.streamBills();
    }
  }

  // Method to handle Pull-to-Refresh
  Future<void> _handleRefresh() async {
    final uid = AuthService().currentUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      // 1. Reload User Data
      await _loadUser(); 
      // 2. Re-initialize Stream (force reconnect)
      setState(() {
         _initBillsStream(uid);
      });
      // A small delay to let the stream reconnect visually
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
     if (_loadingUser) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 4, 
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            if (!Responsive.isDesktop(context))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: BackButton(color: AppColors.textDark),
                          ),
                        Text(
                          AppLocalizations.of(context)?.transactions ?? 'Transactions',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.manageBillsInvoices ?? 'Manage your bills and invoices',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),

            // Global Search Bar below the bordered header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)?.searchPlaceholder ?? 'Search by Name, Invoice, Amount...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textGrey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),


            // Modern Scrollable TabBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textGrey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.grey.shade200,
                indicatorSize: TabBarIndicatorSize.label,
                padding: EdgeInsets.zero,
                tabs: [
                   Tab(text: AppLocalizations.of(context)?.invoices ?? 'Invoices'),
                  Tab(text: AppLocalizations.of(context)?.quotations ?? 'Quotations'),
                  Tab(text: AppLocalizations.of(context)?.purchaseOrders ?? 'Purchases'),
                  Tab(text: AppLocalizations.of(context)?.returns ?? 'Returns'),
                ],
              ),
            ),

            
            // TabBarView
            Expanded(
              child: MaxWidthContainer(
                maxWidth: 1200,
                padding: EdgeInsets.zero,
                child: TabBarView(
                  children: [
                    InvoicesListTab(
                      billsStream: _billsStream, // Pass Stream
                      user: _currentUser,
                    onRefresh: _handleRefresh, // Pass Refresh Handler
                    searchQuery: _searchQuery, // NEW: Pass search query
                    filterStatus: widget.initialFilterStatus, // NEW
                  ), 
                  
                  QuotesListScreen(
                    user: _currentUser,
                    onRefresh: _loadUser,
                    searchQuery: _searchQuery, // NEW
                  ), 

                   const PurchasesListScreen(),

                  SalesReturnListScreen(
                    searchQuery: _searchQuery, // NEW
                  ),

                ],
              ),
            ),
          ),
      ],
        ),
      ),
    );
  }
}

class InvoicesListTab extends StatefulWidget {
  final Stream<List<BillModel>>? billsStream;
  final UserModel? user;
  final Future<void> Function()? onRefresh; // Changed to Future Function
  final String searchQuery; // NEW
  final String? filterStatus; // NEW
  
  const InvoicesListTab({super.key, required this.billsStream, this.user, this.onRefresh, this.searchQuery = '', this.filterStatus});


  @override
  State<InvoicesListTab> createState() => _InvoicesListTabState();
}

class _InvoicesListTabState extends State<InvoicesListTab> with AutomaticKeepAliveClientMixin {


  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    super.dispose();
  }


  void _checkMou(VoidCallback onAllowed) async {
    if (widget.user != null && !widget.user!.mouAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.acceptTerms ?? 'Accept Terms & Conditions'),
          content: Text(AppLocalizations.of(context)?.readSignMou ?? 'You must read and sign the MOU & Terms before creating invoices.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: Text(AppLocalizations.of(context)?.reviewSign ?? 'Review & Sign'),
            ),
          ],
        ),
      );

      if (accepted == true && mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const MouScreen()),
        );
        if (result == true) {
          if (widget.onRefresh != null) widget.onRefresh!();
        }
      }
    } else {
      onAllowed();
    }
  }

  Future<void> _confirmDelete(BuildContext context, String billId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteInvoice ?? 'Delete Invoice'),
        content: Text(AppLocalizations.of(context)?.deleteConfirmation ?? 'Are you sure you want to delete this invoice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        if (billId.length > 20) {
          await BillsService().deleteBill(billId);
          if (mounted) {
            SnackbarHelper.showSuccess(context, 'Invoice deleted');
            if (widget.onRefresh != null) widget.onRefresh!(); // Refresh list via callback
          }
        } else {
          if (mounted) SnackbarHelper.showError(context, 'Cannot delete legacy invoice from list. Please open it to delete.');
        }
      } catch (e) {
        if (mounted) SnackbarHelper.showError(context, 'Failed to delete: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: Column(
          children: [

            Expanded(
              child: StreamBuilder<List<BillModel>>(
                stream: widget.billsStream,
                builder: (context, snapshot) {
                  // Handle Error gracefully
                  if (snapshot.hasError) {
                    final error = snapshot.error.toString();
                    final isOfflineError = error.contains('RealtimeSubscribeException') || 
                                           error.contains('ClientException') || 
                                           error.contains('Failed to fetch');
                    
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isOfflineError ? Icons.cloud_off : Icons.error_outline, 
                                 size: 48, color: AppColors.textGrey),
                            const SizedBox(height: 16),
                            Text(
                              isOfflineError 
                                ? (AppLocalizations.of(context)?.offlineMode ?? 'Offline Mode\nPull to refresh when connected.') 
                                : 'Error: $error', 
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: widget.onRefresh, 
                              child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(widget.searchQuery.isNotEmpty 
                        ? (AppLocalizations.of(context)?.noBillsMatch ?? 'No bills match your search') 
                        : (AppLocalizations.of(context)?.noBillsFound ?? 'No bills found'));
                  }


                  final bills = snapshot.data!.where((bill) {
                    final query = widget.searchQuery.toLowerCase();
                    final matchesQuery = bill.customerName.toLowerCase().contains(query) ||
                           bill.invoiceNumber.toLowerCase().contains(query) ||
                           bill.totalAmount.toStringAsFixed(0).contains(query);
                    
                    if (widget.filterStatus != null) {
                       return matchesQuery && bill.paymentStatus == widget.filterStatus;
                    }
                    return matchesQuery;
                  }).toList();


                  if (bills.isEmpty) {
                    return _buildEmptyState(AppLocalizations.of(context)?.noBillsMatch ?? 'No bills match your search');
                  }

                  // Group bills by month/year
                  final groupedBills = <String, List<BillModel>>{};
                  final now = DateTime.now();
                  final currentMonthKey = DateFormat('MMMM yyyy').format(now);

                  for (var bill in bills) {
                    final key = DateFormat('MMMM yyyy').format(bill.billDate);
                    groupedBills.putIfAbsent(key, () => []).add(bill);
                  }

                  final sortedKeys = groupedBills.keys.toList();
                  // Note: Since bills are usually streamed descending by date, keys should be mostly in order, 
                  // but we should ensure the order if needed. Stream is already sorted.

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final key = sortedKeys[index];
                      final monthBills = groupedBills[key]!;
                      final monthTotal = monthBills.fold(0.0, (sum, b) => sum + b.totalAmount);
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
                        clipBehavior: Clip.antiAlias, // Ensure children respect border radius
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
                            children: monthBills.map((bill) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildBillCard(context, bill),
                            )).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: LicenseScope.isReadOnlyMode(context) 
        ? null 
        : FloatingActionButton(
            heroTag: 'add_bill',
            onPressed: () => _checkMou(() {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBillScreen()));
            }),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
    );
  }

  Widget _buildContent() {
    // This is now handled inside build() directly
    return const SizedBox.shrink(); 
  }

  Widget _buildSearchBar() {
    return const SizedBox.shrink();
  }


  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, BillModel bill) {
    final date = DateFormat('dd MMM yyyy').format(bill.billDate);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillViewScreen(billId: bill.billId))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(bill.invoiceNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                  ),
                  if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: const Text(
                        'E-WAY', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(bill.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (bill.returnAmount > 0)
                     Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.returned ?? 'RETURNED',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                     ),
                  Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(bill.items.isNotEmpty ? bill.items.map((e) => e.description).join(', ') : bill.serviceName, style: TextStyle(fontSize: 14, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const Spacer(),

                  GestureDetector(
                    onTap: () => LicenseScope.isReadOnlyMode(context) ? null : _showStatusSheet(context, bill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(bill.paymentStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getStatusColor(bill.paymentStatus).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Text(bill.paymentStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(bill.paymentStatus))),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 14, color: _getStatusColor(bill.paymentStatus)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: FontAwesomeIcons.whatsapp, 
                    color: Colors.green, 
                    onTap: () => PdfInvoiceHelper.openWhatsApp(context, bill),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(icon: Icons.delete_outline, color: Colors.red, onTap: LicenseScope.isReadOnlyMode(context) ? null : () => _confirmDelete(context, bill.billId), isDisabled: LicenseScope.isReadOnlyMode(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Paid') return AppColors.success;
    if (status == 'Partial') return Colors.amber.shade700;
    return AppColors.error;
  }

  Widget _actionButton({required dynamic icon, required Color color, required VoidCallback? onTap, bool isDisabled = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: icon is IconData
            ? Icon(icon, size: 18, color: isDisabled ? Colors.grey : color)
            : FaIcon(icon, size: 18, color: isDisabled ? Colors.grey : color),
      ),
    );
  }

  void _showStatusSheet(BuildContext context, BillModel bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)?.updatePaymentStatus ?? 'Update Payment Status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 24),
              _statusOption(context, label: AppLocalizations.of(context)?.paid ?? 'Paid', color: AppColors.success, isSelected: bill.paymentStatus == 'Paid', onTap: () {
                BillsService().updateBillStatus(bill.billId, 'Paid', DateTime.now());
                Navigator.pop(context);
              }),
              const SizedBox(height: 12),
              _statusOption(context, label: AppLocalizations.of(context)?.pending ?? 'Pending', color: AppColors.warning, isSelected: bill.paymentStatus == 'Pending', onTap: () {
                BillsService().updateBillStatus(bill.billId, 'Pending', null);
                Navigator.pop(context);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusOption(BuildContext context, {required String label, required Color color, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.1) : AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? color : AppColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.textDark)),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
