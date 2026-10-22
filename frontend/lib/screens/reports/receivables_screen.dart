import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; // Fixed import path
import 'package:intl/intl.dart';
import '../../models/client_receivable_model.dart';
import '../../services/receivables_service.dart';
import '../../theme/app_colors.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  final _service = ReceivablesService();
  int _sortColumnIndex = 2; // Default sort by Amount
  bool _sortAscending = false; // Descending
  late Future<List<ClientReceivableModel>> _receivablesFuture;

  @override
  void initState() {
    super.initState();
    _receivablesFuture = _service.fetchReceivables();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.outstandingReceivables ?? 'Outstanding Receivables'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return FutureBuilder<List<ClientReceivableModel>>(
            future: _receivablesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 60, color: AppColors.success),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)?.noOutstanding ?? 'Great! No outstanding bills.', style: const TextStyle(color: AppColors.textGrey)),
                    ],
                  ),
                );
              }

              var data = snapshot.data!;
              
              // SORTING LOGIC
              data.sort((a, b) {
                int cmp;
                switch (_sortColumnIndex) {
                  case 0: // Name
                    cmp = a.clientName.compareTo(b.clientName);
                    break;
                  case 1: // Count
                    cmp = a.billCount.compareTo(b.billCount);
                    break;
                  case 2: // Amount
                    cmp = a.totalPending.compareTo(b.totalPending);
                    break;
                  case 3: // Overdue
                    cmp = a.overdueDays.compareTo(b.overdueDays);
                    break;
                  default:
                    cmp = 0;
                }
                return _sortAscending ? cmp : -cmp; // Toggle asc/desc
              });

              // Calc Total
              double grandTotal = data.fold(0, (sum, item) => sum + item.totalPending);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
                    child: Column(
                      children: [
                        // GRAND TOTAL CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(AppLocalizations.of(context)?.totalOutstandingBalance ?? 'Total Outstanding Balance', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                '₹${grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.length} Clients Pending',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // DATA TABLE
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: isDesktop ? 900 : (constraints.maxWidth - 32),
                                ),
                                child: DataTable(
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _sortAscending,
                                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                                  horizontalMargin: 20,
                                  columnSpacing: isDesktop ? 48 : 24,
                                  columns: [
                                    DataColumn(
                                      label: Text(AppLocalizations.of(context)?.customer ?? 'Client', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: Text(AppLocalizations.of(context)?.bills ?? 'Bills', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      numeric: true,
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: Text(AppLocalizations.of(context)?.amount ?? 'Amount', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      numeric: true,
                                      onSort: _onSort,
                                    ),
                                    DataColumn(
                                      label: Text(AppLocalizations.of(context)?.overdue ?? 'Overdue', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      numeric: true,
                                      onSort: _onSort,
                                    ),
                                  ],
                                  rows: data.map((item) {
                                    Color overdueColor = AppColors.textDark;
                                    if (item.overdueDays > 60) overdueColor = AppColors.error;
                                    else if (item.overdueDays > 30) overdueColor = Colors.orange;

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(Text(item.billCount.toString())),
                                        DataCell(Text('₹${item.totalPending.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(
                                          AppLocalizations.of(context)?.days(item.overdueDays) ?? '${item.overdueDays} Days', 
                                          style: TextStyle(color: overdueColor, fontWeight: FontWeight.bold)
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }
}
