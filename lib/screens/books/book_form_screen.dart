import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/book_provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_network_image.dart';

class BookFormScreen extends StatefulWidget {
  final BookModel? book;

  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Basic Info Controllers
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _slugController;
  late TextEditingController _authorController;
  late TextEditingController _categoryController;
  late TextEditingController _badgeController;

  // Price & Inventory
  late TextEditingController _priceController;
  late TextEditingController _discountPriceController;
  late TextEditingController _stockController;
  String _stockStatus = 'in_stock';

  // Specifications
  late TextEditingController _pagesController;
  late TextEditingController _editionController;
  late TextEditingController _paperQualityController;
  late TextEditingController _bindingTypeController;
  late TextEditingController _samplePdfController;

  // Description & Features
  late TextEditingController _descriptionController;
  final List<String> _features = [];
  final TextEditingController _newFeatureController = TextEditingController();

  // Cover Image
  String? _existingCoverUrl;
  Uint8List? _newCoverBytes;
  String? _newCoverFilename;
  late TextEditingController _customImageUrlController;

  // Gallery Images
  final List<String> _galleryImages = [];
  final TextEditingController _newGalleryUrlController = TextEditingController();

  // Toggles
  bool _freeDelivery = false;
  bool _isFeatured = false;
  bool _isCombo = false;

  bool _isSaving = false;
  String? _uploadStatusText;

  @override
  void initState() {
    super.initState();
    final b = widget.book;

    _titleController = TextEditingController(text: b?.title ?? '');
    _subtitleController = TextEditingController(text: b?.subtitle ?? '');
    _slugController = TextEditingController(text: b?.slug ?? '');
    _authorController = TextEditingController(text: b?.author ?? 'মো. সুমন হাসান');
    _categoryController = TextEditingController(text: b?.category ?? 'HSC ২০২৬-২৭ (HSC ২০২৭)');
    _badgeController = TextEditingController(text: b?.badge ?? 'বেস্টসেলার');

    _priceController = TextEditingController(text: b != null ? b.price.toStringAsFixed(0) : '');
    _discountPriceController = TextEditingController(text: b != null && b.discountPrice > 0 ? b.discountPrice.toStringAsFixed(0) : '');
    _stockController = TextEditingController(text: b != null ? b.stockCount.toString() : '100');
    _stockStatus = b?.stockStatus ?? 'in_stock';

    _pagesController = TextEditingController(text: b != null && b.pages > 0 ? b.pages.toString() : '116');
    _editionController = TextEditingController(text: b?.edition ?? 'তৃতীয় সংস্করণ');
    _paperQualityController = TextEditingController(text: b?.paperQuality ?? '৬৫ জিএসএম অফসেট হোয়াইট');
    _bindingTypeController = TextEditingController(text: b?.bindingType ?? 'ডিলাক্স পেপারব্যাক ল্যামিনেশন');
    _samplePdfController = TextEditingController(text: b?.samplePdfUrl ?? '');

    _descriptionController = TextEditingController(text: b?.description ?? '');
    if (b != null && b.features.isNotEmpty) {
      _features.addAll(b.features);
    }

    _existingCoverUrl = b?.coverImage;
    _customImageUrlController = TextEditingController(text: b?.coverImage ?? '');
    _customImageUrlController.addListener(() {
      final text = _customImageUrlController.text.trim();
      if (_newCoverBytes == null && text != (_existingCoverUrl ?? '')) {
        setState(() {
          _existingCoverUrl = text.isNotEmpty ? text : null;
        });
      }
    });

    if (b != null && b.galleryImages.isNotEmpty) {
      _galleryImages.addAll(b.galleryImages);
    }

    _freeDelivery = b?.freeDelivery ?? false;
    _isFeatured = b?.isFeatured ?? false;
    _isCombo = b?.isCombo ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _slugController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    _badgeController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _pagesController.dispose();
    _editionController.dispose();
    _paperQualityController.dispose();
    _bindingTypeController.dispose();
    _samplePdfController.dispose();
    _descriptionController.dispose();
    _newFeatureController.dispose();
    _customImageUrlController.dispose();
    _newGalleryUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: source,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _newCoverBytes = bytes;
          _newCoverFilename = file.name;
          _customImageUrlController.text = '';
        });
      }
    } catch (e) {
      _showError('ছবি নির্বাচন করতে সমস্যা হয়েছে: $e');
    }
  }

  Future<void> _pickGalleryImage() async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: ImageSource.gallery,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null) {
        setState(() {
          _uploadStatusText = 'স্যাম্পল ছবি আপলোড হচ্ছে...';
        });
        final bytes = await file.readAsBytes();
        final provider = Provider.of<BookProvider>(context, listen: false);
        final url = await provider.uploadImage(bytes, file.name, type: 'sample');
        if (url != null) {
          setState(() {
            _galleryImages.add(url);
            _uploadStatusText = null;
          });
        } else {
          setState(() => _uploadStatusText = null);
          _showError(provider.errorMessage ?? 'স্যাম্পল ছবি আপলোড ব্যর্থ হয়েছে');
        }
      }
    } catch (e) {
      setState(() => _uploadStatusText = null);
      _showError('ছবি আপলোডে সমস্যা: $e');
    }
  }

  void _showAddGalleryUrlDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentUrl = urlController.text.trim();
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('ইমেজ URL দিয়ে স্যাম্পল যোগ করুন', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ছবির সরাসরি লিংক (https://..., Google Drive ইত্যাদি) পেস্ট করুন:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: urlController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      suffixIcon: currentUrl.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                urlController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (currentUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('লাইভ প্রিভিউ:', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Center(
                      child: AppNetworkImage(
                        imageUrl: currentUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(10),
                        showBorder: true,
                        fallbackIcon: Icons.broken_image_rounded,
                        fallbackText: 'প্রিভিউ পাওয়া যায়নি',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: currentUrl.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _galleryImages.add(currentUrl);
                        });
                        Navigator.pop(ctx);
                      },
                child: const Text('যোগ করুন'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addFeature() {
    final text = _newFeatureController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _features.add(text);
        _newFeatureController.clear();
      });
    }
  }

  void _removeFeature(int index) {
    setState(() => _features.removeAt(index));
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      _showError('দয়া করে প্রয়োজনীয় ফিল্ডগুলো পূরণ করুন');
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadStatusText = 'তথ্য প্রস্তুত করা হচ্ছে...';
    });

    final provider = Provider.of<BookProvider>(context, listen: false);

    // 1. Upload Cover Image if new bytes selected
    String? coverPath = _existingCoverUrl;
    if (_newCoverBytes != null && _newCoverFilename != null) {
      setState(() => _uploadStatusText = 'কভার ছবি আপলোড ও অপটিমাইজ হচ্ছে...');
      final uploadedPath = await provider.uploadImage(
        _newCoverBytes!,
        _newCoverFilename!,
        type: 'cover',
      );
      if (uploadedPath != null) {
        coverPath = uploadedPath;
      } else {
        setState(() => _isSaving = false);
        _showError(provider.errorMessage ?? 'কভার ছবি আপলোড ব্যর্থ হয়েছে।');
        return;
      }
    } else if (_customImageUrlController.text.trim().isNotEmpty) {
      coverPath = _customImageUrlController.text.trim();
    }

    // 2. Prepare payload
    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'subtitle': _subtitleController.text.trim().isNotEmpty ? _subtitleController.text.trim() : null,
      'slug': _slugController.text.trim().isNotEmpty ? _slugController.text.trim() : null,
      'author': _authorController.text.trim(),
      'category': _categoryController.text.trim(),
      'badge': _badgeController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'discount_price': double.tryParse(_discountPriceController.text) ?? 0.0,
      'stock_count': int.tryParse(_stockController.text) ?? 100,
      'stock_status': _stockStatus,
      'pages': int.tryParse(_pagesController.text) ?? 0,
      'edition': _editionController.text.trim(),
      'paper_quality': _paperQualityController.text.trim(),
      'binding_type': _bindingTypeController.text.trim(),
      'sample_pdf_url': _samplePdfController.text.trim().isNotEmpty ? _samplePdfController.text.trim() : null,
      'description': _descriptionController.text.trim(),
      'features': _features,
      'free_delivery': _freeDelivery,
      'is_featured': _isFeatured,
      'is_combo': _isCombo,
      'gallery_images': _galleryImages,
    };

    if (coverPath != null && coverPath.isNotEmpty) {
      data['cover_image'] = coverPath;
    }

    setState(() => _uploadStatusText = 'বইয়ের ডেটা সেভ করা হচ্ছে...');

    bool ok;
    if (widget.book == null) {
      ok = await provider.createBook(data);
    } else {
      ok = await provider.updateBook(widget.book!.id, data);
    }

    setState(() {
      _isSaving = false;
      _uploadStatusText = null;
    });

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black),
              const SizedBox(width: 10),
              Text(
                widget.book == null ? 'নতুন বই সফলভাবে যোগ করা হয়েছে!' : 'বইয়ের সমস্ত তথ্য সফলভাবে আপডেট হয়েছে!',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      _showError(provider.errorMessage ?? 'সেভ করতে ব্যর্থ হয়েছে।');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentRose,
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(isEdit ? 'বই এডিট ও বিস্তারিত তথ্য' : 'নতুন বই যোগ করুন'),
        actions: [
          TextButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
            label: Text(
              isEdit ? 'আপডেট' : 'পাবলিশ',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: _isSaving ? null : _saveBook,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: const Border(top: BorderSide(color: Color(0xFF263345))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              child: _isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(_uploadStatusText ?? 'সংরক্ষণ হচ্ছে...', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text(
                      isEdit ? 'সমস্ত পরিবর্তন সংরক্ষণ করুন' : 'নতুন বই প্রকাশ করুন',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover Image Card
              _buildSectionHeader('১. বইয়ের কভার ছবি (Cover Image & Upload)', Icons.image_rounded),
              _buildCoverImageCard(),
              const SizedBox(height: 20),

              // 2. Basic Info Card
              _buildSectionHeader('২. প্রাথমিক বিবরণ (Basic Information)', Icons.menu_book_rounded),
              _buildBasicInfoCard(),
              const SizedBox(height: 20),

              // 3. Price & Inventory Card
              _buildSectionHeader('৩. মূল্য ও স্টক ম্যানেজমেন্ট (Pricing & Stock)', Icons.monetization_on_rounded),
              _buildPricingCard(),
              const SizedBox(height: 20),

              // 4. Specifications Card
              _buildSectionHeader('৪. প্রিন্ট ও বই স্পেসিফিকেশন (Print Specifications)', Icons.auto_stories_rounded),
              _buildSpecsCard(),
              const SizedBox(height: 20),

              // 5. Description Card
              _buildSectionHeader('৫. বইয়ের বিস্তারিত বর্ণনা (Description)', Icons.description_rounded),
              _buildDescriptionCard(),
              const SizedBox(height: 20),

              // 6. Features Card
              _buildSectionHeader('৬. বইয়ের মূল বৈশিষ্ট্যসমূহ (Highlights & Features)', Icons.checklist_rounded),
              _buildFeaturesCard(),
              const SizedBox(height: 20),

              // 7. Gallery Sample Pages Card
              _buildSectionHeader('৭. ডেমো ও স্যাম্পল পাতা ছবি (Gallery Samples)', Icons.collections_rounded),
              _buildGalleryCard(),
              const SizedBox(height: 20),

              // 8. Toggles Card
              _buildSectionHeader('৮. অতিরিক্ত সেটিংস (Badges & Settings)', Icons.tune_rounded),
              _buildTogglesCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCoverImageCard() {
    return _buildCardContainer(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Box
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 110,
                height: 155,
                color: const Color(0xFF1E293B),
                child: _newCoverBytes != null
                    ? Image.memory(_newCoverBytes!, fit: BoxFit.cover)
                    : (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty)
                        ? AppNetworkImage(
                            imageUrl: _existingCoverUrl!,
                            width: 110,
                            height: 155,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                            fallbackIcon: Icons.book_rounded,
                            fallbackText: 'ছবি লোড হয়নি',
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primary, size: 36),
                                SizedBox(height: 6),
                                Text('ছবি নেই', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 16),
            // Upload Controls
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'বইয়ের ফ্রন্ট কভার ছবি',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'আপলোড করা ছবি স্বয়ংক্রিয়ভাবে WebP ও Thumbnail ফরম্যাটে অপটিমাইজ হবে।',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.18),
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('গ্যালারি', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickCoverImage(ImageSource.gallery),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('ক্যামেরা', style: TextStyle(fontSize: 12)),
                        onPressed: () => _pickCoverImage(ImageSource.camera),
                      ),
                      if (_newCoverBytes != null)
                        TextButton.icon(
                          icon: const Icon(Icons.restore, color: AppTheme.accentRose, size: 16),
                          label: const Text('রিসেট', style: TextStyle(color: AppTheme.accentRose, fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _newCoverBytes = null;
                              _newCoverFilename = null;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF263345)),
        const SizedBox(height: 8),
        _buildFieldLabel('অথবা কভার ছবির ডিরেক্ট URL লিংক পেস্ট করুন'),
        TextFormField(
          controller: _customImageUrlController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://boosterdose.shop/uploads/books/cover.webp',
            helperText: 'সরাসরি লিংক বা Google Drive লিংক পেস্ট করলে সাথে সাথে প্রিভিউ দেখাবে',
            helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.primary, size: 18),
            suffixIcon: _customImageUrlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () {
                      _customImageUrlController.clear();
                      setState(() {
                        _existingCoverUrl = null;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {
              _existingCoverUrl = val.trim().isNotEmpty ? val.trim() : null;
              _newCoverBytes = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCardContainer(
      children: [
        _buildFieldLabel('বইয়ের নাম (Title)*'),
        TextFormField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'উদাঃ এইচএসসি ২০২৭ বাংলা দ্বিতীয় পত্র বাংলা বুস্টার ডোজ'),
          validator: (v) => v == null || v.trim().isEmpty ? 'বইয়ের নাম আবশ্যক' : null,
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('উপ-শিরোনাম (Subtitle)'),
        TextFormField(
          controller: _subtitleController,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'উদাঃ স্বল্প পরিশ্রমে (A+) অর্জনের বিশেষ কৌশল ও পূর্ণাঙ্গ সমাধান'),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('লেখক (Author)*'),
                  TextFormField(
                    controller: _authorController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'মো. সুমন হাসান'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'লেখক আবশ্যক' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('ক্যাটাগরি (Category)'),
                  TextFormField(
                    controller: _categoryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'HSC ২০২৬-২৭'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('ব্যাজ/ট্যাগ (Badge)'),
                  TextFormField(
                    controller: _badgeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'বেস্টসেলার / হট ডিল'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('কাস্টম URL স্ল্যাগ (Slug)'),
                  TextFormField(
                    controller: _slugController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'hsc-bangla-2nd-paper'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingCard() {
    final regular = double.tryParse(_priceController.text) ?? 0.0;
    final discount = double.tryParse(_discountPriceController.text) ?? 0.0;
    final effective = discount > 0 ? discount : regular;

    return _buildCardContainer(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('রেগুলার মূল্য (৳)*'),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: '২২০', prefixText: '৳ '),
                    validator: (v) => v == null || v.trim().isEmpty ? 'মূল্য আবশ্যক' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('ডিসকাউন্ট অফার মূল্য (৳)'),
                  TextFormField(
                    controller: _discountPriceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: '২০০', prefixText: '৳ '),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('কাস্টমার যে মূল্যে কিনবে:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              Text('৳${effective.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('স্টক সংখ্যা (Stock)*'),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: '১০০'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'স্টক সংখ্যা দিন' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('স্টক অবস্থা (Stock Status)'),
                  DropdownButtonFormField<String>(
                    value: _stockStatus,
                    dropdownColor: AppTheme.surfaceDark,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    items: const [
                      DropdownMenuItem(value: 'in_stock', child: Text('🟢 ইন স্টক (In Stock)')),
                      DropdownMenuItem(value: 'limited_stock', child: Text('🟡 সীমিত স্টক (Limited)')),
                      DropdownMenuItem(value: 'out_of_stock', child: Text('🔴 স্টক শেষ (Out of Stock)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _stockStatus = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecsCard() {
    return _buildCardContainer(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('মোট পৃষ্ঠা সংখ্যা (Pages)'),
                  TextFormField(
                    controller: _pagesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: '১১৬'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('সংস্করণ (Edition)'),
                  TextFormField(
                    controller: _editionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'তৃতীয় সংস্করণ'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('কাগজের মান (Paper Quality)'),
                  TextFormField(
                    controller: _paperQualityController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: '৬৫ জিএসএম অফসেট'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('বাইন্ডিং ধরন (Binding)'),
                  TextFormField(
                    controller: _bindingTypeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'ডিলাক্স পেপারব্যাক'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('নমুনা পিডিএফ ডাউনলোড লিংক (Sample PDF URL)'),
        TextFormField(
          controller: _samplePdfController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'https://.../sample.pdf'),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return _buildCardContainer(
      children: [
        _buildFieldLabel('বই সম্পর্কে বিস্তারিত বর্ণনা (Description)'),
        TextFormField(
          controller: _descriptionController,
          maxLines: 6,
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'বইয়ের সূচিপত্র, প্রেক্ষাপট, শিক্ষার্থীদের জন্য কীভাবে উপকারে আসবে তার বিস্তারিত বর্ণনা...',
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesCard() {
    return _buildCardContainer(
      children: [
        const Text(
          'বইয়ের প্রধান প্রধান আকর্ষণ ও বৈশিষ্ট্য (Bullet Highlights):',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 10),

        if (_features.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _features.length,
            itemBuilder: (ctx, i) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_features[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.accentRose, size: 16),
                    onPressed: () => _removeFeature(i),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _newFeatureController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(hintText: 'নতুন পয়েন্ট যোগ করুন...'),
                onFieldSubmitted: (_) => _addFeature(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _addFeature,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('যোগ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGalleryCard() {
    return _buildCardContainer(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 430;
            return isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'বইয়ের ভিতরের পাতা ও সূচিপত্র প্রিভিউ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF334155)),
                              ),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 16, color: AppTheme.accentCyan),
                            label: const Text('URL থেকে যোগ', style: TextStyle(fontSize: 12)),
                            onPressed: _showAddGalleryUrlDialog,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withOpacity(0.18),
                              foregroundColor: AppTheme.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppTheme.primary),
                              ),
                            ),
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('আপলোড', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _pickGalleryImage,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'বইয়ের ভিতরের পাতা ও সূচিপত্র প্রিভিউ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF334155)),
                              ),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 16, color: AppTheme.accentCyan),
                            label: const Text('URL থেকে যোগ', style: TextStyle(fontSize: 12)),
                            onPressed: _showAddGalleryUrlDialog,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withOpacity(0.18),
                              foregroundColor: AppTheme.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppTheme.primary),
                              ),
                            ),
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('আপলোড', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _pickGalleryImage,
                          ),
                        ],
                      ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 12),

        if (_galleryImages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155), style: BorderStyle.solid),
            ),
            child: const Center(
              child: Text(
                'কোনো স্যাম্পল ছবি যোগ করা হয়নি। উপরে "URL থেকে যোগ" অথবা "আপলোড" বাটনে চাপুন।',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryImages.length,
              itemBuilder: (ctx, i) {
                final imgUrl = _galleryImages[i];
                return Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppNetworkImage(
                          imageUrl: imgUrl,
                          width: 90,
                          height: 120,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                          fallbackIcon: Icons.photo_outlined,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _galleryImages.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: AppTheme.accentRose, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTogglesCard() {
    return _buildCardContainer(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ফ্রি ডেলিভারি অফার (Free Delivery)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('এই বইয়ের সাথে কুরিয়ার ফ্রি ডেলিভারি চালু হবে', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          value: _freeDelivery,
          activeColor: AppTheme.primary,
          onChanged: (val) => setState(() => _freeDelivery = val),
        ),
        const Divider(color: Color(0xFF263345)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ফিচার্ড বই (Featured on Landing)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('ওয়েবসাইটের টপ সেকশনে বিশেষ হাইলাইট করা হবে', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          value: _isFeatured,
          activeColor: AppTheme.primary,
          onChanged: (val) => setState(() => _isFeatured = val),
        ),
        const Divider(color: Color(0xFF263345)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('কম্বো প্যাকেজ (Combo Pack)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('একাধিক বইয়ের স্পেশাল কম্বো অফার চিহ্নিত করতে', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          value: _isCombo,
          activeColor: AppTheme.primary,
          onChanged: (val) => setState(() => _isCombo = val),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
