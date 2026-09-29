import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/review_model.dart';
import '../../providers/review_provider.dart';
import '../../widgets/app_network_image.dart';
import 'review_edit_dialog.dart';

class ReviewsManagerScreen extends StatefulWidget {
  const ReviewsManagerScreen({super.key});

  @override
  State<ReviewsManagerScreen> createState() => _ReviewsManagerScreenState();
}

class _ReviewsManagerScreenState extends State<ReviewsManagerScreen> {
  final List<Map<String, String>> _filters = [
    {'key': 'all', 'label': 'সব রিভিউ'},
    {'key': 'pending', 'label': 'অপেক্ষমাণ (Pending)'},
    {'key': 'active', 'label': 'অনুমোদিত (Active)'},
    {'key': 'featured', 'label': 'ফিচার্ড (Featured)'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReviewProvider>(context, listen: false).fetchReviews(refresh: true);
    });
  }

  void _openEditor(BuildContext context, {ReviewModel? review, bool initialApprove = false}) async {
    final result = await ReviewEditDialog.show(
      context,
      review: review,
      initialApprove: initialApprove,
    );
    if (result == true && mounted) {
      Provider.of<ReviewProvider>(context, listen: false).fetchReviews(refresh: true);
    }
  }

  void _viewFullScreenshot(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox(
                      height: 250,
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    ),
                    errorWidget: const SizedBox(
                      height: 200,
                      child: Center(
                        child: Icon(Icons.broken_image, color: AppTheme.accentRose, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.7),
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReviewModel rev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRose, size: 24),
            SizedBox(width: 8),
            Text('রিভিউ মুছবেন?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '\'${rev.reviewerName}\'-এর এই রিভিউটি স্থায়ীভাবে মুছে ফেলতে চান? এই অ্যাকশন আর ফিরিয়ে আনা যাবে না।',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<ReviewProvider>(context, listen: false).deleteReview(rev.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    final stats = reviewProvider.stats;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('রিভিউ ও চ্যাট প্রুফ ম্যানেজার'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: () => reviewProvider.fetchReviews(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text(
          'নতুন রিভিউ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openEditor(context, review: null, initialApprove: true),
      ),
      body: Column(
        children: [
          // Stats Row
          if (stats.isNotEmpty) _buildStatsRow(stats),

          // Filter Chips
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppTheme.surfaceDark,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (ctx, i) {
                final f = _filters[i];
                final isSelected = reviewProvider.filter == f['key'];
                int? count;
                if (f['key'] == 'all') count = stats['total'];
                if (f['key'] == 'pending') count = stats['pending'];
                if (f['key'] == 'active') count = stats['active'];
                if (f['key'] == 'featured') count = stats['featured'];

                final labelText = count != null ? '${f['label']} ($count)' : f['label']!;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labelText),
                    selected: isSelected,
                    selectedColor: AppTheme.accentAmber,
                    backgroundColor: const Color(0xFF161F30),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) reviewProvider.setFilter(f['key']!);
                    },
                  ),
                );
              },
            ),
          ),

          // Reviews List
          Expanded(
            child: reviewProvider.isLoading && reviewProvider.reviews.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : reviewProvider.reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_outlined, color: Color(0xFF64748B), size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'কোনো রিভিউ পাওয়া যায়নি',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openEditor(context, review: null, initialApprove: true),
                              icon: const Icon(Icons.add, size: 18, color: Colors.black),
                              label: const Text('নতুন রিভিউ যুক্ত করুন', style: TextStyle(color: Colors.black)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => reviewProvider.fetchReviews(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: reviewProvider.reviews.length,
                          itemBuilder: (ctx, i) {
                            final rev = reviewProvider.reviews[i];
                            return _buildReviewCard(context, rev, reviewProvider);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return Container(
      color: AppTheme.bgDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _buildStatCard('মোট রিভিউ', stats['total']?.toString() ?? '0', AppTheme.accentCyan, Icons.reviews_outlined),
          const SizedBox(width: 8),
          _buildStatCard('অপেক্ষমাণ', stats['pending']?.toString() ?? '0', AppTheme.accentAmber, Icons.pending_actions_outlined),
          const SizedBox(width: 8),
          _buildStatCard('অনুমোদিত', stats['active']?.toString() ?? '0', AppTheme.primary, Icons.check_circle_outline_rounded),
          const SizedBox(width: 8),
          _buildStatCard('ফিচার্ড', stats['featured']?.toString() ?? '0', AppTheme.accentPurple, Icons.star_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, ReviewModel rev, ReviewProvider provider) {
    final isPending = !rev.isActive;
    final fullScreenshot = rev.fullScreenshotUrl(ApiConfig.baseUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? AppTheme.accentAmber.withOpacity(0.5) : const Color(0xFF263345),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending banner if review is pending
          if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppTheme.accentAmber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'অপেক্ষমাণ (Pending) — ওয়েবসাইটে দেখাতে এডিট ও অনুমোদন করুন',
                      style: TextStyle(
                        color: AppTheme.accentAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _openEditor(context, review: rev, initialApprove: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 14, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'এডিট ও অনুমোদন',
                            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reviewer Header: Name, Designation, Rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isPending ? AppTheme.accentAmber.withOpacity(0.2) : AppTheme.primary.withOpacity(0.2),
                      child: Text(
                        rev.reviewerName.isNotEmpty ? rev.reviewerName[0].toUpperCase() : 'র',
                        style: TextStyle(
                          color: isPending ? AppTheme.accentAmber : AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rev.reviewerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (rev.designation != null && rev.designation!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                rev.designation!,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Rating Stars
                    Row(
                      children: List.generate(
                        5,
                        (idx) => Icon(
                          idx < rev.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppTheme.accentAmber,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Book & Source Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (rev.bookTitle.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, color: AppTheme.accentCyan, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              rev.bookTitle,
                              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    if (rev.sourceLabel != null && rev.sourceLabel!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          rev.sourceLabel!,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                      ),
                    if (rev.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: AppTheme.accentAmber, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'ফিচার্ড রিভিউ',
                              style: TextStyle(color: AppTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Review Comment
                if (rev.comment != null && rev.comment!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Text(
                      rev.comment!,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),

                // Screenshot Preview
                if (fullScreenshot != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _viewFullScreenshot(context, fullScreenshot),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF263345)),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AppNetworkImage(
                                imageUrl: fullScreenshot,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                  ),
                                ),
                                errorWidget: const Center(
                                  child: Icon(Icons.broken_image, color: Color(0xFF64748B), size: 28),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'বড় করে দেখুন',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFF263345)),
                const SizedBox(height: 10),

                // Action Buttons
                Row(
                  children: [
                    if (isPending) ...[
                      // 1-Tap Direct Publish Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final success = await provider.publishReview(rev.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('রিভিউটি সফলভাবে পাবলিশ করা হয়েছে!'),
                                  ],
                                ),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 15, color: Colors.black),
                        label: const Text(
                          'পাবলিশ করুন',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit & Approve modal button
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(context, review: rev, initialApprove: true),
                        icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFE2E8F0)),
                        label: const Text(
                          'এডিট ও অনুমোদন',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ] else ...[
                      // Edit Button for Active Reviews
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(context, review: rev, initialApprove: false),
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF94A3B8)),
                        label: const Text('এডিট', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Active status indicator with unpublish/hold option
                      OutlinedButton.icon(
                        onPressed: () => provider.toggleActive(rev.id),
                        icon: const Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.primary),
                        label: const Text(
                          'পাবলিশড (সক্রিয়)',
                          style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],

                    const SizedBox(width: 8),

                    // Toggle Featured
                    IconButton(
                      icon: Icon(
                        rev.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                        color: rev.isFeatured ? AppTheme.accentAmber : const Color(0xFF64748B),
                        size: 22,
                      ),
                      tooltip: rev.isFeatured ? 'ফিচার্ড থেকে সরান' : 'ফিচার্ড করুন',
                      onPressed: () => provider.toggleFeatured(rev.id),
                    ),

                    const Spacer(),

                    // Delete Review
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRose, size: 20),
                      tooltip: 'মুছে ফেলুন',
                      onPressed: () => _confirmDelete(context, rev),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
