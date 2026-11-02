import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';
import '../models/calendar_event.dart';
import '../services/user_service.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/calendar_service.dart';
import '../providers/shell_provider.dart';
import '../screens/inventory_screen.dart';
import '../screens/notification_center_screen.dart';
import '../core/responsive/breakpoints.dart';

/// UniversalTopHeader implements the "Unified Hierarchical Stack" design:
/// - Left side: App Logo & DigiInvi Name (v1.0), with Client Business Logo & Name directly below.
/// - Right side: Notification bell with live badge count & Inventory quick-access icon.
/// - Adapts smoothly for Desktop (overlay dropdowns) and Mobile (page transitions).
class UniversalTopHeader extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onNavigateToSettings;
  final bool showBusinessProfile;
  final bool isScrolled;

  const UniversalTopHeader({
    super.key,
    this.onNavigateToSettings,
    this.showBusinessProfile = true,
    this.isScrolled = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(isScrolled ? 58 : 84);

  @override
  State<UniversalTopHeader> createState() => _UniversalTopHeaderState();
}

class _UniversalTopHeaderState extends State<UniversalTopHeader> {
  UserModel? _user;
  AppSettings? _appSettings;

  final LayerLink _inventoryLayerLink = LayerLink();
  final LayerLink _notificationLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  StreamSubscription<AppSettings>? _settingsSub;
  Stream<List<Map<String, dynamic>>> _notificationStream = Stream.value([]);
  Stream<List<CalendarEvent>> _calendarStream = Stream.value([]);

  @override
  void initState() {
    super.initState();
    _loadUserAndSettings();
    _subscribeToSettings();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _closeOverlay();
    super.dispose();
  }

  void _subscribeToSettings() {
    _settingsSub = SettingsService().streamSettings().listen((settings) {
      if (mounted) {
        setState(() {
          _appSettings = settings;
          if (_user != null &&
              settings.tenantName.isNotEmpty &&
              settings.tenantName != 'My Business') {
            _user = UserModel(
              uid: _user!.uid,
              name: settings.tenantName,
              email: _user!.email,
              role: _user!.role,
              tenantId: _user!.tenantId,
              license: _user!.license,
              permissions: _user!.permissions,
              createdAt: _user!.createdAt,
            );
          }
        });
      }
    });
  }

  Future<void> _loadUserAndSettings() async {
    final uid = AuthService().currentUser?.id ??
        Supabase.instance.client.auth.currentUser?.id;
    final currentTenant = AuthService().currentTenantId;
    final tenantId = currentTenant.isNotEmpty ? currentTenant : uid;

    if (uid != null) {
      final user = await UserService().getUser(uid);
      final settings = await SettingsService().fetchSettings();
      if (mounted) {
        setState(() {
          _appSettings = settings;
          if (user != null &&
              settings.tenantName.isNotEmpty &&
              settings.tenantName != 'My Business') {
            _user = UserModel(
              uid: user.uid,
              name: settings.tenantName,
              email: user.email,
              role: user.role,
              tenantId: user.tenantId,
              license: user.license,
              permissions: user.permissions,
              createdAt: user.createdAt,
            );
          } else {
            _user = user;
          }
        });
      }
    }

    if (tenantId != null && tenantId.isNotEmpty) {
      try {
        _notificationStream = Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('tenant_id', tenantId);
      } catch (_) {
        _notificationStream = Stream.value([]);
      }

      try {
        _calendarStream = CalendarService().streamEvents(tenantId: tenantId);
      } catch (_) {
        _calendarStream = Stream.value([]);
      }
      if (mounted) setState(() {});
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

  OverlayEntry _createOverlayEntry(BuildContext context,
      {required bool isInventory}) {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismissible translucent backdrop
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content anchored to LayerLink
          Positioned(
            right: 20,
            top: 72,
            child: CompositedTransformFollower(
              link: isInventory ? _inventoryLayerLink : _notificationLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(-360, 50),
              child: Material(
                elevation: 16,
                shadowColor: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  width: 400,
                  height: MediaQuery.of(context).size.height * 0.7,
                  constraints:
                      const BoxConstraints(maxHeight: 600, minHeight: 400),
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
    final bool isCompact = context.isCompact;
    ShellState? shell;
    try {
      shell = Provider.of<ShellState>(context);
    } catch (_) {
      shell = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(minHeight: widget.isScrolled ? 56 : 82),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 24,
        vertical: widget.isScrolled ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isScrolled ? 0.05 : 0.03),
            blurRadius: widget.isScrolled ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Optional Shell Leading (e.g. desktop sub-route back button)
            if (shell?.leading != null) ...[
              shell!.leading!,
              const SizedBox(width: 12),
            ],

            // Left Side: App Logo & Client Business Logo & Name
            Expanded(
              child: _buildHierarchicalBranding(context, isCompact),
            ),

            // Shell actions (e.g. invoice view actions on desktop)
            if (!isCompact && shell != null && shell.actions.isNotEmpty) ...[
              ...shell.actions,
              const SizedBox(width: 16),
            ],

            // Right Side: Inventory Icon
            _buildInventoryButton(context, isCompact),
            const SizedBox(width: 8),

            // Right Side: Notification Bell with Badge
            _buildNotificationButton(context, isCompact),

            // Desktop User Profile Info Pill
            if (!isCompact && _user != null) ...[
              const SizedBox(width: 14),
              _buildUserProfilePill(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchicalBranding(BuildContext context, bool isCompact) {
    final settings = _appSettings;
    final businessName = (settings != null &&
            settings.tenantName.isNotEmpty &&
            settings.tenantName != 'My Business')
        ? settings.tenantName
        : (_user?.name != null &&
                _user!.name!.isNotEmpty &&
                _user!.name != 'My Business'
            ? _user!.name!
            : (settings?.tenantName ?? ''));
    final logoBase64 = settings?.logoBase64;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── TOP TIER: App Logo ONLY (Smoothly hides on scroll) ───────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
          sizeCurve: Curves.easeInOut,
          crossFadeState: widget.isScrolled
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: 10.0), // Vertical spacing between logo & business name
            child: Image.asset(
              'assets/icon/app_logo_header.png',
              height: isCompact ? 28 : 32,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        // ── SUB TIER: Client Business Logo & Business Name ──────────────
        if (widget.showBusinessProfile)
          InkWell(
            onTap: widget.onNavigateToSettings,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Client Business Logo / Icon
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: (logoBase64 != null && logoBase64.isNotEmpty)
                          ? Image.memory(
                              base64Decode(logoBase64),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.storefront_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Client Business Name
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? 160 : 320,
                      ),
                      child: Text(
                        businessName.isNotEmpty ? businessName : 'My Business',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Active status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3.5),
                        const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInventoryButton(BuildContext context, bool isCompact) {
    final button = IconButton(
      icon: const Icon(
        Icons.inventory_2_outlined,
        size: 22,
        color: AppColors.textDark,
      ),
      tooltip: 'Inventory',
      style: IconButton.styleFrom(
        hoverColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        if (isCompact) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryScreen()),
          );
        } else {
          _toggleOverlay(context, isInventory: true);
        }
      },
    );

    if (isCompact) return button;

    return CompositedTransformTarget(
      link: _inventoryLayerLink,
      child: button,
    );
  }

  Widget _buildNotificationButton(BuildContext context, bool isCompact) {
    final content = StreamBuilder<List<Map<String, dynamic>>>(
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
                final eDate =
                    DateTime(e.date.year, e.date.month, e.date.day);
                return !e.read && !eDate.isAfter(today);
              }).toList();
              count += unreadEvents.length;
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    size: 24,
                    color: AppColors.textDark,
                  ),
                  tooltip: 'Notifications',
                  style: IconButton.styleFrom(
                    hoverColor: Colors.black.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (isCompact) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationCenterScreen()),
                      );
                    } else {
                      _toggleOverlay(context, isInventory: false);
                    }
                  },
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    if (isCompact) return content;

    return CompositedTransformTarget(
      link: _notificationLayerLink,
      child: content,
    );
  }

  Widget _buildUserProfilePill(BuildContext context) {
    final name = _user?.name?.isNotEmpty == true ? _user!.name! : 'User';
    final role = _user?.role.toUpperCase() ?? 'ADMIN';

    return InkWell(
      onTap: widget.onNavigateToSettings,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
