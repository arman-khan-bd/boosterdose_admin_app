
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/section_model.dart';
import '../../providers/section_provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_network_image.dart';

class HeroEditorSheet extends StatefulWidget {
  final SectionModel hero;
  final List<dynamic> books;

  const HeroEditorSheet({super.key, required this.hero, required this.books});

  static Future<void> show(BuildContext context) async {
    final sp = Provider.of<SectionProvider>(context, listen: false);
    final hero = sp.heroSection;
    if (hero == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('হিরো সেকশন খুঁজে পাওয়া যায়নি।')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HeroEditorSheet(hero: hero, books: sp.books),
    );
  }

  @override
  State<HeroEditorSheet> createState() => _HeroEditorSheetState();
}

class _HeroEditorSheetState extends State<HeroEditorSheet> {
  final _picker = ImagePicker();
  late bool _isActive;
  late List<Map<String, dynamic>> _slides;
  late bool _autoplay;
  late bool _showDots;
  late bool _showArrows;
  int _activeSlideIndex = 0;
  bool _isSaving = false;
  String? _uploadingKey;

  @override
  void initState() {
    super.initState();
    _isActive = widget.hero.isActive;
    _autoplay = widget.hero.content['autoplay'] as bool? ?? true;
    _showDots = widget.hero.content['show_dots'] as bool? ?? true;
    _showArrows = widget.hero.content['show_arrows'] as bool? ?? true;
    _slides = widget.hero.heroSlides.isNotEmpty
        ? widget.hero.heroSlides
            .map((s) => Map<String, dynamic>.from(s))
            .toList()
        : [
            {
              'id': 'slide-1',
              'title': 'মুখস্থ ছাড়াই সহজ টেকনিকে বাংলা ২য় পত্রে নিশ্চিত',
              'title_highlight': 'A+ মার্কস!',
              'banner_image': '/images/hsc-2026-hero.webp',
              'mobile_image_url': '',
              'order_button_text': 'এখনই অর্ডার করুন',
              'target_book_id': null,
            }
          ];
  }

  Map<String, dynamic> get _activeSlide => _slides[_activeSlideIndex];

  void _updateSlideField(String key, dynamic value) {
    setState(() {
      _slides[_activeSlideIndex][key] = value;
    });
  }

  Future<void> _pickAndUploadImage(String field) async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: ImageSource.gallery,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final uploadKey = 'slide${_activeSlideIndex}_$field';

      setState(() => _uploadingKey = uploadKey);

      final sp = Provider.of<SectionProvider>(context, listen: false);
      final uploadedUrl = await sp.uploadMedia(bytes, file.name);

      if (uploadedUrl != null && mounted) {
        setState(() {
          _slides[_activeSlideIndex][field] = uploadedUrl;
          _uploadingKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text('হিরো ছবি সফলভাবে আপলোড ও অপ্টিমাইজ হয়েছে!'),
          ),
        );
      } else {
        setState(() => _uploadingKey = null);
      }
    } catch (e) {
      setState(() => _uploadingKey = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.accentRose, content: Text('আপলোড ব্যর্থ: $e')),
        );
      }
    }
  }

  void _addSlide() {
    setState(() {
      _slides.add({
        'id': 'slide-${DateTime.now().millisecondsSinceEpoch}',
        'title': 'নতুন স্লাইড',
        'title_highlight': '',
        'banner_image': '',
        'mobile_image_url': '',
        'order_button_text': 'এখনই অর্ডার করুন',
        'target_book_id': null,
      });
      _activeSlideIndex = _slides.length - 1;
    });
  }

  void _removeSlide(int index) {
    if (_slides.length <= 1) return;
    setState(() {
      _slides.removeAt(index);
      if (_activeSlideIndex >= _slides.length) {
        _activeSlideIndex = _slides.length - 1;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final sp = Provider.of<SectionProvider>(context, listen: false);

    final ok = await sp.saveHero({
      'name': widget.hero.name,
      'is_active': _isActive,
      'content': {
        ...widget.hero.content,
        'autoplay': _autoplay,
        'show_dots': _showDots,
        'show_arrows': _showArrows,
        'slides': _slides,
      },
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text('হিরো সেকশন সফলভাবে সংরক্ষণ করা হয়েছে!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text(sp.errorMessage ?? 'সংরক্ষণ ব্যর্থ হয়েছে।'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final targetHeight = screenHeight * 0.92;
    final availableHeight = (targetHeight - bottomInset).clamp(280.0, targetHeight);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        height: availableHeight,
        decoration: const BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
          // Drag handle & header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.slideshow_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('হিরো ব্যানার স্লাইডার ম্যানেজার', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('ব্যানার ছবি, টাইটেল ও বাটন সম্পাদনা করুন', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                Switch(value: _isActive, activeColor: AppTheme.primary, onChanged: (v) => setState(() => _isActive = v)),
                IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          // Slide selector tabs
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _slides.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => setState(() => _activeSlideIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeSlideIndex == i ? AppTheme.primary : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _activeSlideIndex == i ? AppTheme.primary : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'স্লাইড ${i + 1}',
                              style: TextStyle(
                                color: _activeSlideIndex == i ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_slides.length > 1) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeSlide(i),
                                child: Icon(
                                  Icons.close, size: 14,
                                  color: _activeSlideIndex == i ? Colors.black54 : AppTheme.accentRose,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addSlide,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Slide editor content
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner image preview + upload
                  _buildImageUploadCard(
                    label: 'ব্যানার ছবি (Desktop / Banner Image)',
                    imageUrl: _activeSlide['banner_image']?.toString(),
                    uploadKey: 'slide${_activeSlideIndex}_banner_image',
                    onTap: () => _pickAndUploadImage('banner_image'),
                    onPresetPick: (url) => _updateSlideField('banner_image', url),
                    aspectRatio: 16 / 9,
                  ),
                  const SizedBox(height: 14),

                  _buildImageUploadCard(
                    label: 'মোবাইল ছবি (Mobile Image — ঐচ্ছিক)',
                    imageUrl: _activeSlide['mobile_image_url']?.toString(),
                    uploadKey: 'slide${_activeSlideIndex}_mobile_image_url',
                    onTap: () => _pickAndUploadImage('mobile_image_url'),
                    onPresetPick: (url) => _updateSlideField('mobile_image_url', url),
                    aspectRatio: 3 / 4,
                    isCompact: true,
                  ),
                  const SizedBox(height: 18),

                  // Slide texts
                  _buildField('স্লাইড টাইটেল (মূল)', _activeSlide['title']?.toString() ?? '',
                      Icons.title_rounded, (v) => _updateSlideField('title', v)),
                  const SizedBox(height: 12),
                  _buildField('হাইলাইটেড টেক্সট', _activeSlide['title_highlight']?.toString() ?? '',
                      Icons.star_outline_rounded, (v) => _updateSlideField('title_highlight', v)),
                  const SizedBox(height: 12),
                  _buildField('অর্ডার বাটন টেক্সট', _activeSlide['order_button_text']?.toString() ?? 'এখনই অর্ডার করুন',
                      Icons.shopping_cart_outlined, (v) => _updateSlideField('order_button_text', v)),
                  const SizedBox(height: 20),

                  // Carousel settings
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF263345)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ক্যারোজেল সেটিংস', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const Divider(color: Color(0xFF263345), height: 16),
                        _buildToggleRow('অটো-প্লে', _autoplay, (v) => setState(() => _autoplay = v)),
                        _buildToggleRow('ডটস ইন্ডিকেটর', _showDots, (v) => setState(() => _showDots = v)),
                        _buildToggleRow('অ্যারো বাটন', _showArrows, (v) => setState(() => _showArrows = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom save button
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFF161F30),
              border: Border(top: BorderSide(color: Color(0xFF263345))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('বাতিল'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
                    label: Text(
                      _isSaving ? 'সংরক্ষণ হচ্ছে...' : 'হিরো সেকশন সেভ করুন',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildImageUploadCard({
    required String label,
    required String? imageUrl,
    required String uploadKey,
    required VoidCallback onTap,
    required void Function(String) onPresetPick,
    double aspectRatio = 16 / 9,
    bool isCompact = false,
  }) {
    final isUploading = _uploadingKey == uploadKey;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: isCompact ? const BoxConstraints(maxHeight: 160) : const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasImage ? AppTheme.primary.withOpacity(0.3) : const Color(0xFF263345)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: hasImage
                      ? AppNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: isCompact ? 160 : 200,
                          fit: BoxFit.cover,
                        )
                      : SizedBox(
                          height: isCompact ? 160 : 200,
                          width: double.infinity,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF64748B), size: 36),
                              SizedBox(height: 8),
                              Text('ছবি নির্বাচন বা আপলোড করুন', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                        ),
                ),
                if (isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                          SizedBox(height: 10),
                          Text('অপ্টিমাইজ ও আপলোড হচ্ছে...', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_rounded, color: AppTheme.primary, size: 14),
                        SizedBox(width: 4),
                        Text('আপলোড', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, String value, IconData icon, void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
            filled: true,
            fillColor: const Color(0xFF161F30),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, void Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
        Switch(value: value, activeColor: AppTheme.primary, onChanged: onChanged),
      ],
    );
  }
}
