import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/notification_provider.dart';
import '../services/native_notification_service.dart';
import '../services/permission_service.dart';
import 'abandoned_orders/abandoned_orders_screen.dart';
import 'books/books_list_screen.dart';
import 'courier/courier_manager_screen.dart';
import 'notifications/notification_manager_screen.dart';
import 'orders/order_detail_screen.dart';
import 'orders/orders_list_screen.dart';
import 'overview_screen.dart';
import 'profile/profile_screen.dart';
import 'reviews/reviews_manager_screen.dart';
import 'sections/sections_manager_screen.dart';
import '../widgets/system_permission_modal.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const OverviewScreen(),
    const OrdersListScreen(),
    const AbandonedOrdersScreen(),
    const BooksListScreen(),
    const NotificationManagerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start real-time live notification polling & listen for instant incoming orders / abandoned carts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final np = Provider.of<NotificationProvider>(context, listen: false);
      np.startPolling();
      np.addListener(_onNotificationUpdate);

      // Handle notification taps from Android system dropdown tray
      NativeNotificationService.init(
        onNotificationTapped: (type, payload) {
          _handleNotificationRouting(type, payload);
        },
      );

      // Check if launched directly from Android notification click
      NativeNotificationService.getInitialNotification().then((data) {
        if (data != null && mounted) {
          final type = data['type']?.toString() ?? 'order';
          final payload = data['payload']?.toString() ?? '';
          _handleNotificationRouting(type, payload);
        }
      });

      // Only check and show permissions modal on first launch after install
      // and ONLY if any required permission is not yet granted
      _checkAndPromptStartupPermissions();
    });
  }

  void _handleNotificationRouting(String type, String payload) {
    if (!mounted) return;
    if (type == 'order') {
      final orderId = int.tryParse(payload);
      if (orderId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
        );
      } else {
        setState(() => _currentIndex = 1);
      }
    } else if (type == 'abandoned_order') {
      setState(() => _currentIndex = 2);
    } else if (type == 'review') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReviewsManagerScreen()),
      );
    } else {
      setState(() => _currentIndex = 4);
    }
  }

  @override
  void dispose() {
    try {
      final np = Provider.of<NotificationProvider>(context, listen: false);
      np.removeListener(_onNotificationUpdate);
      np.stopPolling();
    } catch (_) {}
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (!mounted) return;
    final np = Provider.of<NotificationProvider>(context, listen: false);
    final item = np.latestArrival;
    if (item != null) {
      np.clearLatestArrival();

      final isOrder = item.type == 'order';
      final title = isOrder ? '🔔 নতুন অর্ডার এসেছে!' : '🛒 নতুন পরিত্যক্ত কার্ট এসেছে!';
      final sub = item.customerName.isNotEmpty
          ? '${item.customerName} • ${item.customerPhone}'
          : 'ফোন: ${item.customerPhone}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isOrder ? const Color(0xFF064E3B) : const Color(0xFF881337),
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isOrder ? AppTheme.primary : AppTheme.accentRose, width: 1.5),
          ),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOrder ? Icons.shopping_bag_rounded : Icons.remove_shopping_cart_rounded,
                  color: isOrder ? AppTheme.primary : AppTheme.accentRose,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 11.5, color: Color(0xFFE2E8F0)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'দেখুন',
            textColor: Colors.white,
            onPressed: () {
              if (item.type == 'order' && item.orderId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: item.orderId!)),
                );
              } else if (item.type == 'abandoned_order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AbandonedOrdersScreen()),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _checkAndPromptStartupPermissions() async {
    if (kIsWeb) return;

    try {
      // 1. Check if already prompted previously (only show first time after install)
      final hasPrompted = await PermissionService.hasPromptedInitialPermissions();
      if (hasPrompted) return;

      // 2. Check if any option is not yet given permission (only show if any option not granted)
      final allGranted = await PermissionService.areAllRequiredPermissionsGranted();
      if (allGranted) {
        // All permissions are already active, never prompt automatically
        await PermissionService.markInitialPermissionsPrompted();
        return;
      }

      // Mark as prompted so it never appears again automatically on future app opens
      await PermissionService.markInitialPermissionsPrompted();

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        SystemPermissionModal.show(context, isStartup: true);
      }
    } catch (_) {}
  }

  void _openMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ম্যানেজমেন্ট মেন্যু (Control Suite)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMenuTile(
                        icon: Icons.rate_review_rounded,
                        color: AppTheme.accentAmber,
                        title: 'রিভিউ ম্যানেজার',
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsManagerScreen()));
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.local_shipping_rounded,
                        color: AppTheme.accentCyan,
                        title: 'কুরিয়ার সার্ভিস',
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CourierManagerScreen()));
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.view_quilt_rounded,
                        color: AppTheme.accentPurple,
                        title: 'সেকশনস ডেটা',
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SectionsManagerScreen()));
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.notifications_active_rounded,
                        color: AppTheme.accentRose,
                        title: 'নোটিফিকেশন ফিড',
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _currentIndex = 4);
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.person_rounded,
                        color: AppTheme.primary,
                        title: 'প্রোফাইল ডেটা',
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.shield_outlined,
                        color: AppTheme.accentEmerald,
                        title: 'সিস্টেম সেটিংস',
                        onTap: () {
                          Navigator.pop(ctx);
                          SystemPermissionModal.show(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifCounts = Provider.of<NotificationProvider>(context).counts;
    final unread = notifCounts?.totalUnread ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 5) {
              _openMoreMenu(context);
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'ওভারভিউ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_rounded),
              label: 'অর্ডারস',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.remove_shopping_cart_rounded),
              label: 'পরিত্যক্ত',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'বইসমূহ',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_rounded),
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRose,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'অ্যালার্ট',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.apps_rounded),
              label: 'মেন্যু',
            ),
          ],
        ),
      ),
    );
  }
}
