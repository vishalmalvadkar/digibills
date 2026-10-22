import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin/client_list_screen.dart'; // NEW


class SuperAdminHomeScreen extends StatelessWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ // Removed const from here
             const Icon(Icons.admin_panel_settings, size: 64, color: Colors.indigo),
             const SizedBox(height: 16),
             const Text(
              'Welcome, Super Admin',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 32),
             ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientListScreen()),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('Manage Clients'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
             ),
             const SizedBox(height: 16),
             const Text(
               'Use this panel to manage client licenses and access.',
               style: TextStyle(color: Colors.grey),
             ),
          ],
        ),
      ),
    );
  }
}
