import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/notification_feed_model.dart';
import '../providers/notification_provider.dart';
import '../screens/abandoned_orders/abandoned_orders_screen.dart';
import '../screens/notifications/notification_manager_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/reviews/reviews_manager_screen.dart';

/// Modern dropdown & message feed modal for instant notification alerts
class NotificationDropdownModal extends StatefulWidget {
  const NotificationDropdownModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationDropdownModal(),
    );
  }

  @override
  State<NotificationDropdownModal> createState() => _NotificationDropdownModalState();
}

class _NotificationDropdownModalState extends State<NotificationDropdownModal> {
  String _selectedTab = 'all'; // 'all' | 'order' | 'abandoned' | 'review'

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String customerName) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) {
      clean = '88$clean';
    } else if (!clean.startsWith('880') && clean.length == 10) {
      clean = '880$clean';
    }
    if (clean.isEmpty) return;

    final msg = Uri.encodeComponent('আসসালামু আলাইকুম $customerName, বুস্টার ডোজ একাডেমি থেকে আপনার অর্ডারের বিষয়ে যোগাযোগ করছি।');
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToDetail(NotificationItem item) {
    Navigator.pop(context); // Close dropdown
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
    } else if (item.type == 'review') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReviewsManagerScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationManagerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final targetHeight = mediaQuery.size.height * 0.85;

    return Consumer<NotificationProvider>(
      builder: (context, np, _) {
        final counts = np.counts;
        final totalUnread = counts?.totalUnread ?? 0;
        final items = np.items;

        // Filter items
        final filteredItems = items.where((it) {
          if (_selectedTab == 'all') return true;
          if (_selectedTab == 'order') return it.type == 'order';
          if (_selectedTab == 'abandoned') return it.type == 'abandoned_order';
          if (_selectedTab == 'review') return it.type == 'review';
          return true;
        }).toList();

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            height: targetHeight,
            decoration: const BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF263345), width: 1.5)),
            ),
            child: Column(
              children: [
                // Pull Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'বিজ্ঞপ্তি ও বার্তা ড্রপডাউন',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                if (totalUnread > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentRose,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$totalUnread নতুন',
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Text(
                              'ওয়েবসাইটে নতুন অর্ডার ও পরিত্যক্ত কার্টের রিয়েল-টাইম ফিড',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: np.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        tooltip: 'রিফ্রেশ',
                        onPressed: () => np.fetchFeed(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFF1E293B), height: 1),

                // Filter Tabs (Chips)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip('all', 'সব (${items.length})', Icons.all_inbox_rounded),
                        const SizedBox(width: 8),
                        _buildTabChip(
                          'order',
                          'নতুন অর্ডার (${counts?.pendingOrders ?? 0})',
                          Icons.shopping_bag_rounded,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _buildTabChip(
                          'abandoned',
                          'পরিত্যক্ত কার্ট (${counts?.pendingAbandoned ?? 0})',
                          Icons.remove_shopping_cart_rounded,
                          color: AppTheme.accentRose,
                        ),
                        const SizedBox(width: 8),
                        _buildTabChip(
                          'review',
                          'রিভিউ (${counts?.pendingReviews ?? 0})',
                          Icons.star_rounded,
                          color: AppTheme.accentPurple,
                        ),
                      ],
                    ),
                  ),
                ),

                // Notification Items List
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161F30),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 44),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'এই ক্যাটাগরিতে কোনো নতুন বিজ্ঞপ্তি নেই',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'ওয়েবসাইট থেকে নতুন অর্ডার আসলে এখানে সরাসরি দেখা যাবে',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) => _buildNotificationCard(filteredItems[idx]),
                        ),
                ),

                // Bottom Action Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161F30),
                    border: Border(top: BorderSide(color: Color(0xFF263345))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationManagerScreen()),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('সম্পূর্ণ নোটিফিকেশন ম্যানেজার'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () async {
                          final ok = await np.sendTestNotification();
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.primary,
                                content: Text('টেস্ট নোটিফিকেশন পাঠানো হয়েছে!'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 20),
                        tooltip: 'টেস্ট পুশ পাঠান',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabChip(String key, String label, IconData icon, {Color? color}) {
    final isSelected = _selectedTab == key;
    final chipColor = color ?? AppTheme.accentCyan;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.18) : const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF263345),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? chipColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (item.type) {
      case 'order':
        typeColor = AppTheme.primary;
        typeIcon = Icons.shopping_bag_rounded;
        typeLabel = 'নতুন অর্ডার';
        break;
      case 'abandoned_order':
        typeColor = AppTheme.accentRose;
        typeIcon = Icons.remove_shopping_cart_rounded;
        typeLabel = 'পরিত্যক্ত কার্ট';
        break;
      case 'review':
        typeColor = AppTheme.accentPurple;
        typeIcon = Icons.star_rounded;
        typeLabel = 'বই রিভিউ';
        break;
      default:
        typeColor = AppTheme.accentCyan;
        typeIcon = Icons.notifications_rounded;
        typeLabel = 'অ্যালার্ট';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (item.timeAgo != null && item.timeAgo!.isNotEmpty)
                  Text(
                    item.timeAgo!,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Name & Book
            Text(
              item.customerName.isNotEmpty ? item.customerName : 'গ্রাহক',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (item.bookTitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'বই: ${item.bookTitle}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Amount / Status / Phone Row
            const SizedBox(height: 6),
            Row(
              children: [
                if (item.customerPhone.isNotEmpty)
                  Expanded(
                    child: Text(
                      'ফোন: ${item.customerPhone}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (item.amount > 0)
                  Text(
                    '৳${item.amount.toStringAsFixed(0)}',
                    style: TextStyle(color: typeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 8),

            // Actions Row
            Row(
              children: [
                if (item.customerPhone.isNotEmpty) ...[
                  // Phone Call button
                  InkWell(
                    onTap: () => _makeCall(item.customerPhone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, color: AppTheme.accentCyan, size: 14),
                          SizedBox(width: 4),
                          Text('কল', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // WhatsApp button
                  InkWell(
                    onTap: () => _openWhatsApp(item.customerPhone, item.customerName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF22C55E), size: 14),
                          SizedBox(width: 4),
                          Text('হোয়াটসঅ্যাপ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                const Spacer(),

                // View Details button
                ElevatedButton.icon(
                  onPressed: () => _navigateToDetail(item),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.black),
                  label: const Text('বিস্তারিত', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: typeColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
