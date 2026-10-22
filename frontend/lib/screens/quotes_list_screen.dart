import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../theme/app_colors.dart';
import 'quote_view_screen.dart';
import 'create_quote_screen.dart';
import '../widgets/license_scope.dart';

import '../utils/snackbar_helper.dart';
import '../utils/pdf_quote_helper.dart';

import '../models/user_model.dart'; // NEW
import 'mou_screen.dart'; // NEW

class QuotesListScreen extends StatefulWidget {
  final UserModel? user; // NEW
  final VoidCallback? onRefresh;
  final String searchQuery; // NEW
  const QuotesListScreen({super.key, this.user, this.onRefresh, this.searchQuery = ''});


  @override
  State<QuotesListScreen> createState() => _QuotesListScreenState();
}

class _QuotesListScreenState extends State<QuotesListScreen> {
  final QuoteService _quoteService = QuoteService();
  late Stream<List<QuoteModel>> _quotesStream;

  @override
  void initState() {
    super.initState();
    _refreshQuotes();
  }

  void _refreshQuotes() {
    setState(() {
      _quotesStream = _quoteService.streamQuotes();
    });
  }

  void _checkMou(VoidCallback onAllowed) async {
    if (widget.user != null && !widget.user!.mouAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept Terms & Conditions'),
          content: const Text('You must read and sign the MOU & Terms before creating quotations.'),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<QuoteModel>>(
        stream: _quotesStream, // Used state variable
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

          final quotes = snapshot.data!.where((q) {
            final query = widget.searchQuery.toLowerCase();
            return q.customerName.toLowerCase().contains(query) ||
                   q.quoteNumber.toLowerCase().contains(query) ||
                   q.totalAmount.toStringAsFixed(0).contains(query);
          }).toList();

          if (quotes.isEmpty) return _buildEmptyState();

          // Group quotes by month/year
          final groupedQuotes = <String, List<QuoteModel>>{};
          final now = DateTime.now();
          final currentMonthKey = DateFormat('MMMM yyyy').format(now);

          for (var quote in quotes) {
            final key = DateFormat('MMMM yyyy').format(quote.date);
            groupedQuotes.putIfAbsent(key, () => []).add(quote);
          }

          final sortedKeys = groupedQuotes.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final monthQuotes = groupedQuotes[key]!;
              final monthTotal = monthQuotes.fold(0.0, (sum, q) => sum + q.totalAmount);
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
                    children: monthQuotes.map((quote) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildQuoteCard(context, quote),
                    )).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: LicenseScope.isReadOnlyMode(context) ? null : FloatingActionButton(
        heroTag: 'add_quote',
        onPressed: () {
          _checkMou(() async {
             await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateQuoteScreen()));
             _refreshQuotes(); // Manual Refresh on return
          });
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No quotations found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context, QuoteModel quote) {
    final date = DateFormat('dd MMM yyyy').format(quote.date);
    
    // Status Logic
    Color statusColor = Colors.grey;
    if (quote.status == 'Sent') statusColor = Colors.blue;
    if (quote.status == 'Accepted') statusColor = Colors.green;
    if (quote.status == 'Expired') statusColor = Colors.red;
    if (quote.status == 'Converted') statusColor = Colors.purple;

    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteViewScreen(quoteId: quote.quoteId)));
      },
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(quote.quoteNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: quote.docType == 'Proforma' ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      quote.docType == 'Proforma' ? 'PROFORMA' : 'QUOTE', 
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: quote.docType == 'Proforma' ? Colors.orange : Colors.blue
                      )
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(quote.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(quote.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('₹${quote.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Expiry: ${DateFormat('dd MMM').format(quote.expiryDate)}', 
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey)
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [


                  _actionButton(
                    context,
                    icon: FontAwesomeIcons.whatsapp,
                    color: Colors.green,
                    onTap: () => PdfQuoteHelper.openWhatsApp(context, quote),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    context,
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () {
                      if (LicenseScope.isReadOnlyMode(context)) return;
                      _confirmDelete(context, quote.quoteId);
                    },
                    isDisabled: LicenseScope.isReadOnlyMode(context),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, {
    required dynamic icon,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: icon is IconData
            ? Icon(icon, size: 18, color: isDisabled ? Colors.grey : color)
            : FaIcon(icon, size: 18, color: isDisabled ? Colors.grey : color),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String quoteId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quote?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _quoteService.deleteQuote(quoteId);
                _refreshQuotes(); // Manual Refresh
                if (context.mounted) {
                  SnackbarHelper.showSuccess(context, 'Quote deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.showError(context, 'Failed to delete quote: $e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
