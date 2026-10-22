import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class BillItemsTable extends StatelessWidget {
  final List<BillItem> items;
  final bool showHsn;

  const BillItemsTable({
    super.key,
    required this.items,
    this.showHsn = true,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return _buildMobileList();
    }
    return _buildDesktopTable(context);
  }

  Widget _buildMobileList() {
    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (showHsn && item.hsnCode != null && item.hsnCode!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.hsnCode!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _mobileInfoItem('Quantity', '${item.quantity} ${item.unit}'),
                  _mobileInfoItem('Rate', '₹${item.unitPrice.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _mobileInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(4), // Description
            1: FlexColumnWidth(1.5), // HSN 
            2: FlexColumnWidth(1.5), // Qty 
            3: FlexColumnWidth(2), // Rate 
            4: FlexColumnWidth(2), // Amount 
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade50),
              children: [
                _tableHeader('Item Description', align: TextAlign.left),
                _tableHeader(items.isNotEmpty ? items.first.hsnType : 'HSN', align: TextAlign.left),
                _tableHeader('Quantity', align: TextAlign.center),
                _tableHeader('Unit Price', align: TextAlign.right),
                _tableHeader('Total Amount', align: TextAlign.right),
              ],
            ),
            // Items
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final bool isEven = index % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : Colors.grey.shade50.withOpacity(0.3),
                ),
                children: [
                  _tableCell(item.description, align: TextAlign.left, isBold: true),
                  _tableCell(item.hsnCode ?? "-", align: TextAlign.left, color: AppColors.textGrey),
                  _tableCell('${item.quantity} ${item.unit}', align: TextAlign.center),
                  _tableCell('₹${item.unitPrice.toStringAsFixed(2)}', align: TextAlign.right),
                  _tableCell('₹${item.amount.toStringAsFixed(2)}', align: TextAlign.right, isBold: true, color: AppColors.primary),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
          color: AppColors.textGrey,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _tableCell(String text, {TextAlign align = TextAlign.left, Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: color ?? AppColors.textDark,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
        textAlign: align,
      ),
    );
  }
}
