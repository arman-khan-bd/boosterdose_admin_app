import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/book_provider.dart';
import '../../widgets/app_network_image.dart';
import 'book_form_screen.dart';

class BooksListScreen extends StatefulWidget {
  const BooksListScreen({super.key});

  @override
  State<BooksListScreen> createState() => _BooksListScreenState();
}

class _BooksListScreenState extends State<BooksListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, in_stock, limited_stock, out_of_stock, featured

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookProvider>(context, listen: false).fetchBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookModel> _filterBooks(List<BookModel> books) {
    var filtered = books;

    // Search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((b) {
        final title = b.title.toLowerCase();
        final author = b.author.toLowerCase();
        final cat = (b.category ?? '').toLowerCase();
        final desc = (b.description ?? '').toLowerCase();
        return title.contains(query) || author.contains(query) || cat.contains(query) || desc.contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedFilter == 'in_stock') {
      filtered = filtered.where((b) => b.stockStatus == 'in_stock').toList();
    } else if (_selectedFilter == 'limited_stock') {
      filtered = filtered.where((b) => b.stockStatus == 'limited_stock').toList();
    } else if (_selectedFilter == 'out_of_stock') {
      filtered = filtered.where((b) => b.stockStatus == 'out_of_stock' || b.stockCount <= 0).toList();
    } else if (_selectedFilter == 'featured') {
      filtered = filtered.where((b) => b.isFeatured).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final displayedBooks = _filterBooks(bookProvider.books);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('বই ক্যাটালগ ও ম্যানেজমেন্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ করুন',
            onPressed: () => bookProvider.fetchBooks(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('নতুন বই যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormScreen()));
        },
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'বইয়ের নাম, লেখক বা ক্যাটাগরি দিয়ে সার্চ...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // 2. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'সব বই (${bookProvider.books.length})'),
                _buildFilterChip('in_stock', 'ইন স্টক'),
                _buildFilterChip('limited_stock', 'সীমিত স্টক'),
                _buildFilterChip('out_of_stock', 'স্টক শেষ'),
                _buildFilterChip('featured', 'ফিচার্ড'),
              ],
            ),
          ),

          // 3. Books List
          Expanded(
            child: bookProvider.isLoading && bookProvider.books.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : displayedBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF64748B), size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'কোনো বই পাওয়া যায়নি',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'অন্য কি-ওয়ার্ড দিয়ে সার্চ করে দেখুন।'
                                  : 'নিচের "নতুন বই যোগ করুন" বাটনে চাপুন।',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => bookProvider.fetchBooks(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: displayedBooks.length,
                          itemBuilder: (ctx, i) => _buildBookCard(context, displayedBooks[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        backgroundColor: AppTheme.surfaceDark,
        selectedColor: AppTheme.primary,
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppTheme.primary : const Color(0xFF263345)),
        ),
        onSelected: (_) => setState(() => _selectedFilter = key),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, BookModel book) {
    Color statusColor;
    String statusText;

    if (book.stockStatus == 'out_of_stock' || book.stockCount <= 0) {
      statusColor = AppTheme.accentRose;
      statusText = 'স্টক শেষ';
    } else if (book.stockStatus == 'limited_stock') {
      statusColor = AppTheme.accentAmber;
      statusText = 'সীমিত স্টক (${book.stockCount})';
    } else {
      statusColor = AppTheme.primary;
      statusText = 'স্টকে আছে (${book.stockCount})';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: book.isFeatured ? AppTheme.primary.withOpacity(0.35) : const Color(0xFF263345),
          width: book.isFeatured ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                AppNetworkImage(
                  imageUrl: book.fullCoverUrl(),
                  width: 78,
                  height: 110,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  fallbackIcon: Icons.book_rounded,
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (book.isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('⭐ ফিচার্ড', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          if (book.badge != null && book.badge!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(book.badge!, style: const TextStyle(color: AppTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          if (book.category != null && book.category!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(book.category!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        book.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Author
                      Row(
                        children: [
                          const Icon(Icons.person_outline, color: Color(0xFF94A3B8), size: 13),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              book.author,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Pricing & Stock row
                      Row(
                        children: [
                          Text(
                            '৳${book.effectivePrice.toInt()}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (book.discountPrice > 0 && book.price > book.discountPrice) ...[
                            const SizedBox(width: 8),
                            Text(
                              '৳${book.price.toInt()}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, decoration: TextDecoration.lineThrough),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
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

          // Action bar footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF131A26),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                if (book.pages > 0) ...[
                  const Icon(Icons.auto_stories_rounded, color: Color(0xFF64748B), size: 14),
                  const SizedBox(width: 4),
                  Text('${book.pages} পৃষ্ঠা', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.shopping_bag_outlined, color: Color(0xFF64748B), size: 14),
                const SizedBox(width: 4),
                Text('বিক্রি: ${book.totalSold}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const Spacer(),

                // Details Button
                InkWell(
                  onTap: () => _showBookDetailsSheet(context, book),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, color: Color(0xFF94A3B8), size: 16),
                        SizedBox(width: 4),
                        Text('বিবরণ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('এডিট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BookFormScreen(book: book)),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.accentRose, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context, book),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookDetailsSheet(BuildContext context, BookModel book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNetworkImage(
                    imageUrl: book.fullCoverUrl(),
                    width: 90,
                    height: 130,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
                    fallbackIcon: Icons.book_rounded,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('লেখক: ${book.author}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        if (book.category != null)
                          Text('ক্যাটাগরি: ${book.category}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('মূল্য: ৳${book.effectivePrice.toInt()}', style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('স্টক সংখ্যা: ${book.stockCount}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF263345)),
              const SizedBox(height: 12),

              const Text('বইয়ের বর্ণনা (Description):', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                book.description?.isNotEmpty == true ? book.description! : 'কোনো বর্ণনা দেওয়া হয়নি।',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),

              if (book.features.isNotEmpty) ...[
                const Text('প্রধান বৈশিষ্ট্যসমূহ:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...book.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (book.galleryImages.isNotEmpty) ...[
                const Text('স্যাম্পল পাতা প্রিভিউ:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: book.galleryImages.length,
                    itemBuilder: (ctx, i) => Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: AppNetworkImage(
                        imageUrl: book.galleryImages[i],
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                        fallbackIcon: Icons.photo_outlined,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('এই বই এডিট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BookFormScreen(book: book)));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, BookModel book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('বই মুছে ফেলতে চান?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('\'${book.title}\' বইটি সম্পূর্ণ মুছে ফেলা হবে। এই কাজ আর আনডু করা যাবে না।', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<BookProvider>(context, listen: false).deleteBook(book.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
