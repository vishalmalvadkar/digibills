import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_event.dart';
import 'auth_service.dart';

class CalendarService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Add or Update Event
  Future<void> saveEvent(CalendarEvent event) async {
    final Map<String, dynamic> data = event.toMap();
    
    // Inject tenant ID
    data['tenant_id'] = _authService.currentTenantId;

    if (event.id.isEmpty) {
      data.remove('id');
      await _supabase.from('calendar_events').insert(data);
    } else {
      // Upsert: update if exists (Supabase requires primary key match)
      // Since we map id, upsert should work if key exists.
      await _supabase.from('calendar_events').upsert(data);
    }
  }

  // Delete Event
  Future<void> deleteEvent(String id) async {
    try {
      await _supabase.from('calendar_events').delete().eq('id', id);
    } catch (e) {
      // Handle error gracefully or rethrow
      rethrow;
    }
  }

  // Stream Events
  Stream<List<CalendarEvent>> streamEvents({required String tenantId}) {
    return _supabase
        .from('calendar_events')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .map((List<Map<String, dynamic>> data) {
          final events = data.map((json) => CalendarEvent.fromMap(json)).toList();
          events.sort((a, b) => a.date.compareTo(b.date));
          return events;
        });
  }

  // Mark Event as Read (Update is_read column)
  Future<void> markAsRead(String eventId) async {
    await _supabase.from('calendar_events').update({'is_read': true}).eq('id', eventId);
  }
}
