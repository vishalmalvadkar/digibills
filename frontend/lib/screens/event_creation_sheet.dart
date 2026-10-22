import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; 
import '../theme/app_colors.dart';
import '../models/calendar_event.dart';

class EventCreationSheet extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarEvent? eventToEdit;

  const EventCreationSheet({
    super.key, 
    required this.selectedDate,
    this.eventToEdit,
  });

  @override
  State<EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends State<EventCreationSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controllers for Meeting
  final _meetingTitleController = TextEditingController();
  final _meetingWhoController = TextEditingController();
  final _meetingLocController = TextEditingController();
  final _meetingContactController = TextEditingController();
  TimeOfDay? _meetingTime;

  // Controllers for Task
  final _taskNameController = TextEditingController();
  final _taskPlanController = TextEditingController();

  // Controllers for Wedding
  List<String> _weddingFunctions = ['Wedding'];
  final _brideController = TextEditingController();
  final _groomController = TextEditingController();
  final _familyController = TextEditingController();
  final _weddingLocController = TextEditingController();
  final _weddingContactController = TextEditingController();
  TimeOfDay? _weddingTime;

  // Controllers for Virtual Meeting
  final _virtualTitleController = TextEditingController();
  final _virtualPlatformController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  final _virtualContactController = TextEditingController();
  TimeOfDay? _virtualTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (widget.eventToEdit != null) {
      _prefillData();
    }
  }

  void _prefillData() {
    final event = widget.eventToEdit!;
    final index = EventType.values.indexOf(event.type);
    _tabController.index = index;

    switch (event.type) {
      case EventType.meeting:
        _meetingTitleController.text = event.title;
        _meetingWhoController.text = event.description?.replaceAll('With: ', '') ?? '';
        _meetingLocController.text = event.location ?? '';
        _meetingContactController.text = event.contactNumber ?? '';
        _meetingTime = event.time;
        break;
      case EventType.task:
        _taskNameController.text = event.title;
        _taskPlanController.text = event.description ?? '';
        break;
      case EventType.wedding:
        if (event.subFunction != null && event.subFunction!.isNotEmpty) {
           _weddingFunctions = event.subFunction!.split(', ');
        }
        _brideController.text = event.brideName ?? '';
        _groomController.text = event.groomName ?? '';
        _familyController.text = event.familyName ?? '';
        _weddingLocController.text = event.location ?? '';
        _weddingContactController.text = event.contactNumber ?? '';
        _weddingTime = event.time;
        break;
      case EventType.virtualMeeting:
        _virtualTitleController.text = event.title;
        _virtualPlatformController.text = event.description?.replaceAll('Platform: ', '') ?? '';
        _virtualLinkController.text = event.platformLink ?? '';
        _virtualContactController.text = event.contactNumber ?? '';
        _virtualTime = event.time;
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _meetingTitleController.dispose();
    _meetingWhoController.dispose();
    _meetingLocController.dispose();
    _meetingContactController.dispose();
    _taskNameController.dispose();
    _taskPlanController.dispose();
    _brideController.dispose();
    _groomController.dispose();
    _familyController.dispose();
    _weddingLocController.dispose();
    _weddingContactController.dispose();
    _virtualTitleController.dispose();
    _virtualPlatformController.dispose();
    _virtualLinkController.dispose();
    _virtualContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Meeting'),
              Tab(text: 'Task'),
              Tab(text: 'Wedding'),
              Tab(text: 'Virtual Meeting'),
            ],
          ),
          Container(
            height: 450,
            padding: const EdgeInsets.all(20),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMeetingForm(),
                _buildTaskForm(),
                _buildWeddingForm(),
                _buildVirtualMeetingForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingForm() {
    return _ScrollableForm(
      children: [
        _buildTextField(label: 'Meeting Title', icon: Icons.title, controller: _meetingTitleController),
        const SizedBox(height: 16),
        _buildTextField(label: 'With Whom', icon: Icons.person_outline, controller: _meetingWhoController),
        const SizedBox(height: 16),
        _buildTextField(label: 'Location', icon: Icons.location_on_outlined, controller: _meetingLocController),
        const SizedBox(height: 16),
        _buildTimePickerField(
          label: 'Time', 
          selectedTime: _meetingTime,
          onTimeSelected: (t) => setState(() => _meetingTime = t),
        ),
        const SizedBox(height: 16),
        _buildContactField(label: 'Contact Person', controller: _meetingContactController),
        const SizedBox(height: 24),
        _buildSubmitButton(widget.eventToEdit != null ? 'Update Meeting' : 'Schedule Meeting', () {
          if (_meetingTitleController.text.isEmpty) return;
          final event = CalendarEvent(
            id: widget.eventToEdit?.id ?? '',
            type: EventType.meeting,
            title: _meetingTitleController.text,
            date: widget.selectedDate,
            description: 'With: ${_meetingWhoController.text}',
            location: _meetingLocController.text,
            time: _meetingTime,
            contactName: 'Contact', 
            contactNumber: _meetingContactController.text,
          );
          Navigator.pop(context, event);
        }),
      ],
    );
  }

  Widget _buildTaskForm() {
    return _ScrollableForm(
      children: [
        _buildTextField(label: 'Task Name', icon: Icons.check_circle_outline, controller: _taskNameController),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'What is your plan?', 
          icon: Icons.notes, 
          maxLines: 4,
          controller: _taskPlanController,
        ),
        const SizedBox(height: 24),
        _buildSubmitButton(widget.eventToEdit != null ? 'Update Task' : 'Add Task', () {
          if (_taskNameController.text.isEmpty) return;
          final event = CalendarEvent(
            id: widget.eventToEdit?.id ?? '',
            type: EventType.task,
            title: _taskNameController.text,
            date: widget.selectedDate,
            description: _taskPlanController.text,
          );
          Navigator.pop(context, event);
        }),
      ],
    );
  }

  Widget _buildWeddingForm() {
    return _ScrollableForm(
      children: [
        InkWell(
          onTap: _showMultiSelectDialog,
          child: InputDecorator(
            decoration: _inputDecoration('Function Type', Icons.event_available),
            child: Text(
              _weddingFunctions.isEmpty ? 'Select Function(s)' : _weddingFunctions.join(', '),
              style: TextStyle(
                color: _weddingFunctions.isEmpty ? Colors.grey[600] : AppColors.textDark,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildTextField(label: 'Bride Name', icon: Icons.female, controller: _brideController),
            const SizedBox(height: 16),
            _buildTextField(label: 'Groom Name', icon: Icons.male, controller: _groomController),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(label: 'Family/Surname', icon: Icons.people_outline, controller: _familyController),
        const SizedBox(height: 16),
        _buildTextField(label: 'Location', icon: Icons.location_city, controller: _weddingLocController),
        const SizedBox(height: 16),
        _buildTimePickerField(
          label: 'Time',
          selectedTime: _weddingTime,
          onTimeSelected: (t) => setState(() => _weddingTime = t),
        ),
        const SizedBox(height: 16),
        _buildContactField(label: 'Contact Person', controller: _weddingContactController),
        const SizedBox(height: 24),
        _buildSubmitButton(widget.eventToEdit != null ? 'Update Event' : 'Save Event', () {
          if (_brideController.text.isEmpty && _groomController.text.isEmpty) return;
          final functionString = _weddingFunctions.join(', ');
          final event = CalendarEvent(
            id: widget.eventToEdit?.id ?? '',
            type: EventType.wedding,
            title: '$functionString: ${_brideController.text} & ${_groomController.text}',
            date: widget.selectedDate,
            location: _weddingLocController.text,
            time: _weddingTime,
            contactNumber: _weddingContactController.text,
            subFunction: functionString,
            brideName: _brideController.text,
            groomName: _groomController.text,
            familyName: _familyController.text,
          );
          Navigator.pop(context, event);
        }),
      ],
    );
  }

  void _showMultiSelectDialog() async {
    final List<String> options = ['Wedding', 'Engagement', 'Sangeet', 'Haldi', 'Reception'];
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Functions'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: options.map((option) {
                    final isChecked = _weddingFunctions.contains(option);
                    return CheckboxListTile(
                      value: isChecked,
                      title: Text(option),
                      activeColor: AppColors.primary,
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            _weddingFunctions.add(option);
                          } else {
                            _weddingFunctions.remove(option);
                          }
                        });
                        // Update parent widget to reflect changes live in the background text
                        setState(() {}); 
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVirtualMeetingForm() {
    return _ScrollableForm(
      children: [
        _buildTextField(label: 'Title', icon: Icons.video_camera_front_outlined, controller: _virtualTitleController),
        const SizedBox(height: 16),
        _buildTextField(label: 'Platform (Zoom/Meet)', icon: Icons.computer, controller: _virtualPlatformController),
        const SizedBox(height: 16),
        _buildTextField(label: 'Meeting Link', icon: Icons.link, controller: _virtualLinkController),
        const SizedBox(height: 16),
        _buildTimePickerField(
          label: 'Time',
          selectedTime: _virtualTime,
          onTimeSelected: (t) => setState(() => _virtualTime = t),
        ),
        const SizedBox(height: 16),
        _buildContactField(label: 'Contact Person', controller: _virtualContactController),
        const SizedBox(height: 24),
        _buildSubmitButton(widget.eventToEdit != null ? 'Update Virtual Meeting' : 'Schedule Virtual Meeting', () {
          if (_virtualTitleController.text.isEmpty) return;
          final event = CalendarEvent(
            id: widget.eventToEdit?.id ?? '',
            type: EventType.virtualMeeting,
            title: _virtualTitleController.text,
            date: widget.selectedDate,
            platformLink: _virtualLinkController.text,
            description: 'Platform: ${_virtualPlatformController.text}',
            time: _virtualTime,
            contactNumber: _virtualContactController.text,
          );
          Navigator.pop(context, event);
        }),
      ],
    );
  }

  // --- Components ---

  Widget _buildTextField({
    required String label, 
    required IconData icon, 
    int maxLines = 1,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TimeOfDay? selectedTime,
    required Function(TimeOfDay) onTimeSelected,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context, 
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          onTimeSelected(time);
        }
      },
      child: IgnorePointer(
        child: TextFormField(
          decoration: _inputDecoration(label, Icons.access_time),
          controller: TextEditingController(
            text: selectedTime?.format(context) ?? '',
          ),
        ),
      ),
    );
  }

  Widget _buildContactField({required String label, required TextEditingController controller}) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(label, Icons.phone_outlined),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              _makePhoneCall(controller.text);
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: AppColors.success.withOpacity(0.1),
            foregroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.call),
          tooltip: 'Call Now',
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
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
}

class _ScrollableForm extends StatelessWidget {
  final List<Widget> children;
  const _ScrollableForm({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
