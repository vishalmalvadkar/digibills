import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'income_ledger_screen.dart';
import 'account_summary_screen.dart';
import 'client_list_screen.dart';
import 'expenses/expense_list_screen.dart';
import 'reports/pnl_screen.dart';
import 'reports/receivables_screen.dart';
import 'reports/tax_ledger_screen.dart';
import 'reports/accounting_reports_screen.dart';
import 'reports/year_end_summary_screen.dart';
import 'reports/balance_sheet_screen.dart'; // NEW
import '../utils/responsive.dart';
import 'package:provider/provider.dart';
import '../providers/shell_provider.dart';
import '../l10n/app_localizations.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  List<Widget> _buildMenuItems(BuildContext context, {bool useSpacing = true}) {
    final List<Widget> items = [];
    final l10n = AppLocalizations.of(context);
    
    void addItem(String title, String subtitle, IconData icon, Color color, Widget screen) {
      items.add(_buildMenuCard(
        context,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ));
      if (useSpacing) items.add(const SizedBox(height: 16));
    }

    addItem(l10n?.incomeLedger ?? 'Income Ledger', l10n?.incomeLedgerDesc ?? 'Track all incoming payments', Icons.account_balance_wallet, AppColors.success, const IncomeLedgerScreen());
    addItem(l10n?.accountSummary ?? 'Account Summary', l10n?.accountSummaryDesc ?? 'Overview of earnings and expenses', Icons.pie_chart, Colors.blue, const AccountSummaryScreen());
    addItem(l10n?.clientStatement ?? 'Client Statement', l10n?.clientStatementDesc ?? 'View individual client ledgers', Icons.people_alt, Colors.orange, const ClientListScreen());
    addItem(l10n?.expenseTracker ?? 'Expense Tracker', l10n?.expenseTrackerDesc ?? 'Log and track business expenses', Icons.receipt, Colors.purple, const ExpenseListScreen());
    addItem(l10n?.profitAndLoss ?? 'Profit & Loss', l10n?.profitAndLossDesc ?? 'Analyze your financial performance', Icons.bar_chart, Colors.teal, const PnLScreen());
    addItem(l10n?.outstandingReceivables ?? 'Outstanding Receivables', l10n?.outstandingReceivablesDesc ?? 'Track unpaid bills & overdue clients', Icons.access_time_filled, Colors.deepOrange, const ReceivablesScreen());
    addItem(l10n?.gstTaxLedger ?? 'GST / Tax Ledger', l10n?.gstTaxLedgerDesc ?? 'Track collected taxes & taxable values', Icons.receipt_long, Colors.indigo, const TaxLedgerScreen());
    addItem(l10n?.accountingReports ?? 'Accounting Reports', l10n?.accountingReportsDesc ?? 'Export data to CSV / Excel', Icons.assessment_outlined, Colors.teal, const AccountingReportsScreen());
    addItem(l10n?.yearEndSummary ?? 'Year-End Summary', l10n?.yearEndSummaryDesc ?? 'Annual revenue & expense breakdown', Icons.calendar_month_outlined, Colors.blueGrey, const YearEndSummaryScreen());
    addItem(l10n?.balanceSheet ?? 'Balance Sheet', l10n?.balanceSheetDesc ?? 'Assets, Liabilities & Equity Statement', Icons.account_balance, Colors.brown, const BalanceSheetScreen());

    return items;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: Responsive.isDesktop(context) ? 1024 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!Responsive.isDesktop(context)) ...[
                     Text(
                      AppLocalizations.of(context)?.account ?? 'Account',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                     Text(
                      AppLocalizations.of(context)?.manageFinances ?? 'Manage your business finances',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
    
                  Responsive(
                    mobile: Column(
                      children: _buildMenuItems(context),
                    ),
                    tablet: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 2.5,
                      children: _buildMenuItems(context, useSpacing: false),
                    ),
                    desktop: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 3,
                      children: _buildMenuItems(context, useSpacing: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
