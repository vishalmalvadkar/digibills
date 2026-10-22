import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/embedded_calendar.dart';
import '../widgets/license_scope.dart';
import '../widgets/license_celebration_card.dart'; // NEW
import '../models/bill_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../models/license_model.dart'; // NEW: Required for typing in methods
import '../models/calendar_event.dart';
import '../services/bills_service.dart';
import '../services/settings_service.dart';
import '../utils/dashboard_calculator.dart';
import '../utils/report_calculator.dart';
import '../utils/report_type.dart';
import '../theme/app_colors.dart';
import '../services/calendar_service.dart';
import '../services/user_service.dart';
import 'notification_center_screen.dart';
import 'quotes_list_screen.dart';
import 'inventory_screen.dart';
import 'dashboard/payment_reminders_card.dart';
import 'create_bill_screen.dart'; // NEW
import 'purchases/create_purchase_screen.dart'; // NEW
import 'bills_screen.dart'; // Ensure this is imported for navigation
import '../services/notification_service.dart';
import '../services/expense_service.dart';
import '../models/expense_model.dart';
import 'dashboard/dashboard_zero_state.dart';
import '../models/platform_config_model.dart'; // NEW
import '../services/platform_governance_service.dart'; // RESTORED
import '../providers/shell_provider.dart'; // NEW
import '../utils/responsive.dart';
import '../core/responsive/breakpoints.dart';
import '../core/responsive/max_width_container.dart';
import '../l10n/app_localizations.dart'; // NEW

import '../services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _tenantId;
  UserModel? _currentUser;
  AppSettings? _appSettings;
  bool _isLoading = true; // Restored
  bool _pwaUpdateAvailable = false;
  
  Stream<List<BillModel>> _billsStream = Stream.value([]);
  Stream<List<ExpenseModel>> _expensesStream = Stream.value([]);
  Stream<AppSettings> _settingsStream = Stream.value(AppSettings.defaultSettings());
  StreamSubscription<AppSettings>? _settingsSub; // NEW
  Stream<List<Map<String, dynamic>>> _notificationStream = Stream.value([]);
  Stream<List<CalendarEvent>> _calendarStream = Stream.value([]);

  SharedPreferences? _prefs; // Class member
  bool? _previousReadOnlyMode; // Track for transition triggers
  bool _showCelebrationOverlay = false; // Declarative Overlay State

  @override
  void initState() {
    super.initState();
    _billsStream = BillsService().streamBills();
    _expensesStream = ExpenseService().streamExpenses();
    _settingsStream = SettingsService().streamSettings();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final isReadOnly = LicenseScope.isReadOnlyMode(context);
    final license = LicenseScope.licenseOf(context);

    // Transition Check: ReadOnly (Expired) -> Active (Renewed)
    // This handles the "Banner Removed" scenario immediately.
    if (_previousReadOnlyMode == true && isReadOnly == false) {
       if (license != null && _prefs != null) {
          debugPrint('Dashboard: ReadOnly -> Active transition. Attempting celebration.');
          _attemptCelebration(license, force: true);
       }
    }
    
    _previousReadOnlyMode = isReadOnly;

    if (_prefs != null && license != null) {
      _checkLicenseRenewal(license);
    }
  }

  void _attemptCelebration(LicenseModel license, {bool force = false}) {
    if (!mounted || _prefs == null) return;

    final nowStr = license.endDate.toIso8601String();
    final lastTriggered = _prefs!.getString('last_celebration_trigger');

    if (force || lastTriggered != nowStr) {
       debugPrint('Triggering License Renewal Celebration (Card): ${license.endDate}');
       _prefs!.setString('last_celebration_trigger', nowStr);
       _prefs!.setString('last_license_expiry', nowStr);

       setState(() {
         _showCelebrationOverlay = true;
       });

       // Auto-dismiss after 10 seconds
       Timer(const Duration(seconds: 10), () {
           if (mounted && _showCelebrationOverlay) {
               setState(() => _showCelebrationOverlay = false);
           }
       });
    } else {
      _prefs!.setString('last_license_expiry', nowStr);
    }
  }

  void _checkLicenseRenewal(LicenseModel? license) {
    if (license == null || _prefs == null) return;
    
    final currentExpiry = license.endDate;
    final storedExpiryStr = _prefs!.getString('last_license_expiry');
    final nowStr = currentExpiry.toIso8601String();

    // 1. First Run -> Silent Sync
    if (storedExpiryStr == null) {
      _prefs!.setString('last_license_expiry', nowStr);
      return;
    }

    final storedExpiry = DateTime.parse(storedExpiryStr);

    // 2. Check for Renewal (Increase in Date compared to stored)
    if (currentExpiry.difference(storedExpiry).inSeconds > 0) {
      _attemptCelebration(license);
    } else {
      // Sync strictly
      _prefs!.setString('last_license_expiry', nowStr);
    }
  }

  Future<void> _loadAllData() async {
    final user = AuthService().currentUser ?? Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        // Parallel Fetch
        final results = await Future.wait([
          UserService().getUser(user.id),
          SettingsService().fetchSettings(),
          SharedPreferences.getInstance(), // NEW: Fetch prefs
        ]);

        final userModel = results[0] as UserModel?;
        final settings = results[1] as AppSettings?;
        final prefs = results[2] as SharedPreferences; // NEW

        if (mounted) {
          setState(() {
            _currentUser = userModel;
            _appSettings = settings;
            _prefs = prefs; // Store class member
            
            if (userModel != null) {
              _tenantId = userModel.tenantId;

              // Initial Check using fetched user model
              _checkLicenseRenewal(userModel.license);
            }
            
            // Initialize Streams after we have user and tenant context
            final uid = user.id;
            if (_currentUser?.role == 'client') {
              _billsStream = BillsService().streamUserRelevantBills(uid);
            } else if (_currentUser?.role == 'staff') {
              // Staff only see their own bills
              _billsStream = BillsService().streamBills(staffId: uid); 
            } else {
               _billsStream = BillsService().streamBills();
            }
            
            _settingsStream = SettingsService().streamSettings();
            _settingsSub?.cancel();
            _settingsSub = _settingsStream.listen((s) {
              if (mounted) setState(() => _appSettings = s);
            });
            
            _expensesStream = ExpenseService().streamExpenses(); // NEW
            
            if (_tenantId != null && _tenantId!.isNotEmpty) {
              try {
                _notificationStream = Supabase.instance.client
                    .from('notifications')
                    .stream(primaryKey: ['id'])
                    .eq('tenant_id', _tenantId!);
              } catch (_) {
                _notificationStream = Stream.value([]);
              }
              
              try {
                _calendarStream = CalendarService().streamEvents(tenantId: _tenantId!);
              } catch (_) {
                _calendarStream = Stream.value([]);
              }
            } else {
              _notificationStream = Stream.value([]);
              _calendarStream = Stream.value([]);
            }

            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading dashboard data: $e');
        if (mounted) {
          setState(() {
            _billsStream = BillsService().streamBills();
            _expensesStream = ExpenseService().streamExpenses();
            _settingsStream = SettingsService().streamSettings();
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _billsStream = BillsService().streamBills();
          _expensesStream = ExpenseService().streamExpenses();
          _settingsStream = SettingsService().streamSettings();
          _isLoading = false;
        });
      }
    }
  }
  
  // _seedSystemUpdateNotification removed as we now use real detection.

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<BillModel>>(
      stream: _billsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final isOfflineError = error.contains('RealtimeSubscribeException') || 
                                 error.contains('ClientException') || 
                                 error.contains('Failed to fetch');
          
          return Scaffold(
             body: Center(
               child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isOfflineError ? Icons.cloud_off : Icons.error_outline, 
                       size: 48, color: AppColors.textGrey),
                  const SizedBox(height: 16),
                    Text(
                    isOfflineError 
                      ? "${AppLocalizations.of(context)?.offlineMode ?? 'Offline Mode'}\n${AppLocalizations.of(context)?.reconnectMessage ?? 'Reconnect to see latest data.'}" 
                      : "${AppLocalizations.of(context)?.error ?? 'Error'}: $error", 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAllData, 
                    child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                  ),
                ],
              ),
             ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bills = snapshot.data ?? [];
        
        return StreamBuilder<List<ExpenseModel>>(
          stream: _expensesStream,
          builder: (context, expSnapshot) {
            final expenses = expSnapshot.data ?? [];
            final summary = DashboardCalculator.calculate(bills, expenses);
            final currentLicense = LicenseScope.licenseOf(context);
            final bool hasInvoices = bills.isNotEmpty;


        return Column(
          children: [
            if (!Responsive.isDesktop(context)) ...[
              _buildHeader(context),
              _buildBusinessProfileSection(context),
            ],
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isDesktop(context) ? 1200 : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // GLOBAL ANNOUNCEMENT BANNER
                        const StandaloneAnnouncementBanner(),
                        const SizedBox(height: 32),

                        // License Celebration Card (Inline)
                        if (_showCelebrationOverlay && currentLicense != null) ...[
                           LicenseCelebrationCard(
                              planName: currentLicense.plan,
                              expiryDate: currentLicense.endDate,
                              onDismiss: () => setState(() => _showCelebrationOverlay = false),
                           ),
                           const SizedBox(height: 32),
                        ],

                        if (LicenseScope.isReadOnlyMode(context)) ...[
                           _buildRenewalBanner(context),
                           const SizedBox(height: 32),
                        ],


                        // 1. Summary Cards (Always show if invoices exist)
                        if (hasInvoices) ...[
                           _summaryCards(context, summary),
                           const SizedBox(height: 32),
                        ],

                        // 2. Shortcuts (Create Invoice, Sales Return) - Moved Up
                        if (!LicenseScope.isReadOnlyMode(context)) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final canCreateBills = _currentUser?.role != 'staff' || (_currentUser?.permissions.contains('create_bills') ?? false);
                              final canManageReturns = _currentUser?.role != 'staff' || (_currentUser?.permissions.contains('manage_returns') ?? false);
                              final isSmall = constraints.maxWidth < 420;

                              final invoiceCard = canCreateBills
                                  ? _buildShortcutCard(
                                      context,
                                      title: AppLocalizations.of(context)?.createInvoice ?? 'Create Invoice',
                                      icon: Icons.add_circle_outline,
                                      color1: const Color(0xFF11998e),
                                      color2: const Color(0xFF38ef7d),
                                      onTap: () {
                                        Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (_) => const CreateBillScreen())
                                        ).then((_) => _loadAllData());
                                      },
                                    )
                                  : null;

                              final purchaseCard = _buildShortcutCard(
                                context,
                                title: 'Purchase',
                                icon: Icons.shopping_cart_outlined,
                                color1: const Color(0xFF614385),
                                color2: const Color(0xFF516395),
                                onTap: () {
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (_) => const CreatePurchaseScreen())
                                  ).then((_) => _loadAllData());
                                },
                              );

                              final returnCard = canManageReturns
                                  ? _buildShortcutCard(
                                      context,
                                      title: AppLocalizations.of(context)?.salesReturn ?? 'Sales Return',
                                      icon: Icons.assignment_return_outlined,
                                      color1: const Color(0xFFFF416C),
                                      color2: const Color(0xFFFF4B2B),
                                      onTap: () {
                                        Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (_) => const BillsScreen(initialIndex: 3))
                                        );
                                      },
                                    )
                                  : null;

                              final activeCards = [
                                if (invoiceCard != null) invoiceCard,
                                purchaseCard,
                                if (returnCard != null) returnCard,
                              ];

                              if (isSmall) {
                                return Column(
                                  children: [
                                    for (int i = 0; i < activeCards.length; i++) ...[
                                      Row(children: [activeCards[i]]),
                                      if (i < activeCards.length - 1) const SizedBox(height: 10),
                                    ],
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  for (int i = 0; i < activeCards.length; i++) ...[
                                    activeCards[i],
                                    if (i < activeCards.length - 1) const SizedBox(width: 12),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],

                        // 3. Payment Reminders & Calendar - Moved Up
                        if (hasInvoices)
                          Responsive(
                            mobile: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PaymentRemindersCard(
                                  bills: bills,
                                  settings: _appSettings,
                                ),
                                const SizedBox(height: 32),
                                const EmbeddedCalendar(),
                              ],
                            ),
                            tablet: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: PaymentRemindersCard(
                                        bills: bills,
                                        settings: _appSettings,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    const Expanded(
                                      flex: 2,
                                      child: EmbeddedCalendar(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            desktop: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: PaymentRemindersCard(
                                        bills: bills,
                                        settings: _appSettings,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    const Expanded(
                                      flex: 2,
                                      child: EmbeddedCalendar(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                            const EmbeddedCalendar(),
                        const SizedBox(height: 32),


                        // 4. Advanced Analytics & Zero State - Moved Down
                        if (_currentUser?.role != 'staff' || (_currentUser?.permissions.contains('view_dashboard') ?? false)) ...[
                           if (!hasInvoices)
                              DashboardZeroState(onActionComplete: _loadAllData)
                           else ...[
                              EarningTrendSection(bills: bills),
                              const SizedBox(height: 32),
                              IncomeVsExpenseTrend(summary: summary),
                              const SizedBox(height: 32),
                              TopPerformanceSection(summary: summary),
                              const SizedBox(height: 32),
                              ArAgingAnalysis(summary: summary),
                              const SizedBox(height: 32),
                              TaxBreakupChart(summary: summary),
                           ],
                           const SizedBox(height: 32),
                        ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.noData ?? 'No Data',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    final displayName = _appSettings?.tenantName ?? AppLocalizations.of(context)?.loading ?? 'Loading...';
    
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icon/app_logo_header.png',
                      height: 40, // Slightly larger height for better resolution
                      filterQuality: FilterQuality.high, // Improve sharpness
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _notificationStream,
                builder: (context, notifSnapshot) {
                  return StreamBuilder<List<CalendarEvent>>(
                    stream: _calendarStream,
                    builder: (context, eventSnapshot) {
                       int count = 0;
                       if (notifSnapshot.hasData) {
                          count += notifSnapshot.data!
                              .where((data) => data['is_read'] != true)
                              .length;
                       }
                       if (eventSnapshot.hasData) {
                         final now = DateTime.now();
                         final today = DateTime(now.year, now.month, now.day);
                         
                         final unreadEvents = eventSnapshot.data!.where((e) {
                           final eDate = DateTime(e.date.year, e.date.month, e.date.day);
                           return !e.read && !eDate.isAfter(today); 
                         }).toList();
                         
                         count += unreadEvents.length;
                       }

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.textDark),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                                );
                              },
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_outlined, size: 28, color: AppColors.textDark),
                                  onPressed: () {
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                                     );
                                  },
                                ),
                                if (count > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                    }
                  );
                }
              ),
            ],
          ),
        );
  }

  Widget _buildBusinessProfileSection(BuildContext context) {
  final settings = _appSettings;
  if (settings == null) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.03),
      border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
    ),
    child: Row(
      children: [
        // Business Logo
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: settings.logoBase64 != null && settings.logoBase64!.isNotEmpty
                ? Image.memory(
                    base64Decode(settings.logoBase64!),
                    key: ValueKey(settings.logoBase64!), // Force rebuild on new logo
                    fit: BoxFit.contain,
                  )
                : const Icon(Icons.business, color: AppColors.textGrey, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        // Business Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.tenantName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(Icons.verified_user, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)?.activeBusiness ?? 'Active Business',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Settings Icon or Switch

      ],
    ),
  );
}



  Widget _buildRenewalBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Light Red background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF991B1B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.autorenew, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        AppLocalizations.of(context)?.renewLicense ?? "Renew Your License",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                          fontSize: 16,
                        ),
                      ),
                    Text(
                        AppLocalizations.of(context)?.renewLicenseMsg ?? "Tap below to send a renewal request to our team.",
                      style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleRenewalRequest(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(AppLocalizations.of(context)?.requestRenewal ?? "Request Renewal Now", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRenewalRequest(BuildContext context) async {
    if (_currentUser == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch client data for whatsapp number
      final clientData = await Supabase.instance.client
          .from('clients')
          .select('whatsapp_number')
          .eq('client_id', _currentUser!.uid)
          .maybeSingle();

      final whatsapp = clientData?['whatsapp_number'] ?? _currentUser!.uid;

      await NotificationService().sendRenewalRequest(
        uid: _currentUser!.uid,
        name: _currentUser!.name ?? 'User',
        email: _currentUser!.email ?? '',
        whatsapp: whatsapp,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.renewalSent ?? "Renewal request sent successfully! We will contact you soon."),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.renewalFailed(e) ?? "Failed to send request: $e"), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _summaryCards(BuildContext context, DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // On very compact mobile screens (< 380px), stack into a 1 or 2-column wrap
        // On standard screens, arrange in 3 columns
        final isVeryCompact = width < 380;

        final cards = [
          _card(AppLocalizations.of(context)?.totalRevenue ?? 'Total Revenue', summary.totalAmount, summary.totalBills, AppColors.primary),
          _card(AppLocalizations.of(context)?.paidCollections ?? 'Paid Collections', summary.paidAmount, summary.paidCount, AppColors.success),
          _card(AppLocalizations.of(context)?.pendingDues ?? 'Pending Dues', summary.pendingAmount, summary.pendingCount, AppColors.warning),
        ];

        if (isVeryCompact) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              Row(
                children: [
                  cards[1],
                  const SizedBox(width: 12),
                  cards[2],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            cards[0],
            const SizedBox(width: 12),
            cards[1],
            const SizedBox(width: 12),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _card(String title, double value, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$count Bills', 
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutCard(BuildContext context, {required String title, required IconData icon, required Color color1, required Color color2, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [color1, color2],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(20),
               boxShadow: [
                 BoxShadow(
                   color: color1.withOpacity(0.4),
                   blurRadius: 12,
                   offset: const Offset(0, 6),
                 ),
               ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _paidVsPendingBar(DashboardSummary summary) {
    if (summary.totalAmount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text(
            'Paid vs Pending',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        String subText = '';
                        if (value.toInt() == 0) {
                          text = 'Paid';
                          subText = '(${summary.paidCount})';
                        } else if (value.toInt() == 1) {
                          text = 'Pending';
                          subText = '(${summary.pendingCount})';
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              Text(
                                text,
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                subText,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                   BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: summary.paidAmount,
                        color: AppColors.success,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                   BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: summary.pendingAmount,
                        color: AppColors.warning,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget IncomeVsExpenseTrend({required DashboardSummary summary}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Income vs Expense",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            "Track your monthly profit trend",
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5000),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text("Month", style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < summary.monthlyProfitTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              summary.monthlyProfitTrend[index].label,
                              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text("Amount (₹)", style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value >= 1000) {
                          return Text('${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
                        }
                        return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income Line
                  LineChartBarData(
                    spots: summary.monthlyProfitTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.amount)).toList(),
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.success.withOpacity(0.1)),
                  ),
                  // Expense Line
                  LineChartBarData(
                    spots: summary.monthlyExpenseTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.amount)).toList(),
                    isCurved: true,
                    color: AppColors.warning,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.warning.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _chartLegend(AppColors.success, "Income"),
               const SizedBox(width: 20),
               _chartLegend(AppColors.warning, "Expense"),
            ],
          )
        ],
      ),
    );
  }


  Widget _chartLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ],
    );
  }

  Widget ArAgingAnalysis({required DashboardSummary summary}) {
    final agingData = summary.arAging;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Accounts Receivable Aging",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text("Distribution of pending payments by age", style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final keys = agingData.keys.toList();
                        if (value >= 0 && value < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(keys[value.toInt()].split(' ')[0], style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: AppColors.textGrey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: agingData.entries.toList().asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value,
                        color: e.value.key == '60+ Days' ? AppColors.error : (e.value.key == '0-15 Days' ? AppColors.success : AppColors.warning),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (agingData['60+ Days']! > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "₹${agingData['60+ Days']!.toStringAsFixed(0)} is overdue by 60+ days. Action required.",
                      style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget TaxBreakupChart({required DashboardSummary summary}) {
    final taxData = summary.gstLiability;
    final totalTax = taxData.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "GST Liability Breakup",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text("Estimates of output tax liability (Sales)", style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        value: taxData['IGST'] ?? 0,
                        title: '',
                        color: AppColors.primary,
                        radius: 20,
                      ),
                      PieChartSectionData(
                        value: taxData['CGST'] ?? 0,
                        title: '',
                        color: AppColors.secondary,
                        radius: 20,
                      ),
                      PieChartSectionData(
                        value: taxData['SGST'] ?? 0,
                        title: '',
                        color: AppColors.warning,
                        radius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _taxLegendItem(AppColors.primary, "IGST", taxData['IGST'] ?? 0),
                    const SizedBox(height: 12),
                    _taxLegendItem(AppColors.secondary, "CGST", taxData['CGST'] ?? 0),
                    const SizedBox(height: 12),
                    _taxLegendItem(AppColors.warning, "SGST", taxData['SGST'] ?? 0),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Liability", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("₹${totalTax.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
            ],
          )
        ],
      ),
    );
  }

  Widget _taxLegendItem(Color color, String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ],
        ),
        Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class StandaloneAnnouncementBanner extends StatefulWidget {
  const StandaloneAnnouncementBanner({super.key});

  @override
  State<StandaloneAnnouncementBanner> createState() => _StandaloneAnnouncementBannerState();
}

class _StandaloneAnnouncementBannerState extends State<StandaloneAnnouncementBanner> {
  String? _dismissedId;

  @override
  void initState() {
    super.initState();
    _loadDismissedId();
  }

  Future<void> _loadDismissedId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _dismissedId = prefs.getString('dismissed_announcement_id'));
      }
    } catch (e) {
      debugPrint('Error loading dismissed announcement id: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformConfigModel>(
      stream: PlatformGovernanceService().streamConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final config = snapshot.data!;
        final text = config.announcementText;
        if (text == null || text.isEmpty) return const SizedBox.shrink();

        final announcementId = config.updatedAt.toIso8601String();
        // If the ID matches what we dismissed, hide it locally
        if (_dismissedId == announcementId) return const SizedBox.shrink();

        Color bannerColor = AppColors.primary;
        IconData icon = Icons.info_outline;
        
        if (config.announcementType == 'warning') {
          bannerColor = Colors.orange;
          icon = Icons.warning_amber_rounded;
        } else if (config.announcementType == 'error') {
          bannerColor = Colors.red;
          icon = Icons.error_outline;
        } else if (config.announcementType == 'success') {
          bannerColor = Colors.green;
          icon = Icons.check_circle_outline;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: bannerColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerColor.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: bannerColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (config.announcementType ?? 'INFO').toUpperCase(),
                      style: TextStyle(
                        color: bannerColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: bannerColor.withOpacity(0.4), size: 18),
                onPressed: () async {
                  // Optimistic removal: hide immediately WITHOUT waiting for disk I/O
                  // This is the key to preventing the "hard refresh" feel
                  setState(() => _dismissedId = announcementId);
                  
                  // Persistent removal: save to disk in background
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('dismissed_announcement_id', announcementId);
                  } catch (e) {
                    debugPrint('Error saving dismissed announcement id: $e');
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class EarningTrendSection extends StatefulWidget {
  final List<BillModel> bills;
  const EarningTrendSection({super.key, required this.bills});

  @override
  State<EarningTrendSection> createState() => _EarningTrendSectionState();
}

class _EarningTrendSectionState extends State<EarningTrendSection> {
  ReportType _selectedType = ReportType.daily;

  @override
  Widget build(BuildContext context) {
    List<TimeSeriesPoint> reportData;
    switch (_selectedType) {
      case ReportType.monthly:
        reportData = ReportCalculator.monthly(widget.bills);
        break;
      case ReportType.yearly:
        reportData = ReportCalculator.yearly(widget.bills);
        break;
      case ReportType.daily:
      default:
        reportData = ReportCalculator.daily(widget.bills);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earning Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          _reportSelector(),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: reportData.isEmpty
                ? const Center(child: Text('No Data'))
                : _lineChart(reportData),
          ),
        ],
      ),
    );
  }

  Widget _reportSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _selectorButton('Daily', ReportType.daily),
          _selectorButton('Monthly', ReportType.monthly),
          _selectorButton('Yearly', ReportType.yearly),
        ],
      ),
    );
  }

  Widget _selectorButton(String label, ReportType type) {
    final isActive = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppColors.textDark : AppColors.textGrey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineChart(List<TimeSeriesPoint> data) {
    double maxY = 0;
    for (var point in data) {
      if (point.amount > maxY) maxY = point.amount;
    }
    if (maxY == 0) maxY = 1000;

    double interval = maxY / 5;
    if (interval == 0) interval = 100;

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.9),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '₹${barSpot.y.toInt()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.border.withOpacity(0.5),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();

                String text;
                if (value >= 1000000) {
                  text = '${(value / 1000000).toStringAsFixed(1)}M';
                } else if (value >= 1000) {
                  text = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  text = value.toInt().toString();
                }
                text = text.replaceAll('.0', '');

                return Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                if (data.length > 7 && index % 2 != 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    data[index].label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map(
                  (e) => FlSpot(
                    e.key.toDouble(),
                    e.value.amount,
                  ),
                )
                .toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopPerformanceSection extends StatefulWidget {
  final DashboardSummary summary;
  const TopPerformanceSection({super.key, required this.summary});

  @override
  State<TopPerformanceSection> createState() => _TopPerformanceSectionState();
}

class _TopPerformanceSectionState extends State<TopPerformanceSection> {
  bool _showCustomers = true;

  @override
  Widget build(BuildContext context) {
    final sortedCustomers = widget.summary.topCustomers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Customers = sortedCustomers.take(5).toList();

    final sortedProducts = widget.summary.topProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Products = sortedProducts.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Top Performance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              // Interaction: Toggles
              Row(
                children: [
                  _toggleButton(
                    title: "Customers",
                    isActive: _showCustomers,
                    onTap: () => setState(() => _showCustomers = true),
                  ),
                  const SizedBox(width: 8),
                  _toggleButton(
                    title: "Sellers",
                    isActive: !_showCustomers,
                    onTap: () => setState(() => _showCustomers = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Top contributors to your business growth", style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 24),
          
          _showCustomers 
            ? _buildList("TOP CUSTOMERS", top5Customers, AppColors.primary)
            : _buildList("BEST SELLERS", top5Products, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _toggleButton({required String title, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primary : Colors.transparent),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12, 
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : AppColors.textGrey
          ),
        ),
      ),
    );
  }

  Widget _buildList(String title, List<MapEntry<String, double>> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        if (items.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Center(child: Text("No data available", style: TextStyle(color: AppColors.textGrey, fontSize: 13))),
           )
        else
          ...items.map((e) => _performanceItem(e.key, e.value)),
      ],
    );
  }

  Widget _performanceItem(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name, 
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(0)}", 
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)
          ),
        ],
      ),
    );
  }
}
