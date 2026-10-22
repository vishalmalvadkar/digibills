import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/bill_model.dart';
import '../theme/app_colors.dart';
import '../services/bills_service.dart';
import '../l10n/app_localizations.dart';

class AccountSummaryScreen extends StatefulWidget {
  const AccountSummaryScreen({super.key});

  @override
  State<AccountSummaryScreen> createState() => _AccountSummaryScreenState();
}

class _AccountSummaryScreenState extends State<AccountSummaryScreen> {
  late Stream<List<BillModel>> _billsStream;

  @override
  void initState() {
    super.initState();
    _billsStream = BillsService().streamBills();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n?.accountSummary ?? 'Account Summary'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: StreamBuilder<List<BillModel>>(
        stream: _billsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text(l10n?.error ?? 'Error loading data'));
          }

          final bills = snapshot.data ?? [];
          
          // 1. Total Billed
          final totalBilled = bills.fold(0.0, (sum, bill) => sum + bill.totalAmount);

          // 2. Total Paid (Sum of totalAmount for 'Paid' bills + Advance for Pending/Partial)
          // Simplified logic: If Paid, full amount. If Partial, advance amount. If Pending, 0 or advance if any.
          double totalPaid = 0.0;
          for (var bill in bills) {
            if (bill.paymentStatus == 'Paid') {
              totalPaid += bill.totalAmount;
            } else {
              totalPaid += bill.advanceAmount; // Advance/Partial payment
            }
          }

          // 3. Outstanding (Total Billed - Total Paid)
          final outstandingBalance = totalBilled - totalPaid;

          // 4. Pending Receivables (Calculated from Bills)
          // Logic: Sum of (Total - Advance) for all Pending/Partial bills where status != Paid
          double pendingReceivables = 0.0;
          for (var bill in bills) {
             if (bill.paymentStatus != 'Paid') {
               pendingReceivables += (bill.totalAmount - bill.advanceAmount);
             }
          }
          // Note: In this logic, outstandingBalance should technically EQUAL pendingReceivables unless logic diverges.
          // Let's keep them consistent.

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Summary Cards
                Row(
                  children: [
                    _summaryCard(l10n?.totalBilled ?? 'Total Billed', totalBilled, Colors.blue),
                    const SizedBox(width: 12),
                    _summaryCard(l10n?.totalPaid ?? 'Total Paid', totalPaid, AppColors.success),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                     _summaryCard(l10n?.pendingReceivables ?? 'Pending Receivables', pendingReceivables, Colors.orange),
                     const SizedBox(width: 12),
                     _summaryCard(l10n?.outstandingBalance ?? 'Outstanding Balance', outstandingBalance, AppColors.error),
                  ],
                ),

                const SizedBox(height: 32),

                // Chart Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                       Text(
                        l10n?.paymentDistribution ?? 'Payment Distribution',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      if (totalBilled > 0)
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: totalPaid,
                                color: AppColors.success,
                                title: '${((totalPaid/totalBilled)*100).toStringAsFixed(1)}%',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              PieChartSectionData(
                                value: outstandingBalance > 0 ? outstandingBalance : 0, 
                                color: AppColors.error,
                                title: '${((outstandingBalance/totalBilled)*100).toStringAsFixed(1)}%',
                                radius: 50,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ) else Text(l10n?.noData ?? 'No Data', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legend(l10n?.paid ?? 'Paid', AppColors.success),
                          const SizedBox(width: 24),
                          _legend(l10n?.outstandingBalance ?? 'Outstanding', AppColors.error),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 8),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: color
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String text, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
