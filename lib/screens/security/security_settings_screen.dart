import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/security_settings_model.dart';
import '../../services/api_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  SecurityStatsModel? _stats;
  List<BlockedEntityModel> _blockedEntities = [];

  // Form controllers & editable state
  bool _apiBlockingEnabled = true;
  int _apiBlockingCount = 3;
  int _apiBlockingTimeWindowHours = 48;
  int _apiBlockingDurationHours = 24;
  int _apiBlockingCooldownSeconds = 20;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getSecuritySettings();
      if (!mounted) return;

      final config = res['config'] as SecurityConfigModel;
      final stats = res['stats'] as SecurityStatsModel;
      final entities = res['blocked_entities'] as List<BlockedEntityModel>;

      setState(() {
        _stats = stats;
        _blockedEntities = entities;

        _apiBlockingEnabled = config.apiBlockingEnabled;
        _apiBlockingCount = config.apiBlockingCount;
        _apiBlockingTimeWindowHours = config.apiBlockingTimeWindowHours;
        _apiBlockingDurationHours = config.apiBlockingDurationHours;
        _apiBlockingCooldownSeconds = config.apiBlockingCooldownSeconds;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final newConfig = SecurityConfigModel(
        apiBlockingEnabled: _apiBlockingEnabled,
        apiBlockingCount: _apiBlockingCount,
        apiBlockingTimeWindowHours: _apiBlockingTimeWindowHours,
        apiBlockingDurationHours: _apiBlockingDurationHours,
        apiBlockingCooldownSeconds: _apiBlockingCooldownSeconds,
      );

      await ApiService.updateSecuritySettings(newConfig);
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ এপিআই ব্লকিং সেটিংস সফলভাবে সংরক্ষিত হয়েছে!'),
          backgroundColor: AppTheme.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ত্রুটি: $e'),
          backgroundColor: AppTheme.accentRose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _unblockEntity(BlockedEntityModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              '${item.type == 'ip' ? 'আইপি' : 'ফোন'} আনব্লক',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'আপনি কি নিশ্চিত যে "${item.value}" আনব্লক করতে চান?',
          style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('হ্যাঁ, আনব্লক করুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.unblockSecurityEntity(type: item.type, value: item.value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${item.value}" সফলভাবে আনব্লক করা হয়েছে!'),
          backgroundColor: AppTheme.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ আনব্লক ব্যর্থ: $e'), backgroundColor: AppTheme.accentRose),
      );
    }
  }

  Future<void> _deleteEntity(BlockedEntityModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('রেকর্ড মুছে ফেলুন', style: TextStyle(fontSize: 16, color: Colors.white)),
        content: Text(
          'তালিকা থেকে "${item.value}" এর রেকর্ডটি সম্পূর্ণ মুছে ফেলতে চান?',
          style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('মুছে ফেলুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteSecurityEntity(item.id);
      if (!mounted) return;
      _loadSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ত্রুটি: $e'), backgroundColor: AppTheme.accentRose),
      );
    }
  }

  void _showManualBlockDialog() {
    String type = 'ip';
    int duration = 24;
    final valController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.block_rounded, color: AppTheme.accentRose, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'নতুন আইপি বা ফোন ব্লক করুন',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Type selector
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => type = 'ip'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'ip' ? AppTheme.accentBlue.withOpacity(0.2) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: type == 'ip' ? AppTheme.accentBlue : const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language_rounded, color: type == 'ip' ? AppTheme.accentBlue : Colors.white60, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'আইপি (IP)',
                                style: TextStyle(
                                  color: type == 'ip' ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => type = 'phone'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'phone' ? AppTheme.accentPurple.withOpacity(0.2) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: type == 'phone' ? AppTheme.accentPurple : const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_rounded, color: type == 'phone' ? AppTheme.accentPurple : Colors.white60, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'ফোন নম্বর',
                                style: TextStyle(
                                  color: type == 'phone' ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Target Value
                Text(
                  type == 'ip' ? 'আইপি অ্যাড্রেস' : 'মোবাইল নম্বর',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: valController,
                  keyboardType: type == 'ip' ? TextInputType.number : TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: type == 'ip' ? 'e.g. 103.138.125.47' : 'e.g. 01712345678',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentRose)),
                  ),
                ),
                const SizedBox(height: 14),
                // Duration
                const Text(
                  'ব্লকিং সময়কাল ও মেয়াদ (Blocking Duration)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: duration,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('১ ঘণ্টা সাময়িক ব্লক')),
                        DropdownMenuItem(value: 6, child: Text('৬ ঘণ্টা সাময়িক ব্লক')),
                        DropdownMenuItem(value: 12, child: Text('১২ ঘণ্টা সাময়িক ব্লক')),
                        DropdownMenuItem(value: 24, child: Text('২৪ ঘণ্টা (১ দিন - প্রস্তাবিত)')),
                        DropdownMenuItem(value: 48, child: Text('৪৮ ঘণ্টা (২ দিন)')),
                        DropdownMenuItem(value: 168, child: Text('৭ দিন (১ সপ্তাহ)')),
                        DropdownMenuItem(value: 720, child: Text('৩০ দিন (১ মাস)')),
                        DropdownMenuItem(value: 0, child: Text('🔒 স্থায়ী ব্লক (Permanent)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => duration = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Reason
                const Text(
                  'ব্লকের কারণ (ঐচ্ছিক)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'বারবার ফেক অর্ডার বা অনাকাঙ্ক্ষিত অনুরোধ',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentRose)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRose,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final val = valController.text.trim();
                      if (val.isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        await ApiService.blockSecurityEntity(
                          type: type,
                          value: val,
                          durationHours: duration,
                          reason: reasonController.text.trim().isNotEmpty
                              ? reasonController.text.trim()
                              : 'Blocked via Mobile Admin App',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ $val সফলভাবে ব্লক করা হয়েছে!'),
                            backgroundColor: AppTheme.primaryDark,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _loadSettings();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ ব্লক ব্যর্থ: $e'), backgroundColor: AppTheme.accentRose),
                        );
                      }
                    },
                    child: const Text('নিশ্চিত ব্লক করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        title: const Text(
          'নিরাপত্তা ও এপিআই ব্লকিং',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadSettings,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.accentRose, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadSettings,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('আবার চেষ্টা করুন'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Overview Metrics Grid
                      _buildMetricsGrid(),
                      const SizedBox(height: 18),

                      // Configuration Policy Card
                      _buildConfigurationCard(),
                      const SizedBox(height: 24),

                      // Blocked Entities List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ব্লকড আইপি ও ফোন তালিকা',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRose.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.accentRose.withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${_blockedEntities.length}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentRose),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showManualBlockDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.accentRose),
                            label: const Text('নতুন ব্লক', style: TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Blocked list items
                      if (_blockedEntities.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 40),
                              SizedBox(height: 10),
                              Text(
                                'বর্তমানে কোনো আইপি বা ফোন ব্লক নেই',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'গ্রাহকগণ স্বাভাবিকভাবে অর্ডার ও রিকোয়েস্ট করতে পারছেন।',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._blockedEntities.map(_buildBlockedEntityCard),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricsGrid() {
    final stats = _stats;
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'মোট ব্লক',
            value: '${stats?.totalBlocked ?? 0}',
            icon: Icons.block_rounded,
            color: AppTheme.accentRose,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'সক্রিয় ব্লক',
            value: '${stats?.activeBlocked ?? 0}',
            icon: Icons.shield_outlined,
            color: AppTheme.accentAmber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'আইপি ব্লক',
            value: '${stats?.blockedIps ?? 0}',
            icon: Icons.language_rounded,
            color: AppTheme.accentBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'ফোন ব্লক',
            value: '${stats?.blockedPhones ?? 0}',
            icon: Icons.phone_rounded,
            color: AppTheme.accentPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.white60),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'কনফিগারেশন সেটিংস',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Switch(
                value: _apiBlockingEnabled,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _apiBlockingEnabled = v),
              ),
            ],
          ),
          const Text(
            'স্বয়ংক্রিয় এপিআই ব্লকিং সুরক্ষা চালু বা বন্ধ রাখুন',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),

          // Threshold Count
          _buildFormRow(
            label: '১. ব্লকিং কাউন্ট সীমা (Threshold)',
            description: 'নির্দিষ্ট সময়ে এই সংখ্যার বেশি অর্ডার বা রিকোয়েস্ট আসলে ব্লক হবে।',
            child: Row(
              children: [
                _buildCountChip(3),
                const SizedBox(width: 8),
                _buildCountChip(5),
                const SizedBox(width: 8),
                _buildCountChip(10),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      'বর্তমান: $_apiBlockingCount বার',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentAmber),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Time Window
          _buildFormRow(
            label: '২. তারিখ ও সময় ভিত্তিক গণনা সীমা (Time Window)',
            description: 'কত ঘণ্টা পেছনের অর্ডার ও রিকোয়েস্ট গণনা করা হবে।',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _apiBlockingTimeWindowHours,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('১ ঘণ্টা (গত ১ ঘণ্টার মধ্যে)')),
                    DropdownMenuItem(value: 6, child: Text('৬ ঘণ্টা (গত ৬ ঘণ্টার মধ্যে)')),
                    DropdownMenuItem(value: 12, child: Text('১২ ঘণ্টা (গত ১২ ঘণ্টার মধ্যে)')),
                    DropdownMenuItem(value: 24, child: Text('২৪ ঘণ্টা (গত ১ দিনের মধ্যে)')),
                    DropdownMenuItem(value: 48, child: Text('৪৮ ঘণ্টা (গত ২ দিনের মধ্যে - প্রস্তাবিত)')),
                    DropdownMenuItem(value: 72, child: Text('৭২ ঘণ্টা (গত ৩ দিনের মধ্যে)')),
                    DropdownMenuItem(value: 168, child: Text('৭ দিন (গত ১ সপ্তাহের মধ্যে)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _apiBlockingTimeWindowHours = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Blocking Duration
          _buildFormRow(
            label: '৩. ব্লকিং সময়কাল ও মেয়াদ (Blocking Duration)',
            description: 'ব্লক হওয়ার পর কত সময় স্থগিত থাকবে। মেয়াদ পার হলে অটো-আনব্লক হবে।',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _apiBlockingDurationHours,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('১ ঘণ্টা সাময়িক ব্লক')),
                    DropdownMenuItem(value: 6, child: Text('৬ ঘণ্টা সাময়িক ব্লক')),
                    DropdownMenuItem(value: 12, child: Text('১২ ঘণ্টা সাময়িক ব্লক')),
                    DropdownMenuItem(value: 24, child: Text('২৪ ঘণ্টা (১ দিন - প্রস্তাবিত)')),
                    DropdownMenuItem(value: 48, child: Text('৪৮ ঘণ্টা (২ দিন)')),
                    DropdownMenuItem(value: 72, child: Text('৭২ ঘণ্টা (৩ দিন)')),
                    DropdownMenuItem(value: 168, child: Text('৭ দিন (১ সপ্তাহ)')),
                    DropdownMenuItem(value: 720, child: Text('৩০ দিন (১ মাস)')),
                    DropdownMenuItem(value: 0, child: Text('🔒 স্থায়ী ব্লক (Permanent)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _apiBlockingDurationHours = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cooldown Seconds
          _buildFormRow(
            label: '৪. স্প্যাম রিকোয়েস্ট কুলডাউন (Cooldown)',
            description: 'পরপর একাধিক অর্ডার অনুরোধের মাঝে বিরতি (সেকেন্ড)।',
            child: Row(
              children: [
                _buildCooldownChip(10),
                const SizedBox(width: 8),
                _buildCooldownChip(20),
                const SizedBox(width: 8),
                _buildCooldownChip(30),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      'বর্তমান: $_apiBlockingCooldownSeconds সেকেন্ড',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _isSaving ? 'সংরক্ষণ হচ্ছে...' : 'সেটিংস সংরক্ষণ করুন',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow({required String label, required String description, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(description, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCountChip(int count) {
    final isSelected = _apiBlockingCount == count;
    return InkWell(
      onTap: () => setState(() => _apiBlockingCount = count),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentAmber.withOpacity(0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentAmber : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$count বার',
          style: TextStyle(
            color: isSelected ? AppTheme.accentAmber : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCooldownChip(int sec) {
    final isSelected = _apiBlockingCooldownSeconds == sec;
    return InkWell(
      onTap: () => setState(() => _apiBlockingCooldownSeconds = sec),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCyan.withOpacity(0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$sec সে.',
          style: TextStyle(
            color: isSelected ? AppTheme.accentCyan : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedEntityCard(BlockedEntityModel item) {
    final isIp = item.type == 'ip';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? AppTheme.accentRose.withOpacity(0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Type & Value + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isIp ? AppTheme.accentBlue.withOpacity(0.15) : AppTheme.accentPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isIp ? AppTheme.accentBlue.withOpacity(0.3) : AppTheme.accentPurple.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isIp ? Icons.language_rounded : Icons.phone_rounded,
                        size: 13, color: isIp ? AppTheme.accentBlue : AppTheme.accentPurple),
                    const SizedBox(width: 4),
                    Text(
                      isIp ? 'আইপি' : 'ফোন',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isIp ? AppTheme.accentBlue : AppTheme.accentPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white, fontFamily: 'monospace'),
                ),
              ),
              if (item.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRose.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: AppTheme.accentRose, size: 7),
                      SizedBox(width: 4),
                      Text('সক্রিয় ব্লক', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentRose)),
                    ],
                  ),
                )
              else if (item.isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('মেয়াদোত্তীর্ণ', style: TextStyle(fontSize: 10, color: Colors.white54)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('আনব্লকড', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Date & Time rows
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                'ব্লক করার সময়: ${item.blockedAtFormatted}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded, size: 14, color: AppTheme.accentAmber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ব্লকিং মেয়াদ: ${item.blockedUntilFormatted}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: item.isExpired ? Colors.white38 : AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),

          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'কারণ: ${item.reason}',
              style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 6),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'চেষ্টা/অর্ডার: ${item.orderCount} টি',
                style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (item.isActive)
                    TextButton.icon(
                      onPressed: () => _unblockEntity(item),
                      icon: const Icon(Icons.lock_open_rounded, size: 15, color: AppTheme.primary),
                      label: const Text('আনব্লক করুন', style: TextStyle(color: AppTheme.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  IconButton(
                    onPressed: () => _deleteEntity(item),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white38),
                    tooltip: 'রেকর্ড মুছুন',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
