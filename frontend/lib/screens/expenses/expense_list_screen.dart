import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import 'add_expense_screen.dart';
import '../../widgets/license_scope.dart'; // NEW


class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  DateTime _focusedDate = DateTime.now();
  String _viewMode = 'Month'; // 'Month' or 'Year'

  void _changeDate(int offset) {
    setState(() {
      if (_viewMode == 'Month') {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + offset);
      } else {
        _focusedDate = DateTime(_focusedDate.year + offset);
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == 'Month' ? 'Year' : 'Month';
    });
  }

  bool _isSamePeriod(DateTime date) {
    if (_viewMode == 'Month') {
      return date.year == _focusedDate.year && date.month == _focusedDate.month;
    } else {
      return date.year == _focusedDate.year;
    }
  }

  double _calculateTotal(List<ExpenseModel> expenses) {
    double total = 0;
    for (var expense in expenses) {
      if (_isSamePeriod(expense.date)) {
        total += expense.amount;
      }
    }
    return total;
  }

  late Stream<List<ExpenseModel>> _expensesStream;

  @override
  void initState() {
    super.initState();
    _expensesStream = ExpenseService().streamExpenses();
  }

  void _refreshExpenses() {
    setState(() {
      _expensesStream = ExpenseService().streamExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = _viewMode == 'Month'
        ? DateFormat('MMMM yyyy').format(_focusedDate)
        : DateFormat('yyyy').format(_focusedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      floatingActionButton: LicenseScope.isReadOnlyMode(context) 
          ? null 
          : FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          _refreshExpenses();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white, // FIX: Icon color white
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // FILTER CONTROLS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Toggle Button
                InkWell(
                  onTap: _toggleViewMode,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _viewMode,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
                const Spacer(),
                // Nav Controls
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // STREAM BUILDER
          Expanded(
            child: StreamBuilder<List<ExpenseModel>>(
              stream: _expensesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No expenses logged yet.'));
                }

                // Filter Data locally
                final allExpenses = snapshot.data!;
                final filteredExpenses = allExpenses.where((e) => _isSamePeriod(e.date)).toList();
                final total = _calculateTotal(filteredExpenses);

                if (filteredExpenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textGrey),
                        const SizedBox(height: 8),
                        Text('No expenses for $dateLabel', style: const TextStyle(color: AppColors.textGrey)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Summary for selected Period
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 1), // separating line
                      child: Column(
                        children: [
                           Text(
                             'Total ($_viewMode)',
                             style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             '₹${total.toStringAsFixed(2)}',
                             style: const TextStyle(
                               fontSize: 32,
                               fontWeight: FontWeight.bold,
                               color: AppColors.error,
                             ),
                           ),
                        ],
                      ),
                    ),
                    
                    // List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredExpenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final expense = filteredExpenses[index];
                          return _expenseCard(expense);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseCard(ExpenseModel expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.outbound, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${expense.category} • ${DateFormat('dd MMM').format(expense.date)}',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
                if (expense.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      expense.notes!,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '₹${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
