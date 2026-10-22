import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:async'; // For StreamSubscription
import '../services/calendar_service.dart'; // NEW
import '../services/user_service.dart'; // NEW
import '../widgets/license_scope.dart'; // NEW
import '../theme/app_colors.dart';
import 'event_creation_sheet.dart';
import '../models/calendar_event.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive.dart';
import 'package:provider/provider.dart'; // NEW
import '../providers/shell_provider.dart'; // NEW

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _tenantId; // NEW
  
  // Events stored in a Map where key is the Date (normalized to midnight)
  Map<DateTime, List<CalendarEvent>> _events = {};
  
  final _calendarService = CalendarService();
  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchTenantId();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _fetchTenantId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Use cached UserService
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

  // Normalize date to remove time part for map keys
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: Responsive.isDesktop(context) 
        ? null 
        : AppBar(
        title: Text(
          DateFormat('MMMM yyyy').format(_focusedDay),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textDark),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Responsive(
        mobile: _buildMobileView(dayEvents, daysInMonth, firstDayOffset),
        tablet: _buildDesktopView(dayEvents, daysInMonth, firstDayOffset),
        desktop: _buildDesktopView(dayEvents, daysInMonth, firstDayOffset),
      ),
      floatingActionButton: (Responsive.isDesktop(context) || LicenseScope.isReadOnlyMode(context) || _tenantId == null)
          ? null 
          : FloatingActionButton(
        onPressed: () => _showEventCreationSheet(_selectedDay),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileView(List<CalendarEvent> dayEvents, int daysInMonth, int firstDayOffset) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildDaysOfWeek()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < firstDayOffset) return const SizedBox();
                final day = index - firstDayOffset + 1;
                final date = DateTime(_focusedDay.year, _focusedDay.month, day);
                return _buildCalendarDay(date);
              },
              childCount: daysInMonth + firstDayOffset,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Divider(thickness: 1, height: 1),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                alignment: Alignment.centerLeft,
                color: AppColors.background,
                child: Text(
                  'Events on ${DateFormat('dd MMM').format(_selectedDay)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (dayEvents.isEmpty) return _buildNoEventsPlaceholder();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  onTap: () => _showEventDetails(context, dayEvents[index]),
                  child: _buildEventCard(dayEvents[index]),
                ),
              );
            },
            childCount: dayEvents.isEmpty ? 1 : dayEvents.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildDesktopView(List<CalendarEvent> dayEvents, int daysInMonth, int firstDayOffset) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Small Calendar
        Container(
          width: 400,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              _buildDaysOfWeek(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: daysInMonth + firstDayOffset,
                  itemBuilder: (context, index) {
                    if (index < firstDayOffset) return const SizedBox();
                    final day = index - firstDayOffset + 1;
                    final date = DateTime(_focusedDay.year, _focusedDay.month, day);
                    return _buildCalendarDay(date);
                  },
                ),
              ),
            ],
          ),
        ),
        // Right Column: Events & Actions
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Schedule for ${DateFormat('EEEE, dd MMMM').format(_selectedDay)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    if (!LicenseScope.isReadOnlyMode(context) && _tenantId != null)
                      ElevatedButton.icon(
                        onPressed: () => _showEventCreationSheet(_selectedDay),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text("Create Event"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: dayEvents.isEmpty 
                    ? _buildNoEventsPlaceholder()
                    : ListView.builder(
                        itemCount: dayEvents.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _showEventDetails(context, dayEvents[index]),
                            child: _buildEventCard(dayEvents[index]),
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoEventsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No events scheduled for this day',
            style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep track of your business appointments and reminders here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.background,
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
                  fontSize: 14,
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

    // Get events for this day
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
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: isSelected 
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (dayEvents.isNotEmpty) ...[
              const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20, color: LicenseScope.isReadOnlyMode(context) ? Colors.grey : AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: LicenseScope.isReadOnlyMode(context) 
                        ? null 
                        : () => _showEventCreationSheet(_selectedDay, eventToEdit: event),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: LicenseScope.isReadOnlyMode(context) ? Colors.grey : AppColors.error),
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
             Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Text(
                event.time!.format(context),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
            ),
             ),
          const SizedBox(height: 4),
          Text(
             event.type.name.toUpperCase(),
             style: TextStyle(
               fontSize: 10,
               fontWeight: FontWeight.bold,
               color: event.color,
               letterSpacing: 0.5,
             ),
          ),
          const SizedBox(height: 8),
          
          if (event.description != null && event.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                event.description!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),

          if (event.location != null && event.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          if (event.contactNumber != null && event.contactNumber!.isNotEmpty)
            InkWell(
              onTap: () => _makePhoneCall(event.contactNumber!),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Call ${event.contactNumber}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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
      // Reconstruct with tenantId
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

      // Save to Firestore
      await _calendarService.saveEvent(eventWithTenant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventToEdit != null ? 'Event updated successfully!' : 'Event saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              // Delete from Firestore
              await _calendarService.deleteEvent(event.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                     content: const Text('Event deleted'),
                     backgroundColor: AppColors.error,
                     behavior: SnackBarBehavior.floating,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _showEventDetails(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) {
         return AlertDialog(
           title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
           content: SingleChildScrollView(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min,
               children: [
                 if (event.time != null)
                   _detailRow(Icons.access_time, event.time!.format(context)),
                 if (event.description != null && event.description!.isNotEmpty)
                   _detailRow(Icons.notes, event.description!),
                 if (event.location != null && event.location!.isNotEmpty)
                   _detailRow(Icons.location_on, event.location!),
                 if (event.contactNumber != null && event.contactNumber!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _makePhoneCall(event.contactNumber!);
                        },
                        child: Row(
                           children: [
                             const Icon(Icons.call, color: AppColors.success, size: 20),
                             const SizedBox(width: 8),
                             Text(event.contactNumber!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                           ],
                        ),
                      ),
                    ),
                 
                 const SizedBox(height: 16),
                 Text('Type: ${event.type.name.toUpperCase()}', style: TextStyle(fontSize: 10, color: event.color, fontWeight: FontWeight.bold)),
               ],
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text('Close'),
             ),
             if (!LicenseScope.isReadOnlyMode(context))
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEventCreationSheet(_selectedDay, eventToEdit: event);
                  },
                  child: const Text('Edit'),
                ),
           ],
         );
      },
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}


