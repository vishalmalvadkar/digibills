import 'package:flutter/material.dart';


enum EventType {
  meeting,
  task,
  wedding,
  virtualMeeting,
}

class CalendarEvent {
  final String id;
  final EventType type;
  final String title;
  final DateTime date;
  
  // Optional details based on type
  final String? description;
  final String? location;
  final String? contactName;
  final String? contactNumber;
  final TimeOfDay? time;
  final String? platformLink; // For virtual meetings
  
  // Wedding specific
  final String? subFunction; // Wedding, Sangeet, etc.
  final String? brideName;
  final String? groomName;
  final String? familyName;
  
  // NEW: Tenant Isolation & Read Status
  final String? tenantId;

  final bool read;
  final DateTime createdAt; // NEW for sorting

  CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.description,
    this.location,
    this.contactName,
    this.contactNumber,
    this.time,
    this.platformLink,
    this.subFunction,
    this.brideName,
    this.groomName,
    this.familyName,
    this.tenantId,
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color {
    switch (type) {
      case EventType.meeting:
        return Colors.blue;
      case EventType.task:
        return Colors.green;
      case EventType.wedding:
        return Colors.purple;
      case EventType.virtualMeeting:
        return Colors.orange;
    }
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    TimeOfDay? parsedTime;
    if (map['time'] != null) {
      final parts = (map['time'] as String).split(':');
      if (parts.length == 2) {
        parsedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }

    return CalendarEvent(
      id: map['id'] ?? '',
      type: EventType.values.firstWhere((e) => e.name == map['type'], orElse: () => EventType.task),
      title: map['title'] ?? '',
      
      date: map['date'] != null 
          ? DateTime.tryParse(map['date'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
          
      description: map['description'],
      location: map['location'],
      contactName: map['contact_name'] ?? map['contactName'],
      contactNumber: map['contact_number'] ?? map['contactNumber'],
      time: parsedTime,
      platformLink: map['platform_link'] ?? map['platformLink'],
      subFunction: map['sub_function'] ?? map['subFunction'],
      brideName: map['bride_name'] ?? map['brideName'],
      groomName: map['groom_name'] ?? map['groomName'],
      familyName: map['family_name'] ?? map['familyName'],
      tenantId: map['tenant_id'] ?? map['tenantId'],
      read: map['is_read'] ?? map['read'] ?? false,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal()
          : null,
    );
  }



  Map<String, dynamic> toMap() {
    return {
      'id': id, // Optional
      'type': type.name,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'location': location,
      'contact_name': contactName,
      'contact_number': contactNumber,
      'time': time != null ? '${time!.hour}:${time!.minute}' : null,
      'platform_link': platformLink,
      'sub_function': subFunction,
      'bride_name': brideName,
      'groom_name': groomName,
      'family_name': familyName,
      'tenant_id': tenantId,
      'is_read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
