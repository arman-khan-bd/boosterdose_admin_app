import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final _searchController = TextEditingController();

  final List<Map<String, String>> _statusFilters = [
    {'key': 'all', 'label': 'সব অর্ডার'},
    {'key': 'pending', 'label': 'পেন্ডিং'},
    {'key': 'processing', 'label': 'প্রসেসিং'},
    {'key': 'shipped', 'label': 'শিপড'},
    {'key': 'delivered', 'label': 'ডেলিভার্ড'},
    {'key': 'cancelled', 'label': 'বাতিল'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchOrders(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('অর্ডার ম্যানেজমেন্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => orderProvider.fetchOrders(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surfaceDark,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'অর্ডার #, নাম অথবা ফোন দিয়ে খুঁজুন...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          orderProvider.setSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (val) => orderProvider.setSearch(val.trim()),
            ),
          ),

          // Horizontal Status Filter Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppTheme.surfaceDark,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              itemBuilder: (ctx, i) {
                final filter = _statusFilters[i];
                final isSelected = orderProvider.selectedStatus == filter['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: const Color(0xFF161F30),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) orderProvider.setStatus(filter['key']!);
                    },
                  ),
                );
              },
            ),
          ),

          // Orders List
          Expanded(
            child: orderProvider.isLoading && orderProvider.orders.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : orderProvider.orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_rounded, color: Color(0xFF64748B), size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'কোনো অর্ডার পাওয়া যায়নি',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => orderProvider.fetchOrders(refresh: true),
                              child: const Text('রিফ্রেশ করুন'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => orderProvider.fetchOrders(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orderProvider.orders.length,
                          itemBuilder: (ctx, i) {
                            final order = orderProvider.orders[i];
                            final isPending = order.status.toLowerCase() == 'pending';

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
                                ).then((_) => orderProvider.fetchOrders(page: orderProvider.currentPage));
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isPending ? const Color(0xFF1B243B) : const Color(0xFF161F30),
                                  borderRadius: BorderRadius.circular(18),
                                  border: isPending
                                      ? Border(
                                          left: const BorderSide(color: Color(0xFFF59E0B), width: 4.5),
                                          top: BorderSide(color: const Color(0xFFF59E0B).withOpacity(0.35), width: 1),
                                          right: const BorderSide(color: Color(0xFF263345), width: 1),
                                          bottom: const BorderSide(color: Color(0xFF263345), width: 1),
                                        )
                                      : Border.all(color: const Color(0xFF263345)),
                                  boxShadow: isPending
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withOpacity(0.09),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            if (isPending) ...[
                                              Container(
                                                width: 9,
                                                height: 9,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFF59E0B).withOpacity(0.85),
                                                      blurRadius: 6,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            Text(
                                              '#${order.orderNumber}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if (isPending) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(0xFFF59E0B).withOpacity(0.4),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'আনরিড / পেন্ডিং',
                                                  style: TextStyle(
                                                    color: Color(0xFFFBBF24),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '৳${order.totalAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      order.customerName,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${order.customerPhone} • ${order.deliveryAddress}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'বই: ${order.bookTitle} (x${order.quantity})',
                                      style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            StatusBadge(status: order.status),
                                            const SizedBox(width: 8),
                                            StatusBadge(status: order.paymentStatus, isPayment: true),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: order.copyableOrderData));
                                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 16),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '#${order.orderNumber} এর ডাটা (নাম, ফোন, ঠিকানা) কপি হয়েছে!',
                                                              style: const TextStyle(fontSize: 12),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      backgroundColor: const Color(0xFF1E293B),
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.accentCyan.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.copy_rounded, size: 12, color: AppTheme.accentCyan),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'কপি',
                                                        style: TextStyle(
                                                          color: AppTheme.accentCyan,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
