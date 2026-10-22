import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/upi_helper.dart';

void main() {
  group('UpiHelper Tests', () {
    test('should generate a correct UPI URL with basic parameters', () {
      final url = UpiHelper.generateUpiUrl(
        pa: 'test@upi',
        pn: 'Test Payee',
        am: 100.5,
      );
      
      expect(url, contains('pa=test@upi'));
      expect(url, contains('pn=Test%20Payee'));
      expect(url, contains('am=100.50'));
      expect(url, contains('cu=INR'));
      expect(url, startsWith('upi://pay?'));
    });

    test('should generate a correct UPI URL with transaction note', () {
      final url = UpiHelper.generateUpiUrl(
        pa: 'test@upi',
        pn: 'Test Payee',
        am: 50.0,
        tn: 'Invoice #123 & 456',
      );
      
      expect(url, contains('tn=Invoice%20%23123%20%26%20456'));
    });

    test('should handle zero amount correctly', () {
      final url = UpiHelper.generateUpiUrl(
        pa: 'test@upi',
        pn: 'Test Payee',
        am: 0.0,
      );
      
      expect(url, contains('am=0.00'));
    });
  });
}
