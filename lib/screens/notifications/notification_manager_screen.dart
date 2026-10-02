import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/notification_provider.dart';
import '../../services/permission_service.dart';
import '../abandoned_orders/abandoned_orders_screen.dart';
import '../orders/order_detail_screen.dart';
import '../reviews/reviews_manager_screen.dart';
import '../../widgets/system_permission_modal.dart';

class NotificationManagerScreen extends StatefulWidget {
  const NotificationManagerScreen({super.key});

  @override
  State<NotificationManagerScreen> createState() => _NotificationManagerScreenState();
}

class _NotificationManagerScreenState extends State<NotificationManagerScreen> {
  bool _hasNotificationPermission = true;
  bool _isBatteryOptimizationDisabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchFeed();
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final batt = await PermissionService.isBatteryOptimizationDisabled();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = notif;
        _isBatteryOptimizationDisabled = batt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = Provider.of<NotificationProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('নোটিফিকেশন ও অ্যালার্ট ফিড'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'সিস্টেম পারমিশন ও ব্যাকগ্রাউন্ড সেটিংস',
                onPressed: () async {
                  await SystemPermissionModal.show(context);
                  _checkPermissions();
                },
              ),
              if (!_hasNotificationPermission || !_isBatteryOptimizationDisabled)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentAmber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: () => np.fetchFeed(),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
            tooltip: 'টেস্ট নোটিফিকেশন পাঠান',
            onPressed: () async {
              final ok = await np.sendTestNotification();
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.primary,
                    content: Text('টেস্ট নোটিফিকেশন সফলভাবে পাঠানো হয়েছে!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: np.isLoading && np.items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Counts summary
                  if (np.counts != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeCard('পেন্ডিং অর্ডার', '${np.counts!.pendingOrders}', AppTheme.accentAmber, () {
                            // Can filter or view
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildBadgeCard(
                            'পরিত্যক্ত কার্ট',
                            '${np.items.isNotEmpty ? np.items.where((i) => i.type == 'abandoned_order').length : np.counts!.pendingAbandoned}',
                            AppTheme.accentRose,
                            () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AbandonedOrdersScreen()));
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildBadgeCard('নতুন রিভিউ', '${np.counts!.pendingReviews}', AppTheme.accentCyan, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsManagerScreen()));
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quick Settings Access Button for permissions
                  InkWell(
                    onTap: () async {
                      await SystemPermissionModal.show(context);
                      _checkPermissions();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                              ? const Color(0xFF263345)
                              : AppTheme.accentAmber.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                                  ? AppTheme.primary.withOpacity(0.12)
                                  : AppTheme.accentAmber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                                  ? AppTheme.primary
                                  : AppTheme.accentAmber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'সিস্টেম পারমিশন ও ব্যাকগ্রাউন্ড সেটিংস',
                                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                                      ? 'সকল নোটিফিকেশন ও ব্যাকগ্রাউন্ড পারমিশন সক্রিয় রয়েছে'
                                      : 'সতর্কতা: লাইভ অ্যালার্ট পেতে অনুমতি সেটআপ করুন',
                                  style: TextStyle(
                                    color: (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                                        ? const Color(0xFF94A3B8)
                                        : AppTheme.accentAmber,
                                    fontSize: 11,
                                    fontWeight: (_hasNotificationPermission && _isBatteryOptimizationDisabled)
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, color: AppTheme.primary, size: 14),
                                SizedBox(width: 4),
                                Text('সেটিংস', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Text(
                    'সাম্প্রতিক অ্যাক্টিভিটি ও অ্যালার্টসমূহ',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (np.items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: const [
                            Icon(Icons.notifications_off_outlined, color: Color(0xFF64748B), size: 48),
                            SizedBox(height: 12),
                            Text('সব অ্যালার্ট ক্লিয়ার রয়েছে', style: TextStyle(color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    )
                  else
                    ...np.items.map((item) {
                      Color typeColor;
                      IconData typeIcon;

                      if (item.type == 'order') {
                        typeColor = AppTheme.primary;
                        typeIcon = Icons.shopping_bag_rounded;
                      } else if (item.type == 'abandoned_order') {
                        typeColor = AppTheme.accentRose;
                        typeIcon = Icons.remove_shopping_cart_rounded;
                      } else {
                        typeColor = AppTheme.accentAmber;
                        typeIcon = Icons.rate_review_rounded;
                      }

                      return InkWell(
                        onTap: () {
                          if (item.type == 'order' && item.id.startsWith('order-')) {
                            final rawId = int.tryParse(item.id.replaceFirst('order-', ''));
                            if (rawId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: rawId)),
                              );
                            }
                          } else if (item.type == 'abandoned_order') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AbandonedOrdersScreen()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReviewsManagerScreen()),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F30),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF263345)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(typeIcon, color: typeColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          item.timeAgo ?? '',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.customerName} • ${item.customerPhone}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'বই: ${item.bookTitle} ${item.amount > 0 ? '• ৳${item.amount.toInt()}' : ''}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildBadgeCard(String label, String count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
