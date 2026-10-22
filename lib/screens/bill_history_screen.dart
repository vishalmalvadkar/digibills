import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/audit_service.dart';
import '../theme/app_colors.dart';
import '../models/bill_model.dart';
import '../services/settings_service.dart';

class BillHistoryScreen extends StatefulWidget {
  final String billId;
  final String invoiceNumber;

  const BillHistoryScreen({
    super.key, 
    required this.billId,
    required this.invoiceNumber,
  });

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  final AuditService _auditService = AuditService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkStatusAndLoad();
  }

  Future<void> _checkStatusAndLoad() async {
    final settings = await SettingsService().fetchSettings();
    if (settings != null) {
      setState(() => _isEnabled = settings.isAuditTrailEnabled);
    }
    
    // Always load logs even if currently disabled, to show past history
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _auditService.fetchLogs(widget.billId);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('History: ${widget.invoiceNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _logs.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No history found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  if (!_isEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Audit Trail is currently disabled in Settings.',
                        style: TextStyle(color: Colors.orange[700], fontSize: 12),
                      ),
                    ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return _buildLogItem(log);
              },
            ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'] ?? 'UNKNOWN';
    final timestamp = DateTime.parse(log['timestamp']).toLocal();
    final changes = log['changes'] as Map<String, dynamic>?;

    Color color;
    IconData icon;

    switch (action) {
      case 'CREATE':
        color = Colors.green;
        icon = Icons.add_circle;
        break;
      case 'EDIT':
        color = Colors.blue;
        icon = Icons.edit;
        break;
      case 'DELETE':
        color = Colors.red;
        icon = Icons.delete;
        break;
      case 'STATUS_CHANGE':
        color = Colors.orange;
        icon = Icons.payment;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatAction(action),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            if (changes != null && changes.isNotEmpty) ...[
              const Divider(height: 24),
              _buildChangesList(changes),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case 'CREATE': return 'Invoice Created';
      case 'EDIT': return 'Invoice Updated';
      case 'DELETE': return 'Invoice Deleted';
      case 'STATUS_CHANGE': return 'Payment Status Changed';
      default: return action;
    }
  }

  Widget _buildChangesList(Map<String, dynamic> changes) {
    if (changes.containsKey('old') && changes.containsKey('new')) {
       // Single field change logic (like status)
       return _buildChangeRow('Status', changes['old'], changes['new']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changes.entries.map((entry) {
        final key = entry.key;
        final val = entry.value;
        if (val is Map && val.containsKey('old') && val.containsKey('new')) {
          return _buildChangeRow(key, val['old'], val['new']);
        }
        return Text('$key: $val', style: const TextStyle(fontSize: 13, color: Colors.grey));
      }).toList(),
    );
  }

  Widget _buildChangeRow(String key, dynamic oldVal, dynamic newVal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatKey(key)}: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Expanded(
            child: Wrap(
               children: [
                 Text(
                   '$oldVal',
                   style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red, fontSize: 13),
                 ),
                 const Padding(
                   padding: EdgeInsets.symmetric(horizontal: 4),
                   child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                 ),
                 Text(
                   '$newVal',
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                 ),
               ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').capitalize();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
