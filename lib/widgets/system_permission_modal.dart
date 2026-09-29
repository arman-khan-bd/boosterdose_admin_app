import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_theme.dart';
import '../services/permission_service.dart';

class SystemPermissionModal extends StatefulWidget {
  final bool isStartup;
  final VoidCallback? onDismiss;

  const SystemPermissionModal({
    super.key,
    this.isStartup = false,
    this.onDismiss,
  });

  /// Show the System Permission & Background Settings Modal
  static Future<void> show(BuildContext context, {bool isStartup = false}) async {
    if (isStartup) {
      final allGranted = await PermissionService.areAllRequiredPermissionsGranted();
      if (allGranted) {
        await PermissionService.markInitialPermissionsPrompted();
        return;
      }
    }
    await PermissionService.markInitialPermissionsPrompted();

    if (!context.mounted) return;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SystemPermissionModal(isStartup: isStartup),
    );
  }

  /// Show as an AlertDialog (useful for startup prompt)
  static Future<void> showStartupDialog(BuildContext context) async {
    final allGranted = await PermissionService.areAllRequiredPermissionsGranted();
    if (allGranted) {
      await PermissionService.markInitialPermissionsPrompted();
      return;
    }
    await PermissionService.markInitialPermissionsPrompted();

    if (!context.mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SystemPermissionModal(
          isStartup: true,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  State<SystemPermissionModal> createState() => _SystemPermissionModalState();
}

class _SystemPermissionModalState extends State<SystemPermissionModal> with WidgetsBindingObserver {
  bool _hasNotificationPermission = false;
  bool _isBatteryOptimizationDisabled = false;
  bool _hasCameraPermission = false;
  bool _hasMediaPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PermissionService.markInitialPermissionsPrompted();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notif = kIsWeb ? true : await Permission.notification.isGranted;
    final batt = await PermissionService.isBatteryOptimizationDisabled();
    final cam = kIsWeb ? true : await Permission.camera.isGranted;
    final media = kIsWeb ? true : (await Permission.photos.isGranted || await Permission.storage.isGranted);

    if (mounted) {
      setState(() {
        _hasNotificationPermission = notif;
        _isBatteryOptimizationDisabled = batt;
        _hasCameraPermission = cam;
        _hasMediaPermission = media;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF263345), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle for BottomSheet
          if (!widget.isStartup)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Shield and Settings button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'সিস্টেম পারমিশন ও ব্যাকগ্রাউন্ড সেটিংস',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'লাইভ অর্ডার নোটিফিকেশন ও আপলোড নিরবচ্ছিন্ন রাখতে',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8), size: 22),
                      tooltip: 'ডিভাইস সেটিংস খুলুন',
                      onPressed: () => openAppSettings(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFF263345), height: 1),
                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else ...[
                  // Item 1: Push Notification
                  _buildPermissionRow(
                    icon: Icons.notifications_active_outlined,
                    iconColor: AppTheme.accentAmber,
                    title: 'পুশ নোটিফিকেশন',
                    subtitle: _hasNotificationPermission
                        ? 'অনুমোদিত (অর্ডার অ্যালার্ট চালু)'
                        : 'বন্ধ রয়েছে (অনুমোদন প্রয়োজন)',
                    isGranted: _hasNotificationPermission,
                    buttonText: _hasNotificationPermission ? 'অনুমোদিত' : 'অনুমোদন দিন',
                    onTap: () async {
                      await PermissionService.requestNotificationPermission(context, showExplanation: true);
                      _checkPermissions();
                    },
                  ),

                  const Divider(color: Color(0xFF1E293B), height: 16),

                  // Item 2: Battery Optimization
                  _buildPermissionRow(
                    icon: Icons.battery_charging_full_rounded,
                    iconColor: AppTheme.primary,
                    title: 'ব্যাটারি অপ্টিমাইজেশন',
                    subtitle: _isBatteryOptimizationDisabled
                        ? 'ডিজেবল (ব্যাকগ্রাউন্ড লাইভ অ্যালার্ট সক্রিয়)'
                        : 'চালু আছে (ব্যাকগ্রাউন্ড বন্ধ হতে পারে)',
                    isGranted: _isBatteryOptimizationDisabled,
                    buttonText: _isBatteryOptimizationDisabled ? 'ডিজেবল্ড' : 'ডিজেবল করুন',
                    onTap: () async {
                      await PermissionService.requestDisableBatteryOptimization(context);
                      _checkPermissions();
                    },
                  ),

                  const Divider(color: Color(0xFF1E293B), height: 16),

                  // Item 3: Media & Camera
                  _buildPermissionRow(
                    icon: Icons.camera_alt_outlined,
                    iconColor: AppTheme.accentCyan,
                    title: 'মিডিয়া ও ক্যামেরা',
                    subtitle: (_hasCameraPermission || _hasMediaPermission)
                        ? 'সক্রিয় (ছবি/কভার ও স্ক্রিনশট আপলোড সচল)'
                        : 'ছবি/কভার ও স্ক্রিনশট আপলোড পারমিশন',
                    isGranted: (_hasCameraPermission || _hasMediaPermission),
                    buttonText: (_hasCameraPermission || _hasMediaPermission) ? 'যাচাই সম্পন্ন' : 'যাচাই করুন',
                    onTap: () async {
                      final c = await PermissionService.requestCameraPermission(context);
                      if (mounted) {
                        final m = await PermissionService.requestMediaPermission(context);
                        _checkPermissions();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: (c || m) ? AppTheme.primary : AppTheme.accentAmber,
                              content: Text(
                                (c || m) ? 'ক্যামেরা ও মিডিয়া পারমিশন সফলভাবে অনুমোদিত!' : 'ক্যামেরা বা মিডিয়া পারমিশন যাচাই সম্পন্ন',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],

                const SizedBox(height: 18),

                // Bottom Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openAppSettings(),
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF94A3B8)),
                        label: const Text('ডিভাইস সেটিংস', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.onDismiss != null) {
                            widget.onDismiss!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'সম্পন্ন',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isGranted,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isGranted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isGranted
                  ? AppTheme.primary.withOpacity(0.12)
                  : AppTheme.accentAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isGranted
                    ? AppTheme.primary.withOpacity(0.4)
                    : AppTheme.accentAmber.withOpacity(0.5),
              ),
            ),
            child: Text(
              buttonText,
              style: TextStyle(
                color: isGranted ? AppTheme.primary : AppTheme.accentAmber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
