import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/section_model.dart';
import '../../providers/section_provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_network_image.dart';

/// Generic section editor for any section (author, bookshelf, faq, footer, reviews, etc.)
class GenericSectionEditorSheet extends StatefulWidget {
  final SectionModel section;

  const GenericSectionEditorSheet({super.key, required this.section});

  static Future<void> show(BuildContext context, SectionModel section) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GenericSectionEditorSheet(section: section),
    );
  }

  @override
  State<GenericSectionEditorSheet> createState() => _GenericSectionEditorSheetState();
}

class _GenericSectionEditorSheetState extends State<GenericSectionEditorSheet> {
  final _picker = ImagePicker();
  late bool _isActive;
  late TextEditingController _nameController;
  late TextEditingController _imageUrlController;
  late Map<String, dynamic> _editableContent;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  Uint8List? _pendingImageBytes;

  @override
  void initState() {
    super.initState();
    _isActive = widget.section.isActive;
    _nameController = TextEditingController(text: widget.section.name);
    _imageUrlController = TextEditingController(text: widget.section.imageUrl ?? widget.section.content['image_url']?.toString() ?? '');
    _editableContent = Map<String, dynamic>.from(widget.section.content);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final hasPermission = await PermissionService.requestImagePickerPermission(
      source: ImageSource.gallery,
      context: context,
    );
    if (!hasPermission) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _pendingImageBytes = bytes;
        _isUploadingImage = true;
      });

      final sp = Provider.of<SectionProvider>(context, listen: false);
      final uploadedUrl = await sp.uploadSectionImage(
        widget.section.id,
        bytes,
        file.name,
        targetField: widget.section.sectionKey == 'navbar' ? 'logo_url' : 'image_url',
      );

      if (uploadedUrl != null && mounted) {
        setState(() {
          _imageUrlController.text = uploadedUrl;
          _editableContent['image_url'] = uploadedUrl;
          _pendingImageBytes = null;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text('ছবি সফলভাবে আপলোড ও অপ্টিমাইজ হয়েছে!'),
          ),
        );
      } else {
        setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.accentRose, content: Text('আপলোড ব্যর্থ: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final sp = Provider.of<SectionProvider>(context, listen: false);

    final updatedContent = Map<String, dynamic>.from(_editableContent);
    if (_imageUrlController.text.trim().isNotEmpty) {
      updatedContent['image_url'] = _imageUrlController.text.trim();
    }

    final ok = await sp.updateSection(widget.section.id, {
      'name': _nameController.text.trim(),
      'is_active': _isActive,
      'image_url': _imageUrlController.text.trim(),
      'content': updatedContent,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text("'${_nameController.text.trim()}' সেকশন সংরক্ষণ হয়েছে!"),
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

  Color get _sectionColor {
    switch (widget.section.sectionKey) {
      case 'hero': return AppTheme.primary;
      case 'navbar': return AppTheme.accentCyan;
      case 'notice_bar': return AppTheme.accentAmber;
      case 'author': return AppTheme.accentPurple;
      case 'reviews': return AppTheme.accentBlue;
      case 'faq': return AppTheme.accentCyan;
      case 'footer': return AppTheme.accentRose;
      default: return AppTheme.primary;
    }
  }

  IconData get _sectionIcon {
    switch (widget.section.sectionKey) {
      case 'hero': return Icons.slideshow_rounded;
      case 'navbar': return Icons.palette_rounded;
      case 'notice_bar': return Icons.campaign_outlined;
      case 'author': return Icons.person_outline_rounded;
      case 'reviews': return Icons.star_outline_rounded;
      case 'bookshelf': return Icons.book_outlined;
      case 'faq': return Icons.help_outline_rounded;
      case 'footer': return Icons.web_asset_rounded;
      default: return Icons.widgets_outlined;
    }
  }

  List<_EditableField> get _fieldsForSection {
    final c = widget.section.content;
    switch (widget.section.sectionKey) {
      case 'author':
        return [
          _EditableField('author_name', 'লেখকের নাম', Icons.person_outline_rounded, c['author_name']?.toString() ?? ''),
          _EditableField('author_title', 'পদবি / টাইটেল', Icons.badge_outlined, c['author_title']?.toString() ?? ''),
          _EditableField('author_bio', 'বায়ো / পরিচিতি', Icons.info_outline_rounded, c['author_bio']?.toString() ?? '', maxLines: 4),
          _EditableField('author_quote', 'বিখ্যাত উক্তি', Icons.format_quote_rounded, c['author_quote']?.toString() ?? '', maxLines: 2),
        ];
      case 'reviews':
        return [
          _EditableField('section_title', 'সেকশন টাইটেল', Icons.title_rounded, c['section_title']?.toString() ?? 'হাজারো শিক্ষার্থীর বিশ্বস্ত সঙ্গী'),
          _EditableField('section_subtitle', 'সাবটাইটেল', Icons.subtitles_rounded, c['section_subtitle']?.toString() ?? '', maxLines: 2),
          _EditableField('section_badge', 'ব্যাজ টেক্সট', Icons.stars_rounded, c['section_badge']?.toString() ?? ''),
          _EditableField('dispatch_title', 'ডেলিভারি ব্যানার টাইটেল', Icons.local_shipping_outlined, c['dispatch_title']?.toString() ?? '', maxLines: 2),
        ];
      case 'faq':
        return [
          _EditableField('section_title', 'সেকশন টাইটেল', Icons.title_rounded, c['section_title']?.toString() ?? ''),
          _EditableField('section_subtitle', 'সাবটাইটেল', Icons.subtitles_rounded, c['section_subtitle']?.toString() ?? '', maxLines: 2),
        ];
      case 'book_about':
        return [
          _EditableField('section_title', 'বই পরিচিতি শিরোনাম', Icons.title_rounded, c['section_title']?.toString() ?? ''),
          _EditableField('description', 'বইয়ের বিবরণ', Icons.description_outlined, c['description']?.toString() ?? '', maxLines: 5),
          _EditableField('section_badge', 'ব্যাজ টেক্সট', Icons.stars_rounded, c['section_badge']?.toString() ?? ''),
        ];
      case 'footer':
        return [
          _EditableField('copyright_text', 'কপিরাইট টেক্সট', Icons.copyright_rounded, c['copyright_text']?.toString() ?? ''),
          _EditableField('footer_tagline', 'ফুটার ট্যাগলাইন', Icons.text_fields_rounded, c['footer_tagline']?.toString() ?? ''),
          _EditableField('contact_email', 'যোগাযোগ ইমেইল', Icons.email_outlined, c['contact_email']?.toString() ?? ''),
        ];
      default:
        return [
          _EditableField('section_title', 'সেকশন টাইটেল', Icons.title_rounded, c['section_title']?.toString() ?? ''),
          _EditableField('section_subtitle', 'সাবটাইটেল', Icons.subtitles_rounded, c['section_subtitle']?.toString() ?? '', maxLines: 2),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final targetHeight = screenHeight * 0.90;
    final availableHeight = (targetHeight - bottomInset).clamp(280.0, targetHeight);
    final color = _sectionColor;
    final fields = _fieldsForSection;

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
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_sectionIcon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.section.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('কী: ${widget.section.sectionKey}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                Switch(value: _isActive, activeColor: AppTheme.primary, onChanged: (v) => setState(() => _isActive = v)),
                IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Name
                  _buildTextField('সেকশন লেবেল নাম', _nameController, Icons.label_outlined),
                  const SizedBox(height: 18),

                  // Section Image
                  const Text('সেকশন ছবি (Section Image)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: _pendingImageBytes != null
                                ? Image.memory(_pendingImageBytes!, width: double.infinity, height: 160, fit: BoxFit.cover)
                                : AppNetworkImage(
                                    imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                                    width: double.infinity,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    fallbackIcon: _sectionIcon,
                                    fallbackText: 'ছবি নেই',
                                  ),
                          ),
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(13)),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                                    SizedBox(height: 8),
                                    Text('আপলোড হচ্ছে...', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.upload_rounded, color: AppTheme.primary, size: 14),
                                  SizedBox(width: 4),
                                  Text('ছবি পরিবর্তন', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField('ছবির URL (ম্যানুয়াল লিঙ্ক)', _imageUrlController, Icons.link_rounded),
                  const SizedBox(height: 18),

                  // Section-specific fields
                  if (fields.isNotEmpty) ...[
                    Text(
                      'সেকশন কন্টেন্ট (${widget.section.sectionKey.toUpperCase()})',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...fields.map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDynamicTextField(field),
                    )),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Save button
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
                        : const Icon(Icons.save_rounded, color: Colors.black, size: 20),
                    label: Text(
                      _isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সেকশন সেভ করুন',
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
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
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
            filled: true, fillColor: const Color(0xFF161F30),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF263345))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicTextField(_EditableField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: field.initialValue,
          maxLines: field.maxLines,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
          onChanged: (v) => setState(() => _editableContent[field.key] = v),
          decoration: InputDecoration(
            prefixIcon: Icon(field.icon, color: AppTheme.primary, size: 18),
            filled: true, fillColor: const Color(0xFF161F30),
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

class _EditableField {
  final String key;
  final String label;
  final IconData icon;
  final String initialValue;
  final int maxLines;

  const _EditableField(this.key, this.label, this.icon, this.initialValue, {this.maxLines = 1});
}
