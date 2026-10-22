import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../models/client_model.dart';

import 'dart:async'; // NEW
import '../services/calendar_service.dart'; // NEW
import '../services/user_service.dart'; // NEW
import '../models/calendar_event.dart'; // NEW
import 'admin/license_invoice_screen.dart';
import 'admin/client_detail_screen.dart';
import '../services/client_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? _tenantId;
  bool _isLoading = true;

  // Stream Controller for the merged list
  final StreamController<List<Map<String, dynamic>>> _mergedStreamController = StreamController();
  StreamSubscription? _notificationsSub;
  StreamSubscription? _calendarSub;
  
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchTenantId();
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    _calendarSub?.cancel();
    _mergedStreamController.close();
    super.dispose();
  }

  Future<void> _fetchTenantId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Use consistent UserService
      final userModel = await UserService().getUser(user.id);

      if (userModel != null && mounted) {
          setState(() {
            _tenantId = userModel.tenantId;
            _isLoading = false;
          });
          _initStreams(_tenantId!, userModel.role);
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching tenant ID: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initStreams(String tenantId, String role) {
    // 1. Listen to Notifications
    var stream = _supabase
        .from('notifications')
        .stream(primaryKey: ['id']);

    // Filter logic: SuperAdmins see 'superadmin' targeted ones.
    // Clients see their own tenant_id.
    final targetId = role == 'superAdmin' ? 'superadmin' : tenantId;

    _notificationsSub = stream
        .eq('tenant_id', targetId) // Filter by target
        .listen((List<Map<String, dynamic>> data) {
          _notifications = data.map((item) {
             // Ensure fields match what our UI expects
             item['source'] = 'notification';
             if (item['created_at'] != null) {
                item['timestamp'] = DateTime.parse(item['created_at']).toLocal();
             } else {
                item['timestamp'] = DateTime.now();
             }
             // Map snake_case to UI keys if needed, or update UI to use correct keys
             // UI uses: read, timestamp, type, message, id
             // DB uses: is_read, created_at, type, message, id
             item['read'] = item['is_read'] ?? false;
             
             return item;
          }).toList();
          _emitMergedList();
        });

    // 2. Listen to Calendar Events
    // Show events from Today and Past. Exclude Future.
    _calendarSub = CalendarService().streamEvents(tenantId: tenantId).listen((events) {
       final now = DateTime.now();
       final today = DateTime(now.year, now.month, now.day);
       
       _events = events
           .where((e) {
             final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
             return !eventDate.isAfter(today);
           })
           .map((event) {
         return {
           'id': event.id,
           'source': 'calendar',
           'type': 'calendar_event',
           'title': event.title,
           'message': _getEventMessage(event),
           'timestamp': event.createdAt.toLocal(), 
           'eventDate': event.date,
           'read': event.read, 
           'color': event.color,
         };
       }).toList();
       _emitMergedList();
    });
  }

  void _emitMergedList() {
    if (_mergedStreamController.isClosed) return;

    final merged = [..._notifications, ..._events];
    
    // Sort by timestamp descending
    merged.sort((a, b) {
       final tA = a['timestamp'] as DateTime;
       final tB = b['timestamp'] as DateTime;
       return tB.compareTo(tA);
    });

    _mergedStreamController.add(merged);
  }

  String _getEventMessage(CalendarEvent event) {
    String msg = "Scheduled for ${DateFormat('MMM d, h:mm a').format(event.date.toLocal())}";
    if (event.description != null && event.description!.isNotEmpty) {
      msg += "\n${event.description}";
    }
    return msg;
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (item['read'] == true) return;
    
    if (item['source'] == 'notification') {
      try {
        await _supabase.from('notifications').update({'is_read': true}).eq('id', item['id']);
      } catch (e) {
        debugPrint("Error marking notification as read: $e");
      }
    } else {
      // Mark calendar event as read
      try {
        await CalendarService().markAsRead(item['id']);
      } catch (e) {
        debugPrint("Error marking event as read: $e");
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tenantId == null) {
       return const Center(child: Text("Could not identify account."));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _mergedStreamController.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting && !_mergedStreamController.hasListener) {
             if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[200]),
                const SizedBox(height: 16),
                Text(
                  "No notifications yet",
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final bool isRead = data['read'] == true;
            final DateTime dt = data['timestamp'] as DateTime;
            final String timeAgoText = _timeAgo(dt.toLocal());
            
            final String title = _getTitleFromType(data['type'], data['source'] as String?, data['title'] as String?);
            final String message = data['message'] as String? ?? 'No message';
            final bool isCalendar = data['source'] == 'calendar';
            final bool isRenewalRequest = data['type'] == 'renewal_request';
            final Map<String, dynamic>? metadata = data['metadata'] as Map<String, dynamic>?;

            return InkWell(
              onTap: () => _markAsRead(data),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isRead ? Colors.white : AppColors.primary.withOpacity(0.06),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Icon
                    _buildAvatar(isCalendar, isRenewalRequest, data['color'] as Color?),
                    const SizedBox(width: 12),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: '$title: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: message),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeAgoText,
                            style: TextStyle(
                              color: isRead ? Colors.grey[500] : AppColors.primary,
                              fontSize: 12,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                          
                          if (isRenewalRequest && metadata != null) ...[
                             const SizedBox(height: 12),
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: Colors.grey[200]!),
                               ),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   _buildDetailRow(Icons.person_outline, metadata['name'] ?? 'N/A'),
                                   _buildDetailRow(Icons.email_outlined, metadata['email'] ?? 'N/A'),
                                   _buildDetailRow(Icons.phone_outlined, metadata['whatsapp'] ?? 'N/A'),
                                   const SizedBox(height: 12),
                                   SizedBox(
                                     width: double.infinity,
                                     child: ElevatedButton(
                                        onPressed: () => _navigateToEdit(context, metadata['uid'], notificationId: data['id']),
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: AppColors.primary,
                                         foregroundColor: Colors.white,
                                         padding: const EdgeInsets.symmetric(vertical: 10),
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                         elevation: 0,
                                       ),
                                       child: const Text("Process Renewal", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Unread Indicator (Blue Dot)
                    if (!isRead)
                      Container(
                        margin: const EdgeInsets.only(top: 15, left: 8),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(bool isCalendar, bool isRenewalRequest, Color? eventColor) {
    Color bgColor;
    IconData icon;
    
    if (isCalendar) {
      bgColor = (eventColor ?? Colors.blue).withOpacity(0.1);
      icon = Icons.event;
    } else if (isRenewalRequest) {
      bgColor = Colors.orange.withOpacity(0.1);
      icon = Icons.autorenew;
    } else {
      bgColor = AppColors.primary.withOpacity(0.1);
      icon = Icons.notifications;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon, 
        color: isCalendar ? (eventColor ?? Colors.blue) : (isRenewalRequest ? Colors.orange : AppColors.primary),
        size: 24,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitleFromType(dynamic type, String? source, String? title) {
    if (source == 'calendar') {
       return title ?? "Event";
    }
    // Handle null or non-string types safely
    final t = type?.toString() ?? '';
    if (t == 'license_expiry_warning') return "License Expiry";
    if (t == 'renewal_request') return "Renewal Request";
    return "Notification";
  }

  Future<void> _navigateToEdit(BuildContext context, String? uid, {String? notificationId}) async {
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = await ClientService().getClient(uid);
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        if (client != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(client: client, notificationId: notificationId),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client record not found')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class StreamSubscription_Composite implements StreamSubscription<dynamic> {
   final List<StreamSubscription> subs;
   StreamSubscription_Composite(StreamSubscription s1, StreamSubscription s2) : subs = [s1, s2];

   @override
   Future<void> cancel() async {
     for (var s in subs) await s.cancel();
   }

   @override
   void onData(void Function(dynamic data)? handleData) {}
   @override
   void onError(Function? handleError) {}
   @override
   void onDone(void Function()? handleDone) {}
   @override
   void pause([Future<void>? resumeSignal]) { for (var s in subs) s.pause(resumeSignal); }
   @override
   void resume() { for (var s in subs) s.resume(); }
   @override
   bool get isPaused => subs.isNotEmpty && subs.first.isPaused;
   @override
   Future<E> asFuture<E>([E? futureValue]) => subs.first.asFuture(futureValue); 
}
