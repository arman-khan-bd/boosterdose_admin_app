import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/courier_provider.dart';

class CourierManagerScreen extends StatefulWidget {
  const CourierManagerScreen({super.key});

  @override
  State<CourierManagerScreen> createState() => _CourierManagerScreenState();
}

class _CourierManagerScreenState extends State<CourierManagerScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String _provider = 'steadfast';
  late TabController _tabController;

  final _steadfastKeyController = TextEditingController();
  final _steadfastSecretController = TextEditingController();
  final _steadfastBaseUrlController = TextEditingController(text: 'https://portal.steadfast.com.bd/api/v1');

  final _pathaoClientController = TextEditingController();
  final _pathaoSecretController = TextEditingController();

  final _redxTokenController = TextEditingController();

  bool _obscureSteadfastSecret = true;
  bool _obscurePathaoSecret = true;
  bool _obscureRedxToken = true;

  bool _isSaving = false;
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final cp = Provider.of<CourierProvider>(context, listen: false);
    await cp.fetchCourierSettings();
    if (cp.settings != null && mounted) {
      final s = cp.settings!;
      setState(() {
        _provider = s.provider;
        _steadfastKeyController.text = s.steadfastApiKey ?? '';
        _steadfastSecretController.text = s.steadfastSecretKey ?? '';
        if (s.steadfastBaseUrl != null && s.steadfastBaseUrl!.isNotEmpty) {
          _steadfastBaseUrlController.text = s.steadfastBaseUrl!;
        }
        _pathaoClientController.text = s.pathaoClientId ?? '';
        _pathaoSecretController.text = s.pathaoClientSecret ?? '';
        _redxTokenController.text = s.redxApiToken ?? '';

        // Switch to the active provider tab
        final tabIndex = switch (_provider) {
          'steadfast' => 0,
          'pathao' => 1,
          'redx' => 2,
          _ => 3,
        };
        _tabController.index = tabIndex;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _steadfastKeyController.dispose();
    _steadfastSecretController.dispose();
    _steadfastBaseUrlController.dispose();
    _pathaoClientController.dispose();
    _pathaoSecretController.dispose();
    _redxTokenController.dispose();
    super.dispose();
  }

  Future<void> _testSteadfastConnection() async {
    final apiKey = _steadfastKeyController.text.trim();
    final secretKey = _steadfastSecretController.text.trim();
    final baseUrl = _steadfastBaseUrlController.text.trim();

    if (apiKey.isEmpty || secretKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accentRose,
          content: Text('অনুগ্রহ করে Steadfast API Key এবং Secret Key পূরণ করুন।'),
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final cp = Provider.of<CourierProvider>(context, listen: false);
    try {
      final res = await cp.testConnection(
        courierProvider: 'steadfast',
        apiKey: apiKey,
        secretKey: secretKey,
        baseUrl: baseUrl.isNotEmpty ? baseUrl : null,
      );
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = {
            'success': false,
            'message': e.toString().replaceAll('Exception:', '').trim(),
          };
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final cp = Provider.of<CourierProvider>(context, listen: false);

    final ok = await cp.updateSettings({
      'courier_provider': _provider,
      'steadfast_api_key': _steadfastKeyController.text.trim(),
      'steadfast_secret_key': _steadfastSecretController.text.trim(),
      'steadfast_base_url': _steadfastBaseUrlController.text.trim(),
      'pathao_client_id': _pathaoClientController.text.trim(),
      'pathao_client_secret': _pathaoSecretController.text.trim(),
      'redx_api_token': _redxTokenController.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('কুরিয়ার কনফিগারেশন সফলভাবে সংরক্ষণ করা হয়েছে!'),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRose,
            content: Text(cp.errorMessage ?? 'সেটিংস সংরক্ষণ ব্যর্থ হয়েছে।'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = Provider.of<CourierProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('কুরিয়ার সার্ভিস কনফিগারেশন'),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: cp.isLoading && cp.settings == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top statistics row
                    if (cp.settings != null) _buildStatsGrid(cp.settings!),
                    const SizedBox(height: 20),

                    // Active Courier Selector Card
                    _buildActiveCourierSelector(),
                    const SizedBox(height: 20),

                    // Courier Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF263345)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.primary,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF94A3B8),
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 13),
                        tabs: const [
                          Tab(text: 'Steadfast'),
                          Tab(text: 'Pathao'),
                          Tab(text: 'RedX'),
                          Tab(text: 'Manual'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab View container
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return switch (_tabController.index) {
                          0 => _buildSteadfastTab(),
                          1 => _buildPathaoTab(),
                          2 => _buildRedxTab(),
                          _ => _buildManualTab(),
                        };
                      },
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.save_rounded, color: Colors.black),
                        label: Text(
                          _isSaving ? 'সংরক্ষণ করা হচ্ছে...' : 'কুরিয়ার সেটিংস সংরক্ষণ করুন',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _saveSettings,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid(dynamic settings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'পার্সেল ডিসপ্যাচ পরিসংখ্যান',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'মোট: ${settings.dispatchedTotal}',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMiniStat('Steadfast', '${settings.steadfastCount}', AppTheme.accentCyan)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStat('Pathao', '${settings.pathaoCount}', AppTheme.accentEmerald)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStat('RedX', '${settings.redxCount}', AppTheme.accentAmber)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStat('ম্যানুয়াল', '${settings.manualCount}', const Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActiveCourierSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'ডিফল্ট সক্রিয় কুরিয়ার সার্ভিস',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'অর্ডার ডিটেইলস থেকে এক ক্লিকে বুকিং করার সময় এই কুরিয়ারটি ডিফল্ট হিসেবে নির্বাচিত থাকবে।',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _provider,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceDark,
                items: const [
                  DropdownMenuItem(
                    value: 'steadfast',
                    child: Row(
                      children: [
                        Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.accentCyan),
                        SizedBox(width: 8),
                        Text('Steadfast Courier (স্টেডফাস্ট এপিআই)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'pathao',
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 16, color: AppTheme.accentEmerald),
                        SizedBox(width: 8),
                        Text('Pathao Courier (পাঠাও)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'redx',
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 16, color: AppTheme.accentAmber),
                        SizedBox(width: 8),
                        Text('RedX Courier (রেডেক্স)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('ম্যানুয়াল / অন্যান্য কুরিয়ার', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _provider = val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteadfastTab() {
    final hasKeys = _steadfastKeyController.text.trim().isNotEmpty && _steadfastSecretController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasKeys ? AppTheme.accentEmerald : AppTheme.accentRose).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasKeys ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 14,
                      color: hasKeys ? AppTheme.accentEmerald : AppTheme.accentRose,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasKeys ? 'কনফিগার করা আছে' : 'কী দেওয়া হয়নি',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasKeys ? AppTheme.accentEmerald : AppTheme.accentRose,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.accentCyan),
                label: const Text('Steadfast Portal', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'https://portal.steadfast.com.bd/login'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('পোর্টাল লিংক কপি করা হয়েছে: https://portal.steadfast.com.bd/login')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Steadfast API Key',
            controller: _steadfastKeyController,
            hint: 'আপনার Steadfast পোর্টাল থেকে API Key পেস্ট করুন',
            icon: Icons.key_rounded,
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Steadfast Secret Key',
            controller: _steadfastSecretController,
            hint: 'আপনার Steadfast Secret Key পেস্ট করুন',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureSteadfastSecret,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSteadfastSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSteadfastSecret = !_obscureSteadfastSecret),
            ),
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'API Base URL (Default)',
            controller: _steadfastBaseUrlController,
            hint: 'https://portal.steadfast.com.bd/api/v1',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 16),

          // Test Connection button & live result
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                        )
                      : const Icon(Icons.network_check_rounded, color: AppTheme.accentCyan, size: 18),
                  label: Text(
                    _isTesting ? 'সংযোগ পরীক্ষা হচ্ছে...' : 'কানেকশন টেস্ট করুন (Test API)',
                    style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentCyan),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isTesting ? null : _testSteadfastConnection,
                ),
              ),
            ],
          ),

          // Test Result feedback banner
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testResult!['success'] == true ? AppTheme.accentEmerald : AppTheme.accentRose).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_testResult!['success'] == true ? AppTheme.accentEmerald : AppTheme.accentRose).withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testResult!['success'] == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _testResult!['success'] == true ? AppTheme.accentEmerald : AppTheme.accentRose,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _testResult!['message'] ?? (_testResult!['success'] == true ? 'সংযোগ সফল!' : 'সংযোগ ব্যর্থ'),
                          style: TextStyle(
                            color: _testResult!['success'] == true ? Colors.white : AppTheme.accentRose,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_testResult!['balance'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'বর্তমান ব্যালেন্স: ৳${_testResult!['balance']}',
                            style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathaoTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pathao Courier সেটিংস',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'পাঠাও মার্চেন্ট অ্যাকাউন্টের Developer সেটিংস থেকে প্রাপ্ত ক্রেডেনশিয়াল লিখুন।',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Pathao Client ID',
            controller: _pathaoClientController,
            hint: 'আপনার Pathao Client ID লিখুন',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            label: 'Pathao Client Secret',
            controller: _pathaoSecretController,
            hint: 'আপনার Pathao Client Secret লিখুন',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePathaoSecret,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePathaoSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePathaoSecret = !_obscurePathaoSecret),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedxTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RedX Courier সেটিংস',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'রেডেক্স মার্চেন্ট ড্যাশবোর্ডের API Settings থেকে Access Token পেস্ট করুন।',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'RedX API Access Token',
            controller: _redxTokenController,
            hint: 'আপনার RedX Access Token লিখুন',
            icon: Icons.vpn_key_rounded,
            obscureText: _obscureRedxToken,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRedxToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(() => _obscureRedxToken = !_obscureRedxToken),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263345)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.accentCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'ম্যানুয়াল / লোকাল কুরিয়ার মোড',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'আপনি যদি সুন্দরবন কুরিয়ার, এসএ পরিবহন, করতোয়া ইত্যাদি লোকাল কুরিয়ার ব্যবহার করেন, তবে কোনো এপিআই কী প্রয়োজন নেই।\n\nঅর্ডার ডিটেইলস স্ক্রিন থেকে সরাসরি কুরিয়ারের নাম এবং বুকিং স্লিপের ট্র্যাকিং কোড টাইপ করে ডিসপ্যাচ করে দিতে পারবেন। অ্যাপ স্বয়ংক্রিয়ভাবে ট্র্যাকিং কোড ট্র্যাক করবে।',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF263345)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
