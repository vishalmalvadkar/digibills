import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'dart:convert'; // NEW
import '../models/settings_model.dart';
import '../services/settings_service.dart'; // NEW
import 'admin/admin_dashboard_tab.dart';
import 'admin/admin_clients_tab.dart';
import 'admin/admin_licenses_tab.dart';
import 'admin/admin_governance_tab.dart'; // NEW
import 'admin/admin_settings_tab.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const AdminDashboardTab(),
    const AdminClientsTab(),
    const AdminLicensesTab(),
    const AdminGovernanceTab(), // NEW
    const AdminSettingsTab(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Clients',
    'Licenses',
    'Governance', // NEW
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: StreamBuilder<AppSettings>(
          stream: SettingsService().streamSettings(),
          builder: (context, snapshot) {
            String appName = 'DigiInvi Admin';
            String? logo;
            double w = 40;
            double h = 40;

            if (snapshot.hasData) {
              final s = snapshot.data!;
              if (s.tenantName.isNotEmpty) appName = s.tenantName;
              logo = s.logoBase64;
              w = s.logoWidth > 0 ? s.logoWidth : 40;
              h = s.logoHeight > 0 ? s.logoHeight : 40;
            }

            return Row(
              children: [
                if (logo != null && logo.isNotEmpty)
                   Image.memory(base64Decode(logo), width: w, height: h, fit: BoxFit.contain)
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user, color: AppColors.primary, size: 24),
                  ),
                const SizedBox(width: 12),
                Text(
                  appName,
                  style: const TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white, // Requirement: White AppBar
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black), // Requirement: Black icons
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textGrey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Clients',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_outlined),
              activeIcon: Icon(Icons.verified),
              label: 'Licenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel),
              label: 'Governance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
