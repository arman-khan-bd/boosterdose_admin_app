class SecurityConfigModel {
  final bool apiBlockingEnabled;
  final int apiBlockingCount;
  final int apiBlockingTimeWindowHours;
  final int apiBlockingDurationHours;
  final int apiBlockingCooldownSeconds;

  SecurityConfigModel({
    required this.apiBlockingEnabled,
    required this.apiBlockingCount,
    required this.apiBlockingTimeWindowHours,
    required this.apiBlockingDurationHours,
    required this.apiBlockingCooldownSeconds,
  });

  factory SecurityConfigModel.fromJson(Map<String, dynamic> json) {
    return SecurityConfigModel(
      apiBlockingEnabled: json['api_blocking_enabled'] == true ||
          json['api_blocking_enabled'] == '1' ||
          json['api_blocking_enabled'] == 1,
      apiBlockingCount: (json['api_blocking_count'] as num?)?.toInt() ?? 3,
      apiBlockingTimeWindowHours: (json['api_blocking_time_window_hours'] as num?)?.toInt() ?? 48,
      apiBlockingDurationHours: (json['api_blocking_duration_hours'] as num?)?.toInt() ?? 24,
      apiBlockingCooldownSeconds: (json['api_blocking_cooldown_seconds'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_blocking_enabled': apiBlockingEnabled,
      'api_blocking_count': apiBlockingCount,
      'api_blocking_time_window_hours': apiBlockingTimeWindowHours,
      'api_blocking_duration_hours': apiBlockingDurationHours,
      'api_blocking_cooldown_seconds': apiBlockingCooldownSeconds,
    };
  }

  SecurityConfigModel copyWith({
    bool? apiBlockingEnabled,
    int? apiBlockingCount,
    int? apiBlockingTimeWindowHours,
    int? apiBlockingDurationHours,
    int? apiBlockingCooldownSeconds,
  }) {
    return SecurityConfigModel(
      apiBlockingEnabled: apiBlockingEnabled ?? this.apiBlockingEnabled,
      apiBlockingCount: apiBlockingCount ?? this.apiBlockingCount,
      apiBlockingTimeWindowHours: apiBlockingTimeWindowHours ?? this.apiBlockingTimeWindowHours,
      apiBlockingDurationHours: apiBlockingDurationHours ?? this.apiBlockingDurationHours,
      apiBlockingCooldownSeconds: apiBlockingCooldownSeconds ?? this.apiBlockingCooldownSeconds,
    );
  }
}

class SecurityStatsModel {
  final int totalBlocked;
  final int activeBlocked;
  final int blockedIps;
  final int blockedPhones;

  SecurityStatsModel({
    required this.totalBlocked,
    required this.activeBlocked,
    required this.blockedIps,
    required this.blockedPhones,
  });

  factory SecurityStatsModel.fromJson(Map<String, dynamic> json) {
    return SecurityStatsModel(
      totalBlocked: (json['total_blocked'] as num?)?.toInt() ?? 0,
      activeBlocked: (json['active_blocked'] as num?)?.toInt() ?? 0,
      blockedIps: (json['blocked_ips'] as num?)?.toInt() ?? 0,
      blockedPhones: (json['blocked_phones'] as num?)?.toInt() ?? 0,
    );
  }
}

class BlockedEntityModel {
  final int id;
  final String type; // 'ip' or 'phone'
  final String value;
  final String? reason;
  final int orderCount;
  final String status;
  final bool isExpired;
  final bool isActive;
  final String? blockedAt;
  final String blockedAtFormatted;
  final String? blockedUntil;
  final String blockedUntilFormatted;

  BlockedEntityModel({
    required this.id,
    required this.type,
    required this.value,
    this.reason,
    required this.orderCount,
    required this.status,
    required this.isExpired,
    required this.isActive,
    this.blockedAt,
    required this.blockedAtFormatted,
    this.blockedUntil,
    required this.blockedUntilFormatted,
  });

  factory BlockedEntityModel.fromJson(Map<String, dynamic> json) {
    return BlockedEntityModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      type: json['type']?.toString() ?? 'ip',
      value: json['value']?.toString() ?? '',
      reason: json['reason']?.toString(),
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'blocked',
      isExpired: json['is_expired'] == true,
      isActive: json['is_active'] == true,
      blockedAt: json['blocked_at']?.toString(),
      blockedAtFormatted: json['blocked_at_formatted']?.toString() ?? 'N/A',
      blockedUntil: json['blocked_until']?.toString(),
      blockedUntilFormatted: json['blocked_until_formatted']?.toString() ?? 'স্থায়ী (Permanent)',
    );
  }
}
