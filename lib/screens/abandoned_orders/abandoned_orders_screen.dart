import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/abandoned_order_model.dart';
import '../../providers/abandoned_order_provider.dart';
import '../../widgets/status_badge.dart';
import 'convert_order_dialog.dart';

class AbandonedOrdersScreen extends StatefulWidget {
  const AbandonedOrdersScreen({super.key});

  @override
  State<AbandonedOrdersScreen> createState() => _AbandonedOrdersScreenState();
}

class _AbandonedOrdersScreenState extends State<AbandonedOrdersScreen> {
  final _searchController = TextEditingController();

  final List<Map<String, String>> _statusFilters = [
    {'key': 'all', 'label': 'সব লিড'},
    {'key': 'pending', 'label': 'পেন্ডিং'},
    {'key': 'contacted', 'label': 'যোগাযোগকৃত'},
    {'key': 'recovered', 'label': 'রিকভার্ড'},
    {'key': 'lost', 'label': 'বাতিল লিড'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AbandonedOrderProvider>(context, listen: false).fetchAbandonedOrders(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showStatusDialog(dynamic lead) {
    final provider = Provider.of<AbandonedOrderProvider>(context, listen: false);
    final statuses = [
      {'key': 'pending', 'label': 'পেন্ডিং (অপেক্ষমাণ)'},
      {'key': 'contacted', 'label': 'গ্রাহকের সাথে যোগাযোগ করা হয়েছে'},
      {'key': 'recovered', 'label': 'সফলভাবে অর্ডার নেওয়া হয়েছে (Recovered)'},
      {'key': 'lost', 'label': 'গ্রাহক কিনতে অনিচ্ছুক (Lost)'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'রিকভারি স্ট্যাটাস আপডেট করুন',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...statuses.map((item) {
                return ListTile(
                  title: Text(item['label']!, style: const TextStyle(color: Colors.white)),
                  trailing: lead.recoveryStatus == item['key']
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await provider.updateStatus(lead.id, item['key']!);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openConvertDialog(AbandonedOrderModel lead) {
    ConvertOrderDialog.show(context, lead);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AbandonedOrderProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('পরিত্যক্ত কার্ট রিকভারি'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.fetchAbandonedOrders(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surfaceDark,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'নাম, মোবাইল বা ঠিকানা দিয়ে খুঁজুন...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (val) => provider.setSearch(val.trim()),
            ),
          ),

          // Filter chips
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
                final isSelected = provider.selectedRecoveryStatus == filter['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    selectedColor: AppTheme.accentRose,
                    backgroundColor: const Color(0xFF161F30),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) provider.setRecoveryStatus(filter['key']!);
                    },
                  ),
                );
              },
            ),
          ),

          // 5-Minute Checkout Grace Notice if any leads are in progress
          if (provider.inProgressCheckoutCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.accentCyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${provider.inProgressCheckoutCount} জন ক্রেতা এইমাত্র চেকআউটে তথ্য পূরণ করেছেন। ৫ মিনিটের মধ্যে অর্ডার না দিলে পরিত্যক্ত তালিকায় দেখাবে।',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          // Abandoned carts list
          Expanded(
            child: provider.isLoading && provider.abandonedOrders.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : provider.abandonedOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.remove_shopping_cart_outlined, color: Color(0xFF64748B), size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'কোনো পরিত্যক্ত কার্ট পাওয়া যায়নি',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => provider.fetchAbandonedOrders(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.abandonedOrders.length,
                          itemBuilder: (ctx, i) {
                            final lead = provider.abandonedOrders[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161F30),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF263345)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lead.customerName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(status: lead.recoveryStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ফোন: ${lead.customerPhone}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                  if (lead.deliveryAddress != null && lead.deliveryAddress!.isNotEmpty)
                                    Text(
                                      'ঠিকানা: ${lead.deliveryAddress}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'বই: ${lead.bookTitle}',
                                          style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '৳${lead.totalAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Color(0xFF263345)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _callCustomer(lead.customerPhone),
                                          icon: const Icon(Icons.phone, size: 14, color: AppTheme.primary),
                                          label: const Text('কল', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppTheme.primaryDark),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _openConvertDialog(lead),
                                          icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.black),
                                          label: const Text('কনভার্ট', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 22),
                                        tooltip: 'স্ট্যাটাস আপডেট',
                                        onPressed: () => _showStatusDialog(lead),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.accentRose, size: 20),
                                        tooltip: 'মুছে ফেলুন',
                                        onPressed: () => provider.deleteAbandoned(lead.id),
                                      ),
                                    ],
                                  ),
                                ],
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
