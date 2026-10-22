import 'package:flutter/material.dart';
import '../../../../models/staff_model.dart';
import '../../../../services/staff_service.dart';
import '../../../../theme/app_colors.dart'; // NEW
import 'add_edit_staff_screen.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final StaffService _staffService = StaffService();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      backgroundColor: AppColors.background, // Official background
      body: StreamBuilder<List<StaffModel>>(
        stream: _staffService.streamStaff(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
           if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final staffList = snapshot.data ?? [];

          return Scaffold(
             backgroundColor: Colors.transparent,
             floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Staff'),
              onPressed: () {
                if (staffList.length >= 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Limit reached: You can add up to 2 staff members only.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditStaffScreen()),
                  );
                }
              },
            ),
            body: staffList.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: AppColors.textGrey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No staff members added yet.',
                        style: TextStyle(fontSize: 18, color: AppColors.textDark.withOpacity(0.7), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Invite Staff" to add complete team members.',
                         textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(staff.email, style: const TextStyle(color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (staff.status == 'pending')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Pending', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                  ),
                                if (staff.status == 'active')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Active', style: TextStyle(fontSize: 10, color: Colors.green)),
                                  ),
                              ],
                            )
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditStaffScreen(staff: staff),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ), // ListView.builder
          ); // Scaffold
        },
      ), // StreamBuilder
    ); // Scaffold
  }
}
