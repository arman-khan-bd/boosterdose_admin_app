import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/section_model.dart';
import '../../providers/section_provider.dart';
import '../../widgets/app_network_image.dart';
import 'hero_editor_sheet.dart';
import 'navbar_editor_sheet.dart';
import 'generic_section_editor_sheet.dart';

class SectionsManagerScreen extends StatefulWidget {
  const SectionsManagerScreen({super.key});

  @override
  State<SectionsManagerScreen> createState() => _SectionsManagerScreenState();
}

class _SectionsManagerScreenState extends State<SectionsManagerScreen> {
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SectionProvider>(context, listen: false).fetchSections();
    });
  }

  Future<void> _openEditor(SectionModel sec) async {
    switch (sec.sectionKey) {
      case 'hero':
        await HeroEditorSheet.show(context);
        break;
      case 'navbar':
      case 'notice_bar':
        await NavbarEditorSheet.show(context);
        break;
      default:
        await GenericSectionEditorSheet.show(context, sec);
        break;
    }
  }

  Color _colorForSection(String key) {
    switch (key) {
      case 'hero': return AppTheme.primary;
      case 'navbar': return AppTheme.accentCyan;
      case 'notice_bar': return AppTheme.accentAmber;
      case 'author': return AppTheme.accentPurple;
      case 'reviews': return AppTheme.accentBlue;
      case 'bookshelf': return AppTheme.accentEmerald;
      case 'faq': return AppTheme.accentCyan;
      case 'footer': return AppTheme.accentRose;
      case 'book_about': return AppTheme.accentAmber;
      case 'floating_buttons': return AppTheme.accentEmerald;
      default: return AppTheme.primary;
    }
  }

  IconData _iconForSection(String key) {
    switch (key) {
      case 'hero': return Icons.slideshow_rounded;
      case 'navbar': return Icons.palette_rounded;
      case 'notice_bar': return Icons.campaign_outlined;
      case 'author': return Icons.person_outline_rounded;
      case 'reviews': return Icons.star_outline_rounded;
      case 'bookshelf': return Icons.book_outlined;
      case 'faq': return Icons.help_outline_rounded;
      case 'footer': return Icons.web_asset_rounded;
      case 'book_about': return Icons.info_outline_rounded;
      case 'floating_buttons': return Icons.contact_phone_rounded;
      default: return Icons.widgets_outlined;
    }
  }

  String _labelForSection(String key) {
    switch (key) {
      case 'hero': return 'হিরো স্লাইডার';
      case 'navbar': return 'লোগো ও হেডার';
      case 'notice_bar': return 'জরুরি নোটিশ বার';
      case 'author': return 'লেখক পরিচিতি';
      case 'reviews': return 'রিভিউ ও ট্রাস্ট';
      case 'bookshelf': return 'বই ক্যাটালগ';
      case 'faq': return 'প্রশ্নোত্তর (FAQ)';
      case 'footer': return 'ফুটার ও সাপোর্ট তথ্য';
      case 'book_about': return 'বই পরিচিতি ও বৈশিষ্ট্য';
      case 'floating_buttons': return 'কল ও হোয়াটসঅ্যাপ বাটন';
      default: return key.toUpperCase();
    }
  }

  String? _contentSnippet(SectionModel sec) {
    final c = sec.content;
    switch (sec.sectionKey) {
      case 'footer':
        final brand = c['brand_title'] ?? c['brand_subtitle'];
        final phone = c['support_phone'] ?? c['phone'];
        if (brand != null && phone != null) return '$brand • $phone';
        return brand?.toString() ?? phone?.toString() ?? c['copyright']?.toString();
      case 'floating_buttons':
        final p = c['phone'] ?? '';
        final w = c['whatsapp'] ?? '';
        if (p.isNotEmpty || w.isNotEmpty) return 'ফোন: $p | WA: $w';
        return null;
      case 'bookshelf':
        return c['section_title']?.toString() ?? c['section_subtitle']?.toString();
      case 'book_about':
        return c['section_title']?.toString() ?? c['section_badge']?.toString();
      case 'author':
        final name = c['author_name'];
        final title = c['author_title'];
        if (name != null && title != null) return '$name ($title)';
        return name?.toString();
      case 'reviews':
        return c['section_title']?.toString() ?? c['dispatch_title']?.toString();
      case 'hero':
        if (sec.heroSlides.isNotEmpty) {
          return sec.heroSlides.first['title']?.toString();
        }
        return null;
      default:
        return c['section_title']?.toString() ?? c['title']?.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SectionProvider>(
      builder: (context, sp, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          appBar: AppBar(
            backgroundColor: AppTheme.bgDark,
            title: const Text('সেকশন ম্যানেজার'),
            actions: [
              // Reorder mode toggle
              IconButton(
                icon: Icon(
                  _reorderMode ? Icons.check_circle_rounded : Icons.swap_vert_rounded,
                  color: _reorderMode ? AppTheme.primary : Colors.white,
                ),
                tooltip: _reorderMode ? 'ক্রম সম্পন্ন' : 'ক্রম পরিবর্তন',
                onPressed: () => setState(() => _reorderMode = !_reorderMode),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => sp.fetchSections(),
              ),
            ],
          ),
          body: sp.isLoading && sp.sections.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : sp.sections.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        // Info Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          color: const Color(0xFF161F30),
                          child: Row(
                            children: [
                              Icon(
                                _reorderMode ? Icons.drag_handle_rounded : Icons.info_outline_rounded,
                                color: _reorderMode ? AppTheme.accentAmber : AppTheme.accentCyan,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _reorderMode
                                      ? 'ড্র্যাগ করে সেকশনের ক্রম পরিবর্তন করুন। সম্পন্ন হলে ✓ বাটনে চাপুন।'
                                      : 'প্রতিটি সেকশনে ট্যাপ করলে এডিটর খুলবে। টগল দিয়ে সেকশন অন/অফ করুন।',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: _reorderMode
                              ? _buildReorderableList(sp)
                              : _buildSectionCards(sp),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildSectionCards(SectionProvider sp) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sp.sections.length,
      itemBuilder: (ctx, i) => _buildSectionCard(sp, sp.sections[i]),
    );
  }

  Widget _buildSectionCard(SectionProvider sp, SectionModel sec) {
    final color = _colorForSection(sec.sectionKey);
    final icon = _iconForSection(sec.sectionKey);
    final displayLabel = _labelForSection(sec.sectionKey);
    final displayImage = sec.displayImage;
    final fullImageUrl = displayImage != null
        ? AppNetworkImage.normalizeUrl(displayImage, baseUrl: ApiConfig.baseUrl)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sec.isActive ? color.withOpacity(0.3) : const Color(0xFF263345),
          width: sec.isActive ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Background image (blurred/dimmed)
            if (fullImageUrl != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: AppNetworkImage(
                    imageUrl: displayImage,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: fullImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: AppNetworkImage(
                                  imageUrl: displayImage,
                                  width: 72, height: 72,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 14),

                      // Title & meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    displayLabel,
                                    style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Active badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sec.isActive
                                        ? AppTheme.primary.withOpacity(0.12)
                                        : AppTheme.accentRose.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          color: sec.isActive ? AppTheme.primary : AppTheme.accentRose,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        sec.isActive ? 'সক্রিয়' : 'বন্ধ',
                                        style: TextStyle(
                                          color: sec.isActive ? AppTheme.primary : AppTheme.accentRose,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sec.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'key: ${sec.sectionKey} • #${sec.sortOrder}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                            if (_contentSnippet(sec) != null && _contentSnippet(sec)!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _contentSnippet(sec)!,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Toggle switch
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: sec.isActive,
                          activeColor: AppTheme.primary,
                          onChanged: (val) => sp.toggleSection(sec.id),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  const SizedBox(height: 10),

                  // Action row
                  Row(
                    children: [
                      // Image URL indicator
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              displayImage != null ? Icons.image_rounded : Icons.image_not_supported_outlined,
                              color: displayImage != null ? AppTheme.primary.withOpacity(0.7) : const Color(0xFF64748B),
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                displayImage != null
                                    ? displayImage.split('/').last
                                    : 'ছবি নেই',
                                style: TextStyle(
                                  color: displayImage != null ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 10.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit button
                      GestureDetector(
                        onTap: () => _openEditor(sec),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, color: color, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'এডিট করুন',
                                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(SectionProvider sp) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sp.sections.length,
      onReorder: (oldIndex, newIndex) => sp.reorder(oldIndex, newIndex),
      itemBuilder: (ctx, i) {
        final sec = sp.sections[i];
        final color = _colorForSection(sec.sectionKey);
        return Container(
          key: ValueKey(sec.id),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161F30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF263345)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(_iconForSection(sec.sectionKey), color: color, size: 20),
            ),
            title: Text(sec.name, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '#${i + 1} • ${sec.sectionKey}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            trailing: const Icon(Icons.drag_handle_rounded, color: Color(0xFF64748B), size: 22),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.web_outlined, color: AppTheme.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('কোনো সেকশন পাওয়া যায়নি', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('রিফ্রেশ করুন অথবা ওয়েব ড্যাশবোর্ড থেকে সেকশন তৈরি করুন।', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Provider.of<SectionProvider>(context, listen: false).fetchSections(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            label: const Text('রিফ্রেশ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
