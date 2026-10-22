import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'package:media_store_plus/media_store_plus.dart';

import 'theme/app_colors.dart';
import 'utils/snackbar_helper.dart';
import 'utils/notification_helper.dart';
import 'services/connectivity_service.dart';
import 'services/api_client.dart';
import 'screens/no_internet_screen.dart';

import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/public/public_quote_view_screen.dart';
import 'screens/public/public_po_view_screen.dart';
import 'screens/public/public_credit_note_view_screen.dart';
import 'screens/public/public_bill_view_screen.dart';

import 'models/user_model.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'services/security_service.dart';
import 'screens/lock_screen.dart';
import 'models/platform_config_model.dart';
import 'services/platform_governance_service.dart';
import 'screens/access_denied_screen.dart';
import 'screens/super_admin_shell.dart';
import 'services/license_service.dart';
import 'widgets/license_scope.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'l10n/app_localizations.dart'; 
import 'package:provider/provider.dart';
import 'providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && Platform.isAndroid) {
    MediaStore.appFolder = "DigiInvi";
    await MediaStore.ensureInitialized();
    await NotificationHelper.initialize();
  }
  await ApiClient().init();

  try {
    await Supabase.initialize(
      url: 'https://homasymduztmrcuqvuqm.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhvbWFzeW1kdXp0bXJjdXF2dXFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4ODY1ODQsImV4cCI6MjA4NDQ2MjU4NH0.BJPLe4KDCFQ4P9-B80tCAca2pWA-BAKZUyDV1NfoL2A',
    );

    // Firebase (Commented out if causing web hangs without scripts)
    /*
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyA2nluNus_S6UE3ouheG1vaccCwQDRdqH0",
        authDomain: "digibills-c97a9.firebaseapp.com",
        projectId: "digibills-c97a9",
        storageBucket: "digibills-c97a9.firebasestorage.app",
        messagingSenderId: "410628341242",
        appId: "1:410628341242:web:f607a5db1e81b5f388f843",
      ),
    );
    */
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const DigiBillsApp(),
    ),
  );

  if (kIsWeb) {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      try {
        final splash = html.document.getElementById('splash');
        if (splash != null) splash.remove();

        final loader = html.document.getElementsByClassName('loading');
        if (loader.isNotEmpty) loader.first.remove();

        html.document.body?.style.background = 'transparent';
        html.document.documentElement?.style.background = 'transparent';

        if (timer.tick > 20) timer.cancel();
      } catch (e) {
        // Ignore
      }
    });
  }
}

class DigiBillsApp extends StatelessWidget {
  const DigiBillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize Connectivity Service
    ConnectivityService().initialize();

    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'DigiInvi',
          scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates, 
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              surface: Colors.white,
              background: Colors.white,
            ),
            fontFamily: 'Roboto',
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          builder: (context, child) {
            return StreamBuilder<ConnectionStatus>(
              stream: ConnectivityService().statusStream,
              initialData: ConnectivityService().currentStatus,
              builder: (context, snapshot) {
                final status = snapshot.data ?? ConnectionStatus.online;
                if (status == ConnectionStatus.offline) {
                  return const NoInternetScreen();
                }
                return child!;
              },
            );
          },
          initialRoute: '/',
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final path = settings.name ?? '';

    if (path.contains('view-bill')) {
      final id = Uri.parse(path).queryParameters['id'] ?? '';
      return MaterialPageRoute(builder: (_) => PublicBillViewScreen(billId: id));
    }
    if (path.contains('view-quote')) {
      final id = Uri.parse(path).queryParameters['id'] ?? '';
      return MaterialPageRoute(builder: (_) => PublicQuoteViewScreen(quoteId: id));
    }
    if (path.contains('view-po')) {
      final id = Uri.parse(path).queryParameters['id'] ?? '';
      return MaterialPageRoute(builder: (_) => PublicPOViewScreen(poId: id));
    }
    if (path.contains('view-return')) {
      final id = Uri.parse(path).queryParameters['id'] ?? '';
      return MaterialPageRoute(builder: (_) => PublicCreditNoteViewScreen(noteId: id));
    }

    return MaterialPageRoute(
      builder: (_) => StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        initialData: AuthService().currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Authentication Error: ${snapshot.error}')),
            );
          }
          final user = snapshot.data;
          if (user != null) return UserRoleGate(user: user);
          return const LoginScreen();
        },
      ),
    );
  }
}

class SecurityGate extends StatefulWidget {
  final Widget child;
  const SecurityGate({super.key, required this.child});
  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate> {
  final _securityService = SecurityService();
  bool _isLocked = true;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final hasPin = await _securityService.isPinSet();
    final isEnabled = await _securityService.isPinEnabled();
    setState(() {
      _isLocked = hasPin && isEnabled;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_isLocked) {
      return LockScreen(
        mode: LockScreenMode.verify,
        onSuccess: () => setState(() => _isLocked = false),
      );
    }
    return widget.child;
  }
}

class UserRoleGate extends StatefulWidget {
  final User user;
  const UserRoleGate({super.key, required this.user});
  @override
  State<UserRoleGate> createState() => _UserRoleGateState();
}

class _UserRoleGateState extends State<UserRoleGate> {
  final UserService _userService = UserService();
  Future<UserModel>? _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _userService.syncUser(widget.user).then((user) {
      PlatformGovernanceService().auditUser(user.uid);
      return user;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          // Show strict Access Denied for any sync errors (Deleted/Suspended)
          return AccessDeniedScreen(
             message: snapshot.error.toString().replaceAll('Exception: ', ''),
          );
        }
        if (snapshot.hasData) {
          final userModel = snapshot.data!;
          if (userModel.role == 'superAdmin') return const SuperAdminShell();
          if (userModel.role == 'guest') return const AccessDeniedScreen();
          
          return PlatformGate(
            child: StreamBuilder<UserModel?>(
              stream: _userService.streamUser(userModel.uid),
              builder: (context, snapshot) {
                final liveUser = snapshot.data ?? userModel;
                final isReadOnly = !LicenseService().isLicenseValid(liveUser);
                return LicenseScope(
                  isReadOnly: isReadOnly,
                  license: liveUser.license,
                  child: SecurityGate(child: const MainNavigation()),
                );
              },
            ),
          );
        }
        return const Scaffold(body: Center(child: Text('Something went wrong')));
      },
    );
  }
}

class PlatformGate extends StatelessWidget {
  final Widget child;
  const PlatformGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformConfigModel>(
      stream: PlatformGovernanceService().streamConfig(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final config = snapshot.data!;
          if (config.maintenanceMode) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.build_circle_outlined, size: 80, color: Colors.orange),
                      const SizedBox(height: 24),
                      const Text('Maintenance Mode', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(config.maintenanceMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => AuthService().signOut(),
                        child: const Text('Sign Out'),
                      )
                    ],
                  ),
                ),
              ),
            );
          }
        }
        return child;
      },
    );
  }
}
