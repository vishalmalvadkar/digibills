import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/client_model.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<void> checkNotifications(BuildContext context) async {
    try {
      final user = _authService.currentUser ?? _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get Client Details to check License
      final tenantId = _authService.currentTenantId;
      
      final clientData = await _supabase
          .from('clients')
          .select()
          .eq('client_id', user.id) // Assuming user.id links to client_id
          .maybeSingle();

      if (clientData == null) return;

      final client = ClientModel.fromMap(clientData);
      
      if (!client.license.isActive) return;
      
      final DateTime endDate = client.license.endDate;
      final DateTime now = DateTime.now();
      
      // 2. Check strict date rules
      if (!_shouldNotifyToday(endDate, now)) return;

      // 3. Deduplication: Check if we already notified this tenant TODAY
     
      final String dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // Check in 'notifications' table if there is a 'license_expiry_warning' for this date
      final existing = await _supabase
          .from('notifications')
          .select()
          .eq('tenant_id', tenantId)
          .eq('date_key', dateKey)
          .eq('type', 'license_expiry_warning')
          .maybeSingle();

      if (existing != null) {
        // Already notified today
        return;
      }

      // 4. Show Notification and Save
      if (context.mounted) {
         _showExpiryWarning(context, endDate);
         
         await _supabase.from('notifications').insert({
           'tenant_id': tenantId,
           'client_id': client.clientId,
           'date_key': dateKey,
           'type': 'license_expiry_warning',
           'message': 'License expiry warning shown',
         });
      }

    } catch (e) {
      // Gracefully ignore network/resolution errors when backend API is handling authentication
      final msg = e.toString();
      if (!msg.contains('ClientException') && !msg.contains('Failed to fetch')) {
        debugPrint("NotificationService info: $e");
      }
    }
  }

  bool _shouldNotifyToday(DateTime endDate, DateTime now) {
    // Calculate days until expiry
    final difference = endDate.difference(now).inDays;
    
    // Rule 3: Last 7 days before expiry AND any day after expiry (persistent warning)
    if (difference <= 6) {
      return true;
    }

    // Rule 2: Specific days of the expiry month
    final dayOfMonth = now.day;
    if (dayOfMonth == 1 || dayOfMonth == 8 || dayOfMonth == 15) {
      return true;
    }

    return false;
  }

  Future<void> sendRenewalRequest({
    required String uid,
    required String name,
    required String email,
    required String whatsapp,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'tenant_id': 'superadmin', // Targeted at SuperAdmins
        'type': 'renewal_request',
        'message': 'Renewal Request from $name',
        'metadata': {
          'uid': uid,
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
        },
        'is_read': false,
      });
    } catch (e) {
      debugPrint("Error sending renewal request: $e");
      rethrow;
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  void _showExpiryWarning(BuildContext context, DateTime endDate) {
    // Calculate days remaining for the message
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    String message;
    if (daysRemaining <= 0) {
      message = "Your license expires today! Please renew immediately.";
    } else {
      message = "Action Required: Your license expires in $daysRemaining days.";
    }

    // Display robust UI
    showDialog(
      context: context,
      barrierDismissible: true, // Force them to acknowledge
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text("License Expiry"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigation to contacts or payment could go here
              // For now just close
            },
            child: const Text("Renew Now"),
          )
        ],
      ),
    );
  }
}
