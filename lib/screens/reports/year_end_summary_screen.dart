import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; // Fixed import path
import 'package:intl/intl.dart';
import '../../models/annual_summary_model.dart';
import '../../services/pnl_service.dart';
import '../../services/settings_service.dart'; // NEW
import '../../utils/pdf_year_end_helper.dart';
import '../../theme/app_colors.dart';
import '../../widgets/license_scope.dart'; // NEW


class YearEndSummaryScreen extends StatefulWidget {
  const YearEndSummaryScreen({super.key});

  @override
  State<YearEndSummaryScreen> createState() => _YearEndSummaryScreenState();
}

class _YearEndSummaryScreenState extends State<YearEndSummaryScreen> {
  int _selectedYear = DateTime.now().year;
  final _service = PnLService();
  bool _isExporting = false;

  Future<void> _export(AnnualSummary data) async {
    setState(() => _isExporting = true);
    try {
      final settings = await SettingsService().fetchSettings();
      await PdfYearEndHelper().generateAndDownload(data, settings);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context)?.error ?? 'Error'}: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.yearEndSummary ?? 'Year-End Summary'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return Column(
            children: [
              // HEADER
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => _selectedYear--),
                        ),
                        Text(AppLocalizations.of(context)?.fiscalYear(_selectedYear) ?? 'Fiscal Year $_selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() => _selectedYear++),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: FutureBuilder<AnnualSummary>(
                  future: _service.fetchAnnualSummary(_selectedYear),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData) return Center(child: Text(AppLocalizations.of(context)?.noData ?? 'No Data'));

                    final data = snapshot.data!;
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
                                  gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildTotalItem(AppLocalizations.of(context)?.revenue ?? 'Revenue', data.totalIncome, Colors.greenAccent),
                                        _buildTotalItem(AppLocalizations.of(context)?.expense ?? 'Expense', data.totalExpense, Colors.redAccent),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    const Divider(color: Colors.white24),
                                    const SizedBox(height: 12),
                                    Text(AppLocalizations.of(context)?.netProfitCaps ?? 'NET PROFIT', style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12)),
                                    Text(
                                      '₹${data.netProfit.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // EXPORT
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: LicenseScope.isReadOnlyMode(context) || _isExporting ? null : () => _export(data),
                                  icon: _isExporting 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                      : const Icon(Icons.picture_as_pdf),
                                  label: Text(AppLocalizations.of(context)?.downloadAnnualReport ?? 'Download Annual Report (PDF)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // MONTHLY BREAKDOWN
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(AppLocalizations.of(context)?.monthlyBreakdown ?? 'Monthly Breakdown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                              ),
                              const SizedBox(height: 16),

                              ...data.monthlyData.map((m) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Month Name
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          DateFormat('MMM').format(DateTime(2000, m.month)),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      
                                      // Vertical Divider
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey.shade200,
                                        margin: const EdgeInsets.symmetric(horizontal: 16),
                                      ),

                                      // Right Side Stats
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Amounts Row
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '+ ₹${m.income.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    color: AppColors.success,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '- ₹${m.expense.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    color: AppColors.error,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Stacked Income/Expense Bar
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: SizedBox(
                                                height: 8,
                                                child: Row(
                                                  children: [
                                                    if (m.income > 0)
                                                      Expanded(
                                                        flex: (m.income * 100).toInt(),
                                                        child: Container(color: AppColors.success),
                                                      ),
                                                    if (m.expense > 0)
                                                      Expanded(
                                                        flex: (m.expense * 100).toInt(),
                                                        child: Container(color: AppColors.error),
                                                      ),
                                                    if (m.income == 0 && m.expense == 0)
                                                      Expanded(child: Container(color: Colors.grey.shade200)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
