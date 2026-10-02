class CourierSettingsModel {
  final String provider;
  final String? steadfastApiKey;
  final String? steadfastSecretKey;
  final String? steadfastBaseUrl;
  final String? pathaoClientId;
  final String? pathaoClientSecret;
  final String? redxApiToken;
  final Map<String, dynamic> stats;

  final List<Map<String, dynamic>> configuredCouriers;

  CourierSettingsModel({
    required this.provider,
    this.steadfastApiKey,
    this.steadfastSecretKey,
    this.steadfastBaseUrl,
    this.pathaoClientId,
    this.pathaoClientSecret,
    this.redxApiToken,
    required this.stats,
    this.configuredCouriers = const [],
  });

  factory CourierSettingsModel.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : <String, dynamic>{};
    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : <String, dynamic>{};
    final configured = (json['configured_couriers'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return CourierSettingsModel(
      provider: settings['courier_provider'] ?? 'steadfast',
      steadfastApiKey: settings['steadfast_api_key'],
      steadfastSecretKey: settings['steadfast_secret_key'],
      steadfastBaseUrl: settings['steadfast_base_url'],
      pathaoClientId: settings['pathao_client_id'],
      pathaoClientSecret: settings['pathao_client_secret'],
      redxApiToken: settings['redx_api_token'],
      stats: stats,
      configuredCouriers: configured,
    );
  }

  bool get isSteadfastConfigured =>
      (steadfastApiKey != null && steadfastApiKey!.trim().isNotEmpty) &&
      (steadfastSecretKey != null && steadfastSecretKey!.trim().isNotEmpty);

  bool get isPathaoConfigured =>
      (pathaoClientId != null && pathaoClientId!.trim().isNotEmpty) &&
      (pathaoClientSecret != null && pathaoClientSecret!.trim().isNotEmpty);

  bool get isRedxConfigured =>
      redxApiToken != null && redxApiToken!.trim().isNotEmpty;

  bool get hasAnyConfigured =>
      isSteadfastConfigured || isPathaoConfigured || isRedxConfigured;

  int get steadfastCount => int.tryParse(stats['steadfast']?.toString() ?? '0') ?? 0;
  int get pathaoCount => int.tryParse(stats['pathao']?.toString() ?? '0') ?? 0;
  int get redxCount => int.tryParse(stats['redx']?.toString() ?? '0') ?? 0;
  int get manualCount => int.tryParse(stats['manual']?.toString() ?? '0') ?? 0;
  int get dispatchedTotal => int.tryParse(stats['dispatched_total']?.toString() ?? '0') ?? 0;
}
