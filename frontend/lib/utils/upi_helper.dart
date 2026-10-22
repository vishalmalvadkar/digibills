import 'dart:core';

class UpiHelper {
  /// Generates a UPI payment URL with proper encoding and formatting.
  /// 
  /// [pa] - VPA or UPI ID (e.g. name@bank)
  /// [pn] - Payee Name
  /// [am] - Amount to be paid
  /// [cu] - Currency (default is INR)
  /// [tn] - Transaction Note (e.g. Invoice #123)
  static String generateUpiUrl({
    required String pa,
    required String pn,
    required double am,
    String cu = 'INR',
    String? tn,
  }) {
    final String amountStr = am.toStringAsFixed(2);
    
    final Map<String, String> queryParams = {
      'pa': pa,
      'pn': pn,
      'am': amountStr,
      'cu': cu,
    };
    
    if (tn != null && tn.isNotEmpty) {
      queryParams['tn'] = tn;
    }
    
    // Standard UPI parameters:
    // pa: Payee address (VPA) - Should be literal (e.g. name@bank)
    // pn: Payee name - Needs encoding
    // am: Amount - Literal decimal
    // cu: Currency - Literal (Usually INR)
    // tn: Transaction note - Needs encoding
    
    final List<String> parts = [
      'pa=$pa',
      'pn=${Uri.encodeComponent(pn)}',
      'am=$amountStr',
      'cu=$cu',
    ];
    
    if (tn != null && tn.isNotEmpty) {
      parts.add('tn=${Uri.encodeComponent(tn)}');
    }
    
    return 'upi://pay?${parts.join('&')}';
  }
}
