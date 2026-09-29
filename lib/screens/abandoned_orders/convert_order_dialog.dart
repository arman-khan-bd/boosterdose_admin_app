import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/abandoned_order_model.dart';
import '../../models/book_model.dart';
import '../../providers/abandoned_order_provider.dart';
import '../../providers/book_provider.dart';

class ConvertOrderDialog extends StatefulWidget {
  final AbandonedOrderModel lead;

  const ConvertOrderDialog({super.key, required this.lead});

  static Future<void> show(BuildContext context, AbandonedOrderModel lead) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConvertOrderDialog(lead: lead),
    );
  }

  @override
  State<ConvertOrderDialog> createState() => _ConvertOrderDialogState();
}

class _ConvertOrderDialogState extends State<ConvertOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _deliveryChargeController;
  late TextEditingController _totalAmountController;
  late TextEditingController _notesController;

  int? _selectedBookId;
  String _paymentMethod = 'cod';
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    final lead = widget.lead;

    _nameController = TextEditingController(
      text: lead.customerName != 'নামহীন লিড' ? lead.customerName : '',
    );
    _phoneController = TextEditingController(text: lead.customerPhone);
    _emailController = TextEditingController(text: lead.customerEmail ?? '');
    _addressController = TextEditingController(text: lead.deliveryAddress ?? '');

    _quantityController = TextEditingController(text: lead.quantity.toString());

    double initialUnitPrice = lead.unitPrice;
    if (initialUnitPrice <= 0 && lead.book != null) {
      final bp = lead.book!['discount_price'] ?? lead.book!['price'];
      initialUnitPrice = bp != null ? (double.tryParse(bp.toString()) ?? 0.0) : 0.0;
    }
    _unitPriceController = TextEditingController(
      text: initialUnitPrice > 0 ? initialUnitPrice.toStringAsFixed(0) : '200',
    );

    final initialCharge = lead.deliveryCharge > 0 ? lead.deliveryCharge : 60.0;
    _deliveryChargeController = TextEditingController(text: initialCharge.toStringAsFixed(0));

    double initialTotal = lead.totalAmount;
    if (initialTotal <= 0) {
      initialTotal = (initialUnitPrice * lead.quantity) + initialCharge;
    }
    _totalAmountController = TextEditingController(text: initialTotal.toStringAsFixed(0));

    _notesController = TextEditingController(
      text: lead.adminNotes ?? 'পরিত্যক্ত কার্ট #${lead.id} থেকে নিশ্চিতকৃত অর্ডার',
    );

    _selectedBookId = lead.bookId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      if (bookProvider.books.isEmpty) {
        bookProvider.fetchBooks();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _deliveryChargeController.dispose();
    _totalAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateTotal() {
    final qty = int.tryParse(_quantityController.text) ?? 1;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final delivery = double.tryParse(_deliveryChargeController.text) ?? 0.0;
    final total = (qty * unitPrice) + delivery;

    setState(() {
      _totalAmountController.text = total.toStringAsFixed(0);
    });
  }

  void _onBookSelected(BookModel book) {
    setState(() {
      _selectedBookId = book.id;
      _unitPriceController.text = book.effectivePrice.toStringAsFixed(0);
    });
    _recalculateTotal();
  }

  Future<void> _submitConvert() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isConverting = true);

    final payload = <String, dynamic>{
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      'delivery_address': _addressController.text.trim(),
      'shipping_address': _addressController.text.trim(),
      'delivery_charge': double.tryParse(_deliveryChargeController.text) ?? 60.0,
      'book_id': _selectedBookId,
      'quantity': int.tryParse(_quantityController.text) ?? 1,
      'unit_price': double.tryParse(_unitPriceController.text) ?? 0.0,
      'total_amount': double.tryParse(_totalAmountController.text) ?? 0.0,
      'payment_method': _paymentMethod,
      'status': 'pending',
      'notes': _notesController.text.trim(),
    };

    try {
      final provider = Provider.of<AbandonedOrderProvider>(context, listen: false);
      final msg = await provider.convertOrder(widget.lead.id, payload);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            behavior: SnackBarBehavior.floating,
            content: Text(e.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final books = bookProvider.books;

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF131A26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFF263345))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অর্ডারে রূপান্তর ও তথ্য এডিট',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'গ্রাহকের সাথে কথা বলে অর্ডারের ডেটা যাচাই ও সংশোধন করুন',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                    onPressed: _isConverting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info Section
                      _buildSectionTitle('গ্রাহকের যোগাযোগের তথ্য'),
                      const SizedBox(height: 8),

                      _buildFieldLabel('কাস্টমারের নাম (Customer Name)*'),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'উদাঃ তানভীর আহমেদ'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'কাস্টমারের নাম দিন' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('ফোন নম্বর (Phone Number)*'),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(hintText: '০১৭১২৩৪৫৬৭৮'),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'ফোন নম্বর আবশ্যক' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('ইমেইল (ঐচ্ছিক)'),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(hintText: 'email@...'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildFieldLabel('শিপিং ও ডেলিভারি ঠিকানা (Shipping Address)*'),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(hintText: 'বাড়ি/রোড নং, এলাকা, থানা, জেলা...'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'শিপিং ঠিকানা আবশ্যক' : null,
                      ),
                      const SizedBox(height: 18),

                      // Order Items Section
                      _buildSectionTitle('বই ও অর্ডারের পরিমাণ'),
                      const SizedBox(height: 8),

                      _buildFieldLabel('বই নির্বাচন (Book)*'),
                      DropdownButtonFormField<int>(
                        value: _selectedBookId != null && books.any((b) => b.id == _selectedBookId)
                            ? _selectedBookId
                            : (books.isNotEmpty ? books.first.id : null),
                        dropdownColor: AppTheme.surfaceDark,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        items: books.map((b) {
                          return DropdownMenuItem<int>(
                            value: b.id,
                            child: Text(
                              '${b.title} (৳${b.effectivePrice.toInt()})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final chosen = books.firstWhere((b) => b.id == val);
                            _onBookSelected(chosen);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('পরিমাণ (Qty)*'),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(hintText: '১'),
                                  validator: (v) => v == null || int.tryParse(v) == null ? 'সংখ্যা দিন' : null,
                                  onChanged: (_) => _recalculateTotal(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('একক মূল্য (৳)*'),
                                TextFormField(
                                  controller: _unitPriceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(hintText: '২০০', prefixText: '৳ '),
                                  onChanged: (_) => _recalculateTotal(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Delivery & Payment Section
                      _buildSectionTitle('ডেলিভারি চার্জ ও পেমেন্ট'),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('ডেলিভারি ফি (৳)'),
                                TextFormField(
                                  controller: _deliveryChargeController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(hintText: '৬০', prefixText: '৳ '),
                                  onChanged: (_) => _recalculateTotal(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('পেমেন্ট মেথড'),
                                DropdownButtonFormField<String>(
                                  value: _paymentMethod,
                                  dropdownColor: AppTheme.surfaceDark,
                                  isExpanded: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                  items: const [
                                    DropdownMenuItem(value: 'cod', child: Text('COD (ক্যাশ অন ডেলিভারি)', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'bkash', child: Text('বিকাশ (bKash)', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'nagad', child: Text('নগদ (Nagad)', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _paymentMethod = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildFieldLabel('মোট প্রদেয় টাকা (Total Amount ৳)*'),
                      TextFormField(
                        controller: _totalAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(hintText: '২৭০', prefixText: '৳ '),
                        validator: (v) => v == null || v.trim().isEmpty ? 'মোট মূল্য দিন' : null,
                      ),
                      const SizedBox(height: 12),

                      _buildFieldLabel('অ্যাডমিন নোট / রিমার্কস'),
                      TextFormField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(hintText: 'গ্রাহকের সাথে আলোচনার সারাংশ...'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF131A26),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFF263345))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        foregroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isConverting ? null : () => Navigator.pop(context),
                      child: const Text('বাতিল'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isConverting ? null : _submitConvert,
                      icon: _isConverting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isConverting ? 'কনভার্ট হচ্ছে...' : 'অর্ডার নিশ্চিত ও কনভার্ট করুন',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
