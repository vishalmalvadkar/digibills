import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'bills_screen.dart';
import 'calendar_screen.dart';
import 'account_screen.dart';
import 'settings_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/license_scope.dart';
import '../widgets/pwa_update_banner.dart'; // NEW
import '../services/pwa_update_service.dart'; // NEW
import '../services/notification_service.dart';
import 'creation_menu_screen.dart'; // NEW import
import '../utils/responsive.dart';
import '../widgets/desktop_top_bar.dart';
import '../providers/shell_provider.dart';
import '../l10n/app_localizations.dart'; // NEW
import 'package:provider/provider.dart';
import '../models/user_model.dart'; // NEW
import '../services/user_service.dart'; // NEW
import 'package:supabase_flutter/supabase_flutter.dart'; // NEW

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ShellState _shellState = ShellState();
  final GlobalKey<NavigatorState> _desktopNavigatorKey = GlobalKey<NavigatorState>();
  UserModel? _currentUser; // NEW

  final List<Widget> _screens = [ 
    const DashboardScreen(),
    const BillsScreen(),
    const CalendarScreen(),
    const AccountScreen(),
    const SettingsScreen(),
  ];

  List<String> _titles(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.dashboard,
      l10n.transactions, 
      l10n.calendar,
      l10n.account,
      l10n.settings,
    ];
  }

  List<int> _validIndices = [0, 1, 2, 3, 4]; // Default all visible

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize PWA Update Service
    PwaUpdateService().init();
    
    _loadUser(); 

    // Check for notifications on app launch
     WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationService().checkNotifications(context);
        _updateShellState(_validIndices[_currentIndex]);
      }
    });
  }
  
  Future<void> _loadUser() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final user = await UserService().getUser(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _calculateValidIndices();
        });
      }
    }
  }

  void _calculateValidIndices() {
    _validIndices = [0, 1, 2]; // Dashboard, Bills, Calendar always visible (Calendar access controlled inside)
    
    final isStaff = _currentUser?.role == 'staff';
    final p = _currentUser?.permissions ?? [];

    // Account Tab (Index 3)
    final canViewReports = !isStaff || p.contains('view_reports');
    final canViewExpenses = !isStaff || p.contains('view_expenses');
    if (canViewReports || canViewExpenses) {
      _validIndices.add(3);
    }

    // Settings Tab (Index 4)
    final canViewSettings = !isStaff || p.contains('manage_settings');
    if (canViewSettings) {
      _validIndices.add(4);
    }
    
    // Reset index if out of bounds
    if (_currentIndex >= _validIndices.length) {
      _currentIndex = 0;
    }
    
    // Update shell state for current valid index
    _updateShellState(_validIndices[_currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false, 
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  
                  _updateShellState(_validIndices[index]);

                  if (_desktopNavigatorKey.currentState != null) {
                    _desktopNavigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                backgroundColor: Colors.white,
                elevation: 5,
                extended: Responsive.isDesktop(context),
                leading: Column(
                  children: [
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/icon/app_logo_header.png',
                      height: 40,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
                trailing: Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'DigiInvi V1.0',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'DigiWebia',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                destinations: _validIndices.map((originalIndex) {
                   switch (originalIndex) {
                     case 0: return NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text(AppLocalizations.of(context)!.dashboard),
                      );
                     case 1: return NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text(AppLocalizations.of(context)!.transactions), 
                      );
                     case 2: return NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: Text(AppLocalizations.of(context)!.calendar),
                      );
                     case 3: return NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: Text(AppLocalizations.of(context)!.account),
                      );
                     case 4: return NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text(AppLocalizations.of(context)!.settings),
                      );
                     default: return NavigationRailDestination(icon: SizedBox(), label: Text(''));
                   }
                }).toList(),
                selectedIconTheme: const IconThemeData(color: AppColors.primary),
                selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                unselectedIconTheme: const IconThemeData(color: AppColors.textGrey),
                unselectedLabelTextStyle: const TextStyle(color: AppColors.textGrey),
              ),
            Expanded(
              child: ChangeNotifierProvider.value(
                value: _shellState,
                child: Column(
                  children: [
                    if (!isMobile) 
                      DesktopTopBar(
                        onNavigateToSettings: () {
                          // Check if settings is in valid indices
                          final settingsIndex = _validIndices.indexOf(4);
                          if (settingsIndex != -1) {
                            setState(() => _currentIndex = settingsIndex);
                            _updateShellState(4);
                            if (_desktopNavigatorKey.currentState != null) {
                              _desktopNavigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
                            }
                          }
                        },
                      ),
                  const PwaUpdateBanner(),
                  if (LicenseScope.isReadOnlyMode(context))
                    _buildReadOnlyBanner(),
                    
                  Expanded(
                    child: isMobile 
                      ? IndexedStack(
                          index: _validIndices[_currentIndex], // Map visual index to actual screen index
                          children: _screens, // Contains ALL screens
                        )
                      : Navigator(
                          key: _desktopNavigatorKey,
                          onGenerateRoute: (settings) {
                            return MaterialPageRoute(
                              builder: (context) => IndexedStack(
                                index: _validIndices[_currentIndex],
                                children: _screens,
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    floatingActionButton: isMobile && !LicenseScope.isReadOnlyMode(context) && (_currentUser?.role != 'staff' || (_currentUser?.permissions.contains('create_bills') ?? false))
          ? SizedBox(
              height: 56, 
              width: 56,
              child: FloatingActionButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreationMenuScreen(),
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: isMobile ? Container( 
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.1),
               blurRadius: 20,
               spreadRadius: 0,
               offset: const Offset(0, -5),
             ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0, 
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 if (_validIndices.contains(0)) _buildNavItem(_validIndices.indexOf(0), Icons.dashboard_outlined, Icons.dashboard, AppLocalizations.of(context)!.dashboard),
                 if (_validIndices.contains(1)) _buildNavItem(_validIndices.indexOf(1), Icons.receipt_long_outlined, Icons.receipt_long, AppLocalizations.of(context)!.transactions), 
                 const SizedBox(width: 40), 
                 if (_validIndices.contains(3)) _buildNavItem(_validIndices.indexOf(3), Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, AppLocalizations.of(context)!.account),
                 if (_validIndices.contains(4)) _buildNavItem(_validIndices.indexOf(4), Icons.settings_outlined, Icons.settings, AppLocalizations.of(context)!.settings),
              ],
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF991B1B), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.licenseExpired,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateShellState(int index) {
    // Only update if on desktop
    if (!Responsive.isDesktop(context)) return;

    final title = _titles(context)[index];
    List<Widget> actions = [];

    // Define actions based on index
    if (index == 1) { // Transactions
      if (!LicenseScope.isReadOnlyMode(context)) {
        actions = [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreationMenuScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 20),
            label: Text(AppLocalizations.of(context)!.createNew),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ];
      }
    }

    _shellState.update(title: title, actions: actions);
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        _updateShellState(index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textGrey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
             if (isSelected) 
              Container(
                 margin: const EdgeInsets.only(top: 2),
                 width: 4,
                 height: 4,
                 decoration: const BoxDecoration(
                   color: AppColors.primary,
                   shape: BoxShape.circle,
                 ),
              ),
          ],
        ),
      ),
    );
  }
}

