import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:async';
import '../services/calendar_service.dart';
import '../services/user_service.dart';
import '../widgets/license_scope.dart';
import '../theme/app_colors.dart';
import '../screens/event_creation_sheet.dart';
import '../models/calendar_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmbeddedCalendar extends StatefulWidget {
  const EmbeddedCalendar({super.key});

  @override
  State<EmbeddedCalendar> createState() => _EmbeddedCalendarState();
}

class _EmbeddedCalendarState extends State<EmbeddedCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _tenantId;
  bool _isExpanded = false; // NEW: Toggle State
  
  Map<DateTime, List<CalendarEvent>> _events = {};
  
  final _calendarService = CalendarService();
  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchTenantId();
  }

  Future<void> _fetchTenantId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userModel = await UserService().getUser(user.id);
      if (userModel != null && mounted) {
        setState(() {
          _tenantId = userModel.tenantId;
        });
        _subscribeToEvents(); 
      }
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _subscribeToEvents() {
    if (_tenantId == null) return;

    _eventsSubscription = _calendarService.streamEvents(tenantId: _tenantId!).listen((eventList) {
      final Map<DateTime, List<CalendarEvent>> groupedEvents = {};
      
      for (var event in eventList) {
        final dateKey = _normalizeDate(event.date);
        if (groupedEvents[dateKey] == null) {
          groupedEvents[dateKey] = [];
        }
        groupedEvents[dateKey]!.add(event);
      }

      if (mounted) {
        setState(() {
          _events = groupedEvents;
        });
      }
    }, onError: (e) {
      debugPrint('Error streaming events: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedDay);
    final firstDayOffset = _getFirstDayOffset(_focusedDay);
    final normalizedDate = _normalizeDate(_selectedDay);
    final dayEvents = _events[normalizedDate] ?? [];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                ),
                Row(
                  children: [
                    // Navigate Back
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                        });
                      },
                    ),
                    // Navigate Forward
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.textDark),
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                        });
                      },
                    ),
                    // Today
                    IconButton(
                      icon: const Icon(Icons.today, color: AppColors.primary),
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime.now();
                          _selectedDay = DateTime.now();
                        });
                      },
                    ),
                    // Toggle Minimize/Maximize
                    IconButton(
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textGrey
                        ),
                        onPressed: () {
                          setState(() {
                             _isExpanded = !_isExpanded;
                          });
                        },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (_isExpanded) ...[
            // Days of Week
            _buildDaysOfWeek(),
            
            // Calendar Grid using GridView
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: daysInMonth + firstDayOffset,
              itemBuilder: (context, index) {
                if (index < firstDayOffset) return const SizedBox();
                final day = index - firstDayOffset + 1;
                final date = DateTime(_focusedDay.year, _focusedDay.month, day);
                return _buildCalendarDay(date);
              },
            ),
            
            const Divider(thickness: 1, height: 32),
            
            // Events Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Events on ${DateFormat('dd MMM').format(_selectedDay)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                    ),
                  ),
                  if (!LicenseScope.isReadOnlyMode(context) && _tenantId != null)
                    IconButton(
                      onPressed: () => _showEventCreationSheet(_selectedDay),
                      icon: const Icon(Icons.add_circle, color: AppColors.primary),
                      tooltip: 'Add Event',
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            if (dayEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 32, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No events scheduled',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: dayEvents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildEventCard(dayEvents[index]),
                  );
                },
              ),
          ], 
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          Color color = AppColors.textGrey;
          if (day == 'Sun') color = AppColors.error;
          if (day == 'Sat') color = Colors.amber[700]!;

          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: color,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    final isSelected = isSameDay(date, _selectedDay);
    final isToday = isSameDay(date, DateTime.now());
    final weekday = date.weekday; 
    final dayEvents = _events[normalizedDate] ?? [];

    Color textColor = AppColors.textDark;
    Color? bgColor;
    BoxBorder? border;

    if (weekday == DateTime.sunday) {
      textColor = AppColors.error;
    } else if (weekday == DateTime.saturday) {
      textColor = Colors.amber[700]!;
    }

    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isToday) {
      border = Border.all(color: AppColors.primary, width: 2);
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: border,
          boxShadow: isSelected 
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] 
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (dayEvents.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dayEvents.take(3).map((e) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : e.color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: event.color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: LicenseScope.isReadOnlyMode(context) ? Colors.grey : AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: LicenseScope.isReadOnlyMode(context) 
                        ? null 
                        : () => _showEventCreationSheet(_selectedDay, eventToEdit: event),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: LicenseScope.isReadOnlyMode(context) ? Colors.grey : AppColors.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: LicenseScope.isReadOnlyMode(context) 
                        ? null 
                        : () => _confirmDelete(event),
                  ),
                ],
              ),
            ],
          ),
          if (event.time != null)
             Text(
              event.time!.format(context),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          
          if (event.location != null && event.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showEventCreationSheet(DateTime date, {CalendarEvent? eventToEdit}) async {
    final result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EventCreationSheet(selectedDate: date, eventToEdit: eventToEdit),
      ),
    );

    if (result != null) {
      final eventWithTenant = CalendarEvent(
        id: result.id,
        type: result.type,
        title: result.title,
        date: result.date,
        description: result.description,
        location: result.location,
        contactName: result.contactName,
        contactNumber: result.contactNumber,
        time: result.time,
        platformLink: result.platformLink,
        subFunction: result.subFunction,
        brideName: result.brideName,
        groomName: result.groomName,
        familyName: result.familyName,
        tenantId: _tenantId, // Inject tenantId
        read: result.read,
      );

      await _calendarService.saveEvent(eventWithTenant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventToEdit != null ? 'Event updated successfully!' : 'Event saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  void _confirmDelete(CalendarEvent event) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _calendarService.deleteEvent(event.id);
            }, 
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  int _getDaysInMonth(DateTime date) {
    final firstDayNextMonth = (date.month < 12)
        ? DateTime(date.year, date.month + 1, 1)
        : DateTime(date.year + 1, 1, 1);
    return firstDayNextMonth.difference(DateTime(date.year, date.month, 1)).inDays;
  }

  int _getFirstDayOffset(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final weekday = firstDay.weekday;
    if (weekday == 7) return 0; 
    return weekday; 
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
