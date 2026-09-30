import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/section_model.dart';
import '../../providers/section_provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_network_image.dart';

class NavbarEditorSheet extends StatefulWidget {
  final SectionModel navbarSection;
  final SectionModel? noticeBarSection;

  const NavbarEditorSheet({
    super.key,
    required this.navbarSection,
    this.noticeBarSection,
  });

  static Future<void> show(BuildContext context) async {
    final sp = Provider.of<SectionProvider>(context, listen: false);
    final navbar = sp.navbarSection;
    if (navbar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('নেভিগেশন হেডার সেকশন খুঁজে পাওয়া যায়নি।')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NavbarEditorSheet(
        navbarSection: navbar,
        noticeBarSection: sp.noticeBarSection,
      ),
    );
  }

  @override
  State<NavbarEditorSheet> createState() => _NavbarEditorSheetState();
}

class _NavbarEditorSheetState extends State<NavbarEditorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _picker = ImagePicker();

  // Navbar form state
  late bool _navIsActive;
  late TextEditingController _brandTitleController;
  late TextEditingController _brandSubtitleController;
  late TextEditingController _taglineController;
  late TextEditingController _phoneController;
  late TextEditingController _orderBtnTextController;
  late TextEditingController _logoUrlController;

  // Notice Bar form state
  bool _noticeIsActive = true;
  late TextEditingController _noticeTextController;
  late TextEditingController _noticeBadgeController;
  late TextEditingController _stockCountController;
  bool _showStock = true;

  // Media upload state
  Uint8List? _newLogoBytes;
  String? _newLogoFilename;
  bool _isUploadingLogo = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Navbar initialization
    final navContent = widget.navbarSection.content;
    _navIsActive = widget.navbarSection.isActive;
    _brandTitleController = TextEditingController(text: navContent['brand_title']?.toString() ?? 'অনন্যা বাংলা');
    _brandSubtitleController = TextEditingController(text: navContent['brand_subtitle']?.toString() ?? 'একাডেমি');
    _taglineController = TextEditingController(text: navContent['tagline']?.toString() ?? 'সুমন স্যারের অফিসিয়াল পাবলিকেশন');
    _phoneController = TextEditingController(text: navContent['phone']?.toString() ?? '০১৭০০-০০০০০০');
    _orderBtnTextController = TextEditingController(
      text: navContent['order_btn_text']?.toString() ?? navContent['order_button_text']?.toString() ?? 'অর্ডার করুন',
    );
    _logoUrlController = TextEditingController(
      text: navContent['logo_url']?.toString() ?? widget.navbarSection.imageUrl ?? '/images/logo.png',
    );

    // Notice Bar initialization
    if (widget.noticeBarSection != null) {
      final nbContent = widget.noticeBarSection!.content;
      _noticeIsActive = widget.noticeBarSection!.isActive;
      _noticeTextController = TextEditingController(
        text: nbContent['text']?.toString() ?? 'যে কোনো কম্বো প্যাকেজে সারা দেশে ফ্রি হোম ডেলিভারি + স্পেশাল রিভিশন চার্ট একদম ফ্রি!',
      );
      _noticeBadgeController = TextEditingController(text: nbContent['badge']?.toString() ?? 'সীমিত সময়ের অফার');
      _stockCountController = TextEditingController(text: widget.noticeBarSection!.stockCount.toString());
      _showStock = nbContent['show_stock'] != false && nbContent['stock_enabled'] != false;
    } else {
      _noticeTextController = TextEditingController(text: 'যে কোনো কম্বো প্যাকেজে সারা দেশে ফ্রি হোম ডেলিভারি!');
      _noticeBadgeController = TextEditingController(text: 'অফার');
      _stockCountController = TextEditingController(text: '23');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _brandTitleController.dispose();
    _brandSubtitleController.dispose();
    _taglineController.dispose();
    _phoneController.dispose();
    _orderBtnTextController.dispose();
    _logoUrlController.dispose();
    _noticeTextController.dispose();
    _noticeBadgeController.dispose();
    _stockCountController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(ImageSource source) async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: source,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 92,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _newLogoBytes = bytes;
          _newLogoFilename = file.name;
        });

        // Direct upload to section
        await _uploadLogoDirect();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('লোগো সিলেক্ট করতে সমস্যা হয়েছে: $e')),
      );
    }
  }

  Future<void> _uploadLogoDirect() async {
    if (_newLogoBytes == null || _newLogoFilename == null) return;
    setState(() => _isUploadingLogo = true);

    try {
      final sp = Provider.of<SectionProvider>(context, listen: false);
      final uploadedUrl = await sp.uploadSectionImage(
        widget.navbarSection.id,
        _newLogoBytes!,
        _newLogoFilename!,
        targetField: 'logo_url',
      );

      if (uploadedUrl != null && mounted) {
        setState(() {
          _logoUrlController.text = uploadedUrl;
          _newLogoBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text('লোগো সফলভাবে আপলোড ও অপ্টিমাইজ করা হয়েছে!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text('লোগো আপলোড ব্যর্থ: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    final sp = Provider.of<SectionProvider>(context, listen: false);

    try {
      // 1. Save Navbar
      final navPayload = {
        'name': widget.navbarSection.name,
        'is_active': _navIsActive,
        'image_url': _logoUrlController.text.trim(),
        'content': {
          ...widget.navbarSection.content,
          'brand_title': _brandTitleController.text.trim(),
          'brand_subtitle': _brandSubtitleController.text.trim(),
          'tagline': _taglineController.text.trim(),
          'phone': _phoneController.text.trim(),
          'order_btn_text': _orderBtnTextController.text.trim(),
          'order_button_text': _orderBtnTextController.text.trim(),
          'logo_url': _logoUrlController.text.trim(),
        },
      };

      final navOk = await sp.updateSection(widget.navbarSection.id, navPayload);

      // 2. Save Notice Bar (if present)
      bool nbOk = true;
      if (widget.noticeBarSection != null) {
        final parsedStock = int.tryParse(_stockCountController.text.trim()) ?? 23;
        final nbPayload = {
          'name': widget.noticeBarSection!.name,
          'is_active': _noticeIsActive,
          'content': {
            ...widget.noticeBarSection!.content,
            'badge': _noticeBadgeController.text.trim(),
            'text': _noticeTextController.text.trim(),
            'stock_count': parsedStock,
            'stock_left': '$parsedStock কপি',
            'show_stock': _showStock,
            'stock_enabled': _showStock,
          },
        };
        nbOk = await sp.updateSection(widget.noticeBarSection!.id, nbPayload);
      }

      if (mounted) {
        if (navOk && nbOk) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.primary,
              content: Text('লোগো ও হেডার সেটিংস সফলভাবে সংরক্ষণ করা হয়েছে!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentRose,
              content: Text(sp.errorMessage ?? 'সংরক্ষণ ব্যর্থ হয়েছে।'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          // Drag handle
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.palette_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'লোগো ও হেডার ব্র্যান্ডিং ম্যানেজার',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'লোগো, টাইটেল ও নোটিশ বার এডিট করুন',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF263345)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.web_rounded, size: 18), text: 'লোগো ও হেডার'),
                Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'জরুরি নোটিশ বার'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNavbarTab(),
                _buildNoticeBarTab(),
              ],
            ),
          ),

          // Bottom action button
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
                    onPressed: _isSaving ? null : _saveAll,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.check_circle_outline, color: Colors.black),
                    label: Text(
                      _isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সেটিংস সংরক্ষণ করুন',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildNavbarTab() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Switch Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF263345)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('হেডার নেভিগেশন স্ট্যাটাস', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('ওয়েবসাইটে হেডার প্রদর্শন চালু/বন্ধ রাখুন', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
                Switch(
                  value: _navIsActive,
                  activeColor: AppTheme.primary,
                  onChanged: (val) => setState(() => _navIsActive = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Logo Upload & Preview Section
          const Text('ওয়েবসাইট লোগো (Website Logo)', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF263345)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Logo Preview
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: _newLogoBytes != null
                          ? Image.memory(_newLogoBytes!, fit: BoxFit.contain)
                          : AppNetworkImage(
                              imageUrl: _logoUrlController.text,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.image_outlined,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'লোগো আপলোড বা পরিবর্তন',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'স্বচ্ছ PNG বা WebP ফরম্যাট ব্যবহারের পরামর্শ দেওয়া হচ্ছে।',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isUploadingLogo ? null : () => _pickLogo(ImageSource.gallery),
                                icon: _isUploadingLogo
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.upload_file_rounded, size: 16),
                                label: const Text('গ্যালারি', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isUploadingLogo ? null : () => _pickLogo(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: const Text('ক্যামেরা', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTextField('লোগো ইমেজ লিঙ্ক (URL)', _logoUrlController, Icons.link_rounded),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Titles & Brand Text
          const Text('ব্র্যান্ড ও টাইটেল তথ্য', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTextField('ব্র্যান্ড মূল নাম (Title)', _brandTitleController, Icons.title_rounded, hint: 'অনন্যা বাংলা'),
          const SizedBox(height: 12),
          _buildTextField('সাবটাইটেল (Subtitle)', _brandSubtitleController, Icons.subtitles_rounded, hint: 'একাডেমি'),
          const SizedBox(height: 12),
          _buildTextField('ট্যাগলাইন / লেখক পরিচিতি', _taglineController, Icons.badge_outlined, hint: 'সুমন স্যারের অফিসিয়াল পাবলিকেশন'),
          const SizedBox(height: 12),
          _buildTextField('হটলাইন ফোন নম্বর', _phoneController, Icons.phone_rounded, hint: '০১৭০০-০০০০০০'),
          const SizedBox(height: 12),
          _buildTextField('অর্ডার বাটন টেক্সট', _orderBtnTextController, Icons.shopping_bag_outlined, hint: 'অর্ডার করুন'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNoticeBarTab() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Switch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF263345)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('নোটিশ বার স্ট্যাটাস', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('ওয়েবসাইটের একদম উপরে জরুরি অফার বাটন চালু রাখুন', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
                Switch(
                  value: _noticeIsActive,
                  activeColor: AppTheme.accentEmerald,
                  onChanged: (val) => setState(() => _noticeIsActive = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _buildTextField('জরুরি ব্যাজ টেক্সট', _noticeBadgeController, Icons.stars_rounded, hint: 'সীমিত সময়ের অফার'),
          const SizedBox(height: 12),
          _buildTextField('ঘোষণা / অফার বার্তা', _noticeTextController, Icons.announcement_outlined, maxLines: 3, hint: 'যে কোনো কম্বো প্যাকেজে ফ্রি হোম ডেলিভারি!'),
          const SizedBox(height: 18),

          // Stock Counter Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF263345)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('লাইভ স্টক কাউন্টার', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _showStock,
                      activeColor: AppTheme.accentEmerald,
                      onChanged: (val) => setState(() => _showStock = val),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'গ্রাহকদের দ্রুত অর্ডার করতে উদ্বুদ্ধ করতে নোটিশ বারে অবশিষ্টাংশ বই সংখ্যা দেখায়।',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final cur = int.tryParse(_stockCountController.text) ?? 23;
                        if (cur > 1) {
                          _stockCountController.text = (cur - 1).toString();
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.accentRose),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _stockCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final cur = int.tryParse(_stockCountController.text) ?? 23;
                        _stockCountController.text = (cur + 1).toString();
                        setState(() {});
                      },
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.accentEmerald),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [15, 23, 50, 100].map((preset) {
                    return ActionChip(
                      label: Text('$preset কপি'),
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                      backgroundColor: const Color(0xFF1E293B),
                      onPressed: () {
                        _stockCountController.text = preset.toString();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
}
