import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_badge.dart';
import 'abandoned_orders/abandoned_orders_screen.dart';
import 'books/books_list_screen.dart';
import 'courier/courier_manager_screen.dart';
import 'notifications/notification_manager_screen.dart';
import 'orders/order_detail_screen.dart';
import 'orders/orders_list_screen.dart';
import 'profile/profile_screen.dart';
import 'reviews/reviews_manager_screen.dart';
import 'sections/sections_manager_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final data = dashboard.data;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'বুস্টার ডোজ ওভারভিউ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  auth.user?.name ?? 'অ্যাডমিন',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => dashboard.fetchDashboardData(),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
      body: dashboard.isLoading && data == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : dashboard.errorMessage != null && data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppTheme.accentRose, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          dashboard.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => dashboard.fetchDashboardData(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('আবার চেষ্টা করুন'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => dashboard.fetchDashboardData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action Buttons Grid (Required: manage orders, abandand orders, books manager, profile data manager ,review, currier service manager, sections data manager, notification manager)
                        _buildQuickActionButtons(),
                        const SizedBox(height: 24),

                        // High-Level KPIs
                        if (data != null) ...[
                          _buildKpiMetrics(data),
                          const SizedBox(height: 24),

                          // 14-Day Sales & Orders Chart
                          _buildChartCard(data),
                          const SizedBox(height: 24),

                          // Status Distribution
                          _buildStatusDistribution(data),
                          const SizedBox(height: 24),

                          // Top Selling Books
                          _buildTopBooks(data),
                          const SizedBox(height: 24),

                          // Recent Orders
                          _buildRecentOrders(data),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'কুইক অ্যাকশন কন্ট্রোল',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildActionItem(
              icon: Icons.shopping_bag_outlined,
              title: 'অর্ডারস',
              color: AppTheme.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen())),
            ),
            _buildActionItem(
              icon: Icons.remove_shopping_cart_outlined,
              title: 'পরিত্যক্ত',
              color: AppTheme.accentRose,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AbandonedOrdersScreen())),
            ),
            _buildActionItem(
              icon: Icons.menu_book_outlined,
              title: 'বইসমূহ',
              color: AppTheme.accentCyan,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksListScreen())),
            ),
            _buildActionItem(
              icon: Icons.rate_review_outlined,
              title: 'রিভিউ',
              color: AppTheme.accentAmber,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsManagerScreen())),
            ),
            _buildActionItem(
              icon: Icons.local_shipping_outlined,
              title: 'কুরিয়ার',
              color: AppTheme.accentBlue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourierManagerScreen())),
            ),
            _buildActionItem(
              icon: Icons.view_quilt_outlined,
              title: 'সেকশনস',
              color: AppTheme.accentPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SectionsManagerScreen())),
            ),
            _buildActionItem(
              icon: Icons.notifications_none_rounded,
              title: 'অ্যালার্ট ফিড',
              color: Colors.orangeAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationManagerScreen())),
            ),
            _buildActionItem(
              icon: Icons.person_outline_rounded,
              title: 'প্রোফাইল',
              color: Colors.tealAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMetrics(dynamic data) {
    final s = data.stats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double ratio = width < 360 ? 1.05 : (width < 450 ? 1.15 : (width < 700 ? 1.35 : 1.55));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'মূল পরিসংখ্যান (Key Metrics)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  title: 'সর্বমোট রাজস্ব',
                  value: '৳ ${currencyFormat.format(s.totalRevenue)}',
                  subtitle: 'AOV: ৳${s.aov.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.primary,
                ),
                MetricCard(
                  title: 'মোট অর্ডার',
                  value: '${s.totalOrders}',
                  subtitle: 'আজকে: ${s.todayOrders}',
                  icon: Icons.shopping_bag_rounded,
                  color: AppTheme.accentBlue,
                ),
                MetricCard(
                  title: 'পেন্ডিং অর্ডার',
                  value: '${s.pendingOrders}',
                  subtitle: 'প্রসেসিং: ${s.processingOrders}',
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.accentAmber,
                ),
                MetricCard(
                  title: 'পরিত্যক্ত কার্ট',
                  value: '${s.abandonedCount}',
                  subtitle: 'রিকভার্ড: ${s.recoveredCount}',
                  icon: Icons.remove_shopping_cart_rounded,
                  color: AppTheme.accentRose,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartCard(dynamic data) {
    final points = data.chartData;
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
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
                'দৈনিক রাজস্ব ও অর্ডার ট্রেন্ড (১৪ দিন)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Live Data',
                  style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF263345),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < points.length) {
                          return Text(
                            points[idx].date,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points.asMap().entries.map<FlSpot>((e) {
                      return FlSpot(e.key.toDouble(), e.value.revenue);
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution(dynamic data) {
    final list = data.statusDistribution;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'অর্ডার স্ট্যাটাস বিভাজন',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...list.map((item) {
            Color itemColor;
            try {
              itemColor = Color(int.parse(item.colorHex.replaceFirst('#', '0xFF')));
            } catch (_) {
              itemColor = AppTheme.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: itemColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.label,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '${item.count} (${item.percent}%)',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.percent / 100,
                      backgroundColor: const Color(0xFF263345),
                      valueColor: AlwaysStoppedAnimation<Color>(itemColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopBooks(dynamic data) {
    final books = data.topBooks;
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'সর্বাধিক বিক্রিত বইসমূহ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (ctx, i) {
              final b = books[i];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF263345)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF243247),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.book, color: AppTheme.primary, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.title,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'বিক্রি: ${b.totalSold} কপি • ৳${b.totalRevenue.toInt()}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
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

  Widget _buildRecentOrders(dynamic data) {
    final recent = data.recentOrders;
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'সাম্প্রতিক অর্ডারসমূহ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen()));
              },
              child: const Text('সব দেখুন →', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recent.map((order) {
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF263345)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '#${order['order_number']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '৳${order['total_amount']}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order['customer_name']} • ${order['customer_phone']}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge(status: order['status'] ?? 'pending'),
                            Text(
                              order['time_ago'] ?? '',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
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
        }),
      ],
    );
  }
}
