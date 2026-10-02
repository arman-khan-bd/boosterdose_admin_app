import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/order_model.dart';
import '../../providers/courier_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../courier/courier_manager_screen.dart';

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
  Map<String, dynamic> _courierSettings = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cp = Provider.of<CourierProvider>(context, listen: false);
      if (cp.settings == null) {
        cp.fetchCourierSettings();
      }
    });
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
        _courierSettings = res['courier_settings'] ?? {};
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

  void _copyToClipboard(String text, {String? successMessage}) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                successMessage ?? 'কপি করা হয়েছে!',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
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

  List<Map<String, String>> _getConfiguredCouriers() {
    final list = <Map<String, String>>[];
    final configuredRaw = _courierSettings['configured_couriers'];
    if (configuredRaw is List && configuredRaw.isNotEmpty) {
      for (final item in configuredRaw) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final name = item['name']?.toString() ?? id;
          if (id.isNotEmpty) {
            list.add({'id': id, 'name': name});
          }
        }
      }
    }

    if (list.isEmpty) {
      final cp = Provider.of<CourierProvider>(context, listen: false);
      final s = cp.settings;
      if (s != null) {
        if (s.isSteadfastConfigured) {
          list.add({'id': 'steadfast', 'name': 'Steadfast Courier (স্টেডফাস্ট)'});
        }
        if (s.isPathaoConfigured) {
          list.add({'id': 'pathao', 'name': 'Pathao Courier (পাঠাও)'});
        }
        if (s.isRedxConfigured) {
          list.add({'id': 'redx', 'name': 'RedX Courier (রেডেক্স)'});
        }
      }
    }
    return list;
  }

  void _showNoCourierConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF263345)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'কোনো কুরিয়ার এপিআই কনফিগার নেই',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'সরাসরি এক-ক্লিকে কুরিয়ারে বুকিং পাঠাতে Steadfast, Pathao অথবা RedX এর API Key ও Secret কনফিগার করা প্রয়োজন।',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('বন্ধ করুন', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CourierManagerScreen()),
                      ).then((_) {
                        _loadDetail();
                        Provider.of<CourierProvider>(context, listen: false).fetchCourierSettings();
                      });
                    },
                    icon: const Icon(Icons.settings, size: 16, color: Colors.black),
                    label: const Text('সেটিংস', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmItem(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: highlight ? AppTheme.primary : Colors.white,
              fontSize: 12,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCourierConfirmationDialog({
    required BuildContext bottomSheetContext,
    required String courierId,
    required String courierName,
    required String dispatchMode,
    String? consignmentId,
  }) async {
    if (_order == null) return;
    final o = _order!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isDialogSubmitting = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF131D2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF263345)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'কুরিয়ার বুকিং নিশ্চয়তা',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'আপনি কি নিশ্চিত যে নিচের অর্ডারের জন্য কুরিয়ারে বুকিং রিকোয়েস্ট পাঠাতে চান?',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF263345)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConfirmItem('অর্ডার নম্বর', '#${o.orderNumber}', highlight: true),
                        const SizedBox(height: 8),
                        _buildConfirmItem('কুরিয়ার সার্ভিস', courierName),
                        const SizedBox(height: 8),
                        _buildConfirmItem('বুকিং মোড', dispatchMode == 'api' ? 'স্বয়ংক্রিয় এপিআই (API)' : 'ম্যানুয়াল কোড'),
                        const SizedBox(height: 8),
                        _buildConfirmItem('গ্রাহকের নাম', o.customerName),
                        const SizedBox(height: 8),
                        _buildConfirmItem('ফোন নম্বর', o.customerPhone),
                        const SizedBox(height: 8),
                        _buildConfirmItem('ঠিকানা', o.deliveryAddress),
                        const Divider(color: Color(0xFF263345), height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('ক্যাশ কালেকশন (COD)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('৳${o.totalAmount.toInt()}', style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isDialogSubmitting ? null : () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isDialogSubmitting
                          ? null
                          : () async {
                              setDialogState(() => isDialogSubmitting = true);
                              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                              try {
                                final res = await orderProvider.dispatchCourier(
                                  o.id,
                                  courier: courierId,
                                  dispatchType: dispatchMode,
                                  consignmentId: consignmentId,
                                );

                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                if (bottomSheetContext.mounted) Navigator.pop(bottomSheetContext);

                                if (mounted) {
                                  _showCourierSuccessDialog(res);
                                }
                              } catch (e) {
                                setDialogState(() => isDialogSubmitting = false);
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isDialogSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'হ্যাঁ, বুকিং পাঠান',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCourierSuccessDialog(Map<String, dynamic> res) {
    final trackingCode = res['tracking_code']?.toString() ?? res['consignment_id']?.toString() ?? '';
    final courierName = res['courier_name']?.toString() ?? 'কুরিয়ার সার্ভিস';
    final orderNum = res['order_number']?.toString() ?? _order?.orderNumber ?? '';
    final customerName = res['customer_name']?.toString() ?? _order?.customerName ?? '';
    final customerPhone = res['customer_phone']?.toString() ?? _order?.customerPhone ?? '';
    final totalAmount = res['total_amount']?.toString() ?? (_order?.totalAmount.toInt().toString() ?? '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF263345)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentEmerald.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.35), width: 2),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentEmerald,
                size: 46,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'কুরিয়ারে বুকিং সফল হয়েছে!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              res['message']?.toString() ?? 'পার্সেল সফলভাবে কুরিয়ার সার্ভিসে এন্ট্রি হয়েছে।',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (trackingCode.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'কনসাইনমেন্ট / ট্র্যাকিং আইডি',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            trackingCode,
                            style: const TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            trackingCode,
                            successMessage: 'ট্র্যাকিং কোড কপি করা হয়েছে!',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary),
                                SizedBox(width: 4),
                                Text(
                                  'কপি',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF263345)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('কুরিয়ার', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text(courierName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('অর্ডার', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text('#$orderNum', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (customerName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('গ্রাহক', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Text('$customerName ($customerPhone)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ক্যাশ কালেকশন (COD)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text('৳$totalAmount', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadDetail();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ঠিক আছে (সম্পন্ন)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCourierDispatchModal() {
    if (_order == null) return;
    final configuredCouriers = _getConfiguredCouriers();
    if (configuredCouriers.isEmpty) {
      _showNoCourierConfiguredDialog();
      return;
    }

    String selectedCourier = configuredCouriers.first['id']!;
    final defaultProvider = _courierSettings['provider']?.toString();
    if (defaultProvider != null && configuredCouriers.any((c) => c['id'] == defaultProvider)) {
      selectedCourier = defaultProvider;
    }

    String dispatchMode = 'api'; // 'api' or 'manual'
    final consignmentController = TextEditingController();

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

                const Text('কুরিয়ার সার্ভিস নির্বাচন করুন (শুধু কনফিগারকৃত)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
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
                      items: configuredCouriers.map((courier) {
                        return DropdownMenuItem<String>(
                          value: courier['id'],
                          child: Text(
                            courier['name'] ?? courier['id']!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
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
                      hintText: 'উদা: STF-783921 বা কনসাইনমেন্ট নম্বর',
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final selectedCourierItem = configuredCouriers.firstWhere(
                        (c) => c['id'] == selectedCourier,
                        orElse: () => {'id': selectedCourier, 'name': selectedCourier},
                      );
                      _showCourierConfirmationDialog(
                        bottomSheetContext: ctx,
                        courierId: selectedCourier,
                        courierName: selectedCourierItem['name'] ?? selectedCourier,
                        dispatchMode: dispatchMode,
                        consignmentId: consignmentController.text.trim().isNotEmpty
                            ? consignmentController.text.trim()
                            : null,
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                    label: const Text('বুকিং নিশ্চিত করতে এগিয়ে যান', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
            tooltip: 'অর্ডার ডাটা কপি করুন',
            onPressed: () => _copyToClipboard(
              o.copyableOrderData,
              successMessage: 'অর্ডারের সম্পূর্ণ ডাটা (নাম, ফোন, ঠিকানা) কপি হয়েছে!',
            ),
          ),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _copyToClipboard(
                              o.copyableOrderData,
                              successMessage: 'অর্ডারের সম্পূর্ণ ডাটা (নাম, ফোন, ঠিকানা) কপি হয়েছে!',
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'ডাটা কপি',
                                    style: TextStyle(
                                      color: AppTheme.accentCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _callCustomer(o.customerPhone),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow(
                    'নাম',
                    o.customerName,
                    copyValue: o.customerName,
                    copyLabel: 'গ্রাহকের নাম',
                  ),
                  _buildDetailRow(
                    'ফোন নম্বর',
                    o.customerPhone,
                    copyValue: o.customerPhone,
                    copyLabel: 'ফোন নম্বর',
                  ),
                  if (o.customerEmail != null && o.customerEmail!.isNotEmpty)
                    _buildDetailRow(
                      'ইমেইল',
                      o.customerEmail!,
                      copyValue: o.customerEmail!,
                      copyLabel: 'ইমেইল',
                    ),
                  _buildDetailRow(
                    'শিপিং ঠিকানা',
                    o.deliveryAddress.isNotEmpty ? o.deliveryAddress : 'কোনো ঠিকানা নেই',
                    copyValue: o.deliveryAddress.isNotEmpty ? o.deliveryAddress : null,
                    copyLabel: 'শিপিং ঠিকানা',
                  ),
                  if (o.ipAddress != null)
                    _buildDetailRow(
                      'আইপি অ্যাড্রেস',
                      o.ipAddress!,
                      copyValue: o.ipAddress,
                      copyLabel: 'আইপি অ্যাড্রেস',
                    ),
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
                            onTap: () => _copyToClipboard(
                              o.trackingCode!,
                              successMessage: 'ট্র্যাকিং কোড কপি করা হয়েছে!',
                            ),
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

  Widget _buildDetailRow(
    String label,
    String value, {
    String? copyValue,
    String? copyLabel,
  }) {
    final canCopy = copyValue != null && copyValue.trim().isNotEmpty;

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
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _copyToClipboard(
                copyValue,
                successMessage: '${copyLabel ?? label} কপি করা হয়েছে!',
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF263345)),
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
