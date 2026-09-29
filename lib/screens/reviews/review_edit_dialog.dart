import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_network_image.dart';
import '../../config/app_theme.dart';
import '../../models/review_model.dart';
import '../../providers/book_provider.dart';
import '../../providers/review_provider.dart';

class ReviewEditDialog extends StatefulWidget {
  final ReviewModel? review;
  final bool initialApprove;

  const ReviewEditDialog({
    super.key,
    this.review,
    this.initialApprove = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    ReviewModel? review,
    bool initialApprove = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewEditDialog(
        review: review,
        initialApprove: initialApprove,
      ),
    );
  }

  @override
  State<ReviewEditDialog> createState() => _ReviewEditDialogState();
}

class _ReviewEditDialogState extends State<ReviewEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _commentController;
  late TextEditingController _screenshotUrlController;

  int? _selectedBookId;
  int _rating = 5;
  String _source = 'whatsapp';
  bool _isActive = true;
  bool _isFeatured = false;
  bool _removeScreenshot = false;

  Uint8List? _newScreenshotBytes;
  String? _newScreenshotFilename;

  bool _isSubmitting = false;

  final List<Map<String, String>> _sources = [
    {'key': 'whatsapp', 'label': 'হোয়াটসঅ্যাপ (WhatsApp)'},
    {'key': 'messenger', 'label': 'মেসেঞ্জার (Messenger)'},
    {'key': 'facebook', 'label': 'ফেসবুক (Facebook)'},
    {'key': 'website', 'label': 'ওয়েবসাইট (Website)'},
    {'key': 'delivery', 'label': 'কুরিয়ার / আনবক্সিং'},
  ];

  @override
  void initState() {
    super.initState();
    final rev = widget.review;

    _nameController = TextEditingController(text: rev?.reviewerName ?? '');
    _designationController = TextEditingController(text: rev?.designation ?? '');
    _commentController = TextEditingController(text: rev?.comment ?? '');
    _screenshotUrlController = TextEditingController(text: rev?.screenshotUrl ?? '');

    _selectedBookId = rev?.bookId;
    _rating = rev?.rating ?? 5;
    _source = rev?.source ?? 'whatsapp';

    // If opening with initialApprove or creating new, default to active: true
    if (widget.initialApprove) {
      _isActive = true;
    } else {
      _isActive = rev?.isActive ?? true;
    }

    _isFeatured = rev?.isFeatured ?? false;

    // Load books if needed
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
    _designationController.dispose();
    _commentController.dispose();
    _screenshotUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: source,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _newScreenshotBytes = bytes;
          _newScreenshotFilename = file.name;
          _removeScreenshot = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ছবি নির্বাচন ত্রুটি: $e'),
          backgroundColor: AppTheme.accentRose,
        ),
      );
    }
  }

  Future<void> _saveReview({bool approve = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

      final shouldBeActive = approve ? true : _isActive;
      final Map<String, dynamic> data = {
        'reviewer_name': _nameController.text.trim(),
        'designation': _designationController.text.trim().isNotEmpty
            ? _designationController.text.trim()
            : null,
        'book_id': _selectedBookId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'source': _source,
        'is_active': shouldBeActive,
        'is_featured': _isFeatured,
        'approve': approve || shouldBeActive,
        'publish': approve || shouldBeActive,
      };

      if (_removeScreenshot) {
        data['remove_screenshot'] = true;
      } else if (_screenshotUrlController.text.trim().isNotEmpty && _newScreenshotBytes == null) {
        data['screenshot_url'] = _screenshotUrlController.text.trim();
      }

      bool success = false;
      if (widget.review != null) {
        final result = await reviewProvider.updateReview(
          widget.review!.id,
          data,
          screenshotBytes: _newScreenshotBytes,
          screenshotFilename: _newScreenshotFilename,
        );
        success = result != null;
      } else {
        final result = await reviewProvider.createReview(
          data,
          screenshotBytes: _newScreenshotBytes,
          screenshotFilename: _newScreenshotFilename,
        );
        success = result != null;
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      approve
                          ? 'রিভিউটি সফলভাবে এডিট ও অনুমোদন করা হয়েছে!'
                          : 'রিভিউ তথ্য সফলভাবে সংরক্ষণ করা হয়েছে!',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reviewProvider.errorMessage ?? 'সংরক্ষণ ব্যর্থ হয়েছে'),
              backgroundColor: AppTheme.accentRose,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ত্রুটি: $e'),
            backgroundColor: AppTheme.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final isEditing = widget.review != null;
    final isPending = widget.review != null && !widget.review!.isActive;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeader(isEditing, isPending),

          const Divider(height: 1, color: Color(0xFF263345)),

          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Approval Notice Banner
                    if (isPending) _buildPendingAlertNotice(),

                    // Reviewer Name & Designation
                    _buildSectionTitle('শিক্ষার্থী / রিভিউয়ারের তথ্য', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'শিক্ষার্থীর নাম *',
                        hintText: 'উদা: তাওহীদ হাসান',
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF161F30),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'শিক্ষার্থীর নাম দিন';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _designationController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'ব্যাচ / কলেজ / শিক্ষাপ্রতিষ্ঠান',
                        hintText: 'উদা: DMC-52 / নটর ডেম কলেজ / HSC-24',
                        prefixIcon: const Icon(Icons.school_outlined, color: AppTheme.accentCyan, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF161F30),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Book Selection
                    _buildSectionTitle('বই নির্বাচন (Review for Book)', Icons.menu_book_rounded),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF263345)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedBookId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF161F30),
                          hint: const Text('সাধারণ রিভিউ (কোন বই নির্দিষ্ট নয়)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('সাধারণ রিভিউ (ওয়েবসাইট / সব বই)', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14)),
                            ),
                            ...bookProvider.books.map((b) => DropdownMenuItem<int?>(
                              value: b.id,
                              child: Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            )),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedBookId = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Rating Selector
                    _buildSectionTitle('স্টার রেটিং (Rating)', Icons.star_rounded),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF263345)),
                      ),
                      child: Row(
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              return IconButton(
                                icon: Icon(
                                  starNum <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: AppTheme.accentAmber,
                                  size: 32,
                                ),
                                onPressed: () {
                                  setState(() => _rating = starNum);
                                },
                              );
                            }),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
                            ),
                            child: Text(
                              '$_rating / ৫ স্টার',
                              style: const TextStyle(
                                color: AppTheme.accentAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Comment / Feedback Text
                    _buildSectionTitle('শিক্ষার্থীর মন্তব্য ও ফিডব্যাক', Icons.comment_outlined),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commentController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'শিক্ষার্থীর রিভিউ বা চ্যাট থেকে প্রাপ্ত গুরুত্বপূর্ণ কথা এখানে লিখুন...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF161F30),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Screenshot / Chat Proof Image
                    _buildSectionTitle('চ্যাট স্ক্রিনশট বা প্রুফ ছবি', Icons.image_outlined),
                    const SizedBox(height: 12),
                    _buildScreenshotSection(),

                    const SizedBox(height: 20),

                    // Source Selector
                    _buildSectionTitle('রিভিউয়ের উৎস (Source)', Icons.share_outlined),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF263345)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _source,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF161F30),
                          items: _sources.map((s) => DropdownMenuItem<String>(
                            value: s['key'],
                            child: Text(s['label']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _source = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Switches: Approval & Featured
                    _buildSectionTitle('অনুমোদন ও প্রদর্শন সেটিংস', Icons.toggle_on_outlined),
                    const SizedBox(height: 12),
                    _buildStatusSwitches(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(isPending),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isEditing, bool isPending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? Icons.rate_review_rounded : Icons.add_comment_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? (isPending ? 'রিভিউ এডিটর ও অনুমোদন' : 'রিভিউ তথ্য এডিট')
                      : 'নতুন রিভিউ যোগ করুন',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isEditing
                      ? 'অনুমোদনের আগে টেক্সট ও ছবি সংশোধন করুন'
                      : 'ম্যানুয়াল রিভিউ বা চ্যাট প্রুফ সেভ করুন',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPending ? AppTheme.accentAmber.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPending ? AppTheme.accentAmber.withOpacity(0.4) : AppTheme.primary.withOpacity(0.4),
                ),
              ),
              child: Text(
                isPending ? 'অপেক্ষমাণ' : 'অনুমোদিত',
                style: TextStyle(
                  color: isPending ? AppTheme.accentAmber : AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlertNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'এই রিভিউটি বর্তমানে পেন্ডিং আছে। টেক্সট বা তথ্যে কোনো বানান বা ফরম্যাটিং ভুল থাকলে তা ঠিক করে নিচে "সংরক্ষণ ও অনুমোদন" বাটনে চাপুন।',
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotSection() {
    final urlFromText = _screenshotUrlController.text.trim();
    final effectiveUrl = urlFromText.isNotEmpty
        ? urlFromText
        : (!_removeScreenshot && widget.review?.screenshotUrl != null && widget.review!.screenshotUrl!.isNotEmpty
            ? widget.review!.screenshotUrl
            : null);
    final hasScreenshotToDisplay = effectiveUrl != null && effectiveUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If new bytes picked
          if (_newScreenshotBytes != null) ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _newScreenshotBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'নতুন ছবি প্রস্তুত (${_newScreenshotFilename ?? "image.jpg"})',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _newScreenshotBytes = null;
                      _newScreenshotFilename = null;
                    });
                  },
                  child: const Text('রিমুভ', style: TextStyle(color: AppTheme.accentRose, fontSize: 12)),
                ),
              ],
            ),
          ]
          // If has screenshot from URL or existing review
          else if (hasScreenshotToDisplay) ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(
                  imageUrl: effectiveUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(10),
                  fallbackIcon: Icons.image_not_supported_outlined,
                  fallbackText: 'ছবি লোড করা যায়নি',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  urlFromText.isNotEmpty ? 'লিংক প্রিভিউ' : 'বিদ্যমান স্ক্রিনশট',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _removeScreenshot = true;
                      _screenshotUrlController.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: AppTheme.accentRose, size: 16),
                  label: const Text('স্ক্রিনশট মুছুন', style: TextStyle(color: AppTheme.accentRose, fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF64748B), size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _removeScreenshot ? 'স্ক্রিনশট মুছে ফেলা হবে' : 'কোনো স্ক্রিনশট প্রুফ নেই',
                    style: TextStyle(
                      color: _removeScreenshot ? AppTheme.accentRose : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: Color(0xFF263345)),
          const SizedBox(height: 8),

          // Pick from gallery/camera buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.primary),
                  label: const Text('গ্যালারি থেকে নিন', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF263345)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16, color: AppTheme.accentCyan),
                  label: const Text('ক্যামেরা তুলুন', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF263345)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Direct Image URL Field with Live Update
          TextFormField(
            controller: _screenshotUrlController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'অথবা ইমেজ লিংক পেস্ট করুন (Image URL)',
              hintText: 'https://...',
              helperText: 'সরাসরি ছবির লিংক বা Google Drive লিংক দিলে সাথে সাথে প্রিভিউ দেখাবে',
              helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
              prefixIcon: const Icon(Icons.link, color: AppTheme.primary, size: 18),
              suffixIcon: _screenshotUrlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _screenshotUrlController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF263345))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF263345))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
            ),
            onChanged: (val) {
              setState(() {
                _removeScreenshot = false;
                _newScreenshotBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSwitches() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _isActive,
            onChanged: (val) => setState(() => _isActive = val),
            activeColor: AppTheme.primary,
            title: const Text(
              'অনুমোদন করুন (Approve & Make Active)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'সক্রিয় থাকলে ওয়েবসাইটে এবং বইয়ের ল্যান্ডিং পেজে দৃশ্যমান হবে',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263345)),
          SwitchListTile(
            value: _isFeatured,
            onChanged: (val) => setState(() => _isFeatured = val),
            activeColor: AppTheme.accentAmber,
            title: const Text(
              'ফিচার্ড রিভিউ (Featured on Storefront)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'হোমপেজ ও বিশেষ সেকশনের টপ রিভিউ হিসেবে প্রদর্শিত হবে',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool isPending) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161F30),
        border: Border(top: BorderSide(color: Color(0xFF263345))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel Button
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
              ),
            ),

            const SizedBox(width: 12),

            // If pending, offer "Save Only" and prominent "Save & Approve"
            if (isPending) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => _saveReview(approve: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF475569)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('শুধু সংরক্ষণ', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _saveReview(approve: true),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.black),
                  label: Text(
                    _isSubmitting ? 'প্রসেসিং...' : 'সংরক্ষণ ও অনুমোদন',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
            ] else ...[
              // If already active or new review
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _saveReview(approve: _isActive),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save_rounded, size: 20, color: Colors.black),
                  label: Text(
                    _isSubmitting ? 'সংরক্ষণ হচ্ছে...' : 'পরিবর্তন সংরক্ষণ করুন',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
