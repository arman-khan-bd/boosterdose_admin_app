import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  List<OrderModel> _customerHistory = [];
  Map<String, dynamic> _security = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getOrderDetail(widget.orderId);
      setState(() {
        _order = res['order'];
        _customerHistory = res['customer_history'];
        _security = res['security'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showStatusDialog() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final statuses = [
      {'key': 'pending', 'label': 'পেন্ডিং (অপেক্ষমাণ)'},
      {'key': 'processing', 'label': 'প্রসেসিং হচ্ছে'},
      {'key': 'shipped', 'label': 'কুরিয়ারে শিপড'},
      {'key': 'delivered', 'label': 'ডেলিভারি সম্পন্ন'},
      {'key': 'cancelled', 'label': 'অর্ডার বাতিল'},
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
                  'অর্ডার স্ট্যাটাস পরিবর্তন করুন',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...statuses.map((item) {
                return ListTile(
                  title: Text(item['label']!, style: const TextStyle(color: Colors.white)),
                  trailing: _order?.status == item['key']
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await orderProvider.updateStatus(_order!.id, item['key']!);
                    if (ok) {
                      _loadDetail();
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentDialog() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final paymentStatuses = [
      {'key': 'pending', 'label': 'বকেয়া (COD/Pending)'},
      {'key': 'paid', 'label': 'পরিশোধিত (Paid)'},
      {'key': 'refunded', 'label': 'রিফান্ডেড (Refunded)'},
      {'key': 'failed', 'label': 'পেমেন্ট ব্যর্থ (Failed)'},
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
                  'পেমেন্ট স্ট্যাটাস পরিবর্তন করুন',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...paymentStatuses.map((item) {
                return ListTile(
                  title: Text(item['label']!, style: const TextStyle(color: Colors.white)),
                  trailing: _order?.paymentStatus == item['key']
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await orderProvider.updatePayment(_order!.id, item['key']!);
                    if (ok) {
                      _loadDetail();
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openCourierDispatchModal() {
    if (_order == null) return;
    String selectedCourier = 'steadfast';
    String dispatchMode = 'api'; // 'api' or 'manual'
    final consignmentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131D2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'কুরিয়ারে পার্সেল বুকিং / ডিসপ্যাচ',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Order summary preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF263345)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('অর্ডার: #${_order!.orderNumber}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('COD মূল্য: ৳${_order!.totalAmount.toInt()}', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_order!.customerName} (${_order!.customerPhone})',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _order!.deliveryAddress,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('কুরিয়ার সার্ভিস নির্বাচন করুন', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF263345)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCourier,
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceDark,
                      items: const [
                        DropdownMenuItem(value: 'steadfast', child: Text('Steadfast Courier (স্টেডফাস্ট)', style: TextStyle(color: Colors.white, fontSize: 13))),
                        DropdownMenuItem(value: 'pathao', child: Text('Pathao Courier (পাঠাও)', style: TextStyle(color: Colors.white, fontSize: 13))),
                        DropdownMenuItem(value: 'redx', child: Text('RedX Courier (রেডেক্স)', style: TextStyle(color: Colors.white, fontSize: 13))),
                        DropdownMenuItem(value: 'manual', child: Text('Manual / অন্যান্য লোকাল কুরিয়ার', style: TextStyle(color: Colors.white, fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedCourier = val;
                            if (val != 'steadfast') {
                              dispatchMode = 'manual';
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (selectedCourier == 'steadfast') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('স্বয়ংক্রিয় এপিআই', style: TextStyle(fontSize: 12))),
                          selected: dispatchMode == 'api',
                          selectedColor: AppTheme.primary,
                          onSelected: (val) {
                            if (val) setModalState(() => dispatchMode = 'api');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('ম্যানুয়াল কোড', style: TextStyle(fontSize: 12))),
                          selected: dispatchMode == 'manual',
                          selectedColor: AppTheme.primary,
                          onSelected: (val) {
                            if (val) setModalState(() => dispatchMode = 'manual');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                if (dispatchMode == 'manual' || selectedCourier != 'steadfast') ...[
                  const Text('কনসাইনমেন্ট / ট্র্যাকিং আইডি (ঐচ্ছিক)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: consignmentController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'উদা: STF-783921 বা সুন্দরবন স্লিপ নম্বর',
                      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF263345)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                            try {
                              final res = await orderProvider.dispatchCourier(
                                _order!.id,
                                courier: selectedCourier,
                                dispatchType: dispatchMode,
                                consignmentId: consignmentController.text.trim().isNotEmpty
                                    ? consignmentController.text.trim()
                                    : null,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.accentEmerald,
                                    content: Text(res['message'] ?? 'পার্সেল সফলভাবে কুরিয়ারে বুকিং করা হয়েছে!'),
                                  ),
                                );
                                _loadDetail();
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.accentRose,
                                    content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('বুকিং নিশ্চিত করুন', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openUpdateTrackingDialog() {
    if (_order == null) return;
    final courierController = TextEditingController(text: _order!.courierName ?? '');
    final trackingController = TextEditingController(text: _order!.trackingCode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ট্র্যাকিং তথ্য পরিবর্তন', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('কুরিয়ারের নাম', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: courierController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(hintText: 'উদা: Steadfast / Sundarban'),
            ),
            const SizedBox(height: 12),
            const Text('ট্র্যাকিং / কনসাইনমেন্ট কোড', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: trackingController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(hintText: 'উদা: STF-982341'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updated = await ApiService.updateOrderCourier(
                  _order!.id,
                  courierName: courierController.text.trim(),
                  trackingCode: trackingController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _order = updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.accentEmerald,
                      content: Text('ট্র্যাকিং তথ্য সফলভাবে আপডেট হয়েছে!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppTheme.accentRose, content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock() async {
    if (_order == null) return;
    try {
      final isBlocked = await ApiService.toggleBlockEntity('phone', _order!.customerPhone);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isBlocked ? AppTheme.accentRose : AppTheme.primary,
          content: Text(isBlocked ? 'এই নম্বরটি ব্লক করা হয়েছে!' : 'নম্বরটি আনব্লক করা হয়েছে।'),
        ),
      );
      _loadDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.accentRose, content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(title: const Text('অর্ডার বিবরণ')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(title: const Text('অর্ডার বিবরণ')),
        body: Center(
          child: Text(
            _errorMessage ?? 'অর্ডারের তথ্য পাওয়া যায়নি',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final o = _order!;
    final isBlocked = _security['is_phone_blocked'] == true;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('#${o.orderNumber}'),
        actions: [
          IconButton(
            icon: Icon(
              isBlocked ? Icons.block : Icons.shield_outlined,
              color: isBlocked ? AppTheme.accentRose : Colors.white,
            ),
            tooltip: isBlocked ? 'আনব্লক করুন' : 'নম্বর ব্লক করুন',
            onPressed: _toggleBlock,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Quick Action Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF263345)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ডেলিভারি স্ট্যাটাস', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(height: 6),
                          StatusBadge(status: o.status),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('পেমেন্ট স্ট্যাটাস', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(height: 6),
                          StatusBadge(status: o.paymentStatus, isPayment: true),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF263345)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showStatusDialog,
                          icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                          label: const Text('স্ট্যাটাস পরিবর্তন', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF334155)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showPaymentDialog,
                          icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                          label: const Text('পেমেন্ট আপডেট', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF334155)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF263345)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'গ্রাহকের তথ্য',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () => _callCustomer(o.customerPhone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.phone, color: AppTheme.primary, size: 14),
                              SizedBox(width: 4),
                              Text('কল করুন', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('নাম', o.customerName),
                  _buildDetailRow('ফোন নম্বর', o.customerPhone),
                  if (o.customerEmail != null && o.customerEmail!.isNotEmpty)
                    _buildDetailRow('ইমেইল', o.customerEmail!),
                  _buildDetailRow('শিপিং ঠিকানা', o.deliveryAddress.isNotEmpty ? o.deliveryAddress : 'কোনো ঠিকানা নেই'),
                  if (o.ipAddress != null)
                    _buildDetailRow('আইপি অ্যাড্রেস', o.ipAddress!),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item and Pricing Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF263345)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'অর্ডার আইটেম ও বিলিং',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${o.bookTitle} (x${o.quantity})',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Text(
                        '৳${(o.unitPrice * o.quantity).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ডেলিভারি চার্জ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      Text('৳${o.deliveryCharge.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF263345)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('সর্বমোট বিল (Total)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        '৳${o.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Courier Integration Card
            _buildCourierCard(o),
            if (_customerHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF263345)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'গ্রাহকের পূর্ববর্তী অর্ডার (${_customerHistory.length} টি)',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._customerHistory.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('#${h.orderNumber} • ${h.bookTitle}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Text('৳${h.totalAmount.toInt()}', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourierCard(OrderModel o) {
    final isDispatched = (o.trackingCode != null && o.trackingCode!.trim().isNotEmpty) ||
        o.courierStatus == 'dispatched';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDispatched ? AppTheme.accentEmerald.withOpacity(0.3) : const Color(0xFF263345),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'কুরিয়ার ডিসপ্যাচ ও ট্র্যাকিং',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isDispatched)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.accentEmerald),
                      SizedBox(width: 4),
                      Text(
                        'ডিসপ্যাচ সম্পন্ন',
                        style: TextStyle(color: AppTheme.accentEmerald, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow('কুরিয়ার', o.courierName ?? 'এখনো নির্ধারণ করা হয়নি'),
          if (isDispatched) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 110,
                    child: Text('ট্র্যাকিং কোড', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: SelectableText(
                            o.trackingCode ?? 'উপলব্ধ নয়',
                            style: const TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (o.trackingCode != null && o.trackingCode!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: o.trackingCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 1),
                                  content: Text('ট্র্যাকিং কোড কপি করা হয়েছে!'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.accentCyan),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildDetailRow('ট্র্যাকিং কোড', 'এখনো বুকিং করা হয়নি'),
          ],
          const SizedBox(height: 12),
          if (!isDispatched) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCourierDispatchModal,
                icon: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                label: const Text('কুরিয়ারে পাঠান (Dispatch Parcel)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openUpdateTrackingDialog,
                    icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.accentCyan),
                    label: const Text('তথ্য পরিবর্তন', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF263345)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCourierDispatchModal,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                    label: const Text('পুনরায় বুকিং', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF263345)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
