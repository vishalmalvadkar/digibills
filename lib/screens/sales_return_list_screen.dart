import 'package:flutter/material.dart';
import '../widgets/license_scope.dart';
import 'package:intl/intl.dart';
import '../models/credit_note_model.dart';
import '../services/credit_note_service.dart';
import '../theme/app_colors.dart';
import 'create_credit_note_screen.dart';
import 'credit_note_detail_screen.dart';

class SalesReturnListScreen extends StatelessWidget {
  final String searchQuery; // NEW
  const SalesReturnListScreen({super.key, this.searchQuery = ''});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<CreditNoteModel>>(
        stream: CreditNoteService().streamCreditNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final returns = snapshot.data!.where((note) {
            final query = searchQuery.toLowerCase();
            return note.creditNoteNumber.toLowerCase().contains(query) ||
                   note.invoiceNumber.toLowerCase().contains(query) ||
                   note.totalAmount.toStringAsFixed(0).contains(query);
          }).toList();

          if (returns.isEmpty) return _buildEmptyState();

          // Group returns by month/year
          final groupedReturns = <String, List<CreditNoteModel>>{};
          final now = DateTime.now();
          final currentMonthKey = DateFormat('MMMM yyyy').format(now);

          for (var note in returns) {
            final key = DateFormat('MMMM yyyy').format(note.returnDate);
            groupedReturns.putIfAbsent(key, () => []).add(note);
          }

          final sortedKeys = groupedReturns.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final monthReturns = groupedReturns[key]!;
              final monthTotal = monthReturns.fold(0.0, (sum, note) => sum + note.totalAmount);
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
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '- ₹${monthTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
                    children: monthReturns.map((note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: AppColors.background, // Slightly different color for nested card to distinguish
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            child: const Icon(Icons.undo, color: AppColors.error),
                          ),
                          title: Text(note.creditNoteNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(note.returnDate)),
                              if (note.invoiceNumber.isNotEmpty)
                                 Text('Inv: ${note.invoiceNumber}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              if (note.reason.isNotEmpty)
                                Text(note.reason, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '- ₹${note.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Processed', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => CreditNoteDetailScreen(note: note)));
                          },
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: LicenseScope.isReadOnlyMode(context) 
        ? null 
        : FloatingActionButton(
            heroTag: 'add_return',
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCreditNoteScreen()));
            },
            backgroundColor: AppColors.error,
            child: const Icon(Icons.add, color: Colors.white),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_return_outlined, size: 64, color: AppColors.textGrey),
          const SizedBox(height: 16),
          Text(searchQuery.isNotEmpty ? 'No returns match your search' : 'No Returns Found', style: const TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
