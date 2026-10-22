import 'dart:async'; // NEW
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/settings_service.dart';
import '../models/settings_model.dart'; // NEW
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../screens/inventory_screen.dart';
import '../screens/notification_center_screen.dart';

class DesktopTopBar extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const DesktopTopBar({super.key, this.onNavigateToSettings});

  @override
  State<DesktopTopBar> createState() => _DesktopTopBarState();
}

class _DesktopTopBarState extends State<DesktopTopBar> {
  UserModel? _user;
  String? _logoBase64;
  
  final LayerLink _inventoryLayerLink = LayerLink();
  final LayerLink _notificationLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  StreamSubscription<AppSettings>? _settingsSub; // NEW

  @override
  void initState() {
    super.initState();
    _loadUser();
    _subscribeToSettings();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  void _subscribeToSettings() {
    _settingsSub = SettingsService().streamSettings().listen((settings) {
      if (mounted) {
        setState(() {
          _logoBase64 = settings.logoBase64;
        });
      }
    });
  }

  Future<void> _loadUser() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
       // Only fetch user here, settings are handled by stream
      final user = await UserService().getUser(uid);
      if (mounted) {
        setState(() => _user = user);
      }
    }
  }
  
  void _toggleOverlay(BuildContext context, {required bool isInventory}) {
    if (_overlayEntry != null) {
      _closeOverlay();
      return;
    }

    _overlayEntry = _createOverlayEntry(context, isInventory: isInventory);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry(BuildContext context, {required bool isInventory}) {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismissible background
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content
          Positioned(
            right: 20, // Align to right side
            top: 70,   // Below the top bar
            child: CompositedTransformFollower(
              link: isInventory ? _inventoryLayerLink : _notificationLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(-360, 50), 
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  width: 400,
                  height: MediaQuery.of(context).size.height * 0.7,
                  constraints: const BoxConstraints(maxHeight: 600, minHeight: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isInventory 
                      ? InventoryScreen(onAdd: _closeOverlay) 
                      : const NotificationCenterScreen(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellState>();
    
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (shell.leading != null) ...[
             shell.leading!,
             const SizedBox(width: 16),
          ],
          Text(
            shell.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 24),
          // Sub-screen actions
          ...shell.actions,
          const Spacer(),
          // Global Actions
          CompositedTransformTarget(
            link: _inventoryLayerLink,
            child: IconButton(
              icon: const Icon(Icons.inventory_2_outlined, color: AppColors.textGrey),
              tooltip: 'Inventory',
              onPressed: () => _toggleOverlay(context, isInventory: true),
            ),
          ),
           CompositedTransformTarget(
            link: _notificationLayerLink,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.textGrey),
              tooltip: 'Notifications',
              onPressed: () => _toggleOverlay(context, isInventory: false),
            ),
          ),
          const SizedBox(width: 16),
          // User Profile Info
          if (_user != null)
            InkWell(
              onTap: widget.onNavigateToSettings,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _user?.name ?? 'User',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          _user!.role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    // REMOVED: Logo/Avatar on the right side
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
