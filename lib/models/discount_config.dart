/// Per-variant discount configuration, as configured by the seller and
/// returned by the backend after being applied.
///
/// `currentlyEffective`, `effectivePrice`, and `effectivePercentage` are
/// response-only — the backend computes them from `type`/`value`/`active`/
/// the schedule window and today's date. They are omitted from [toJson]
/// since the PATCH request only needs the seller-configured fields.
enum DiscountType {
  percentage,
  flat;

  String toJsonValue() => this == DiscountType.percentage ? 'PERCENTAGE' : 'FLAT';

  static DiscountType fromJsonValue(String? v) {
    switch (v?.toUpperCase()) {
      case 'FLAT':
        return DiscountType.flat;
      case 'PERCENTAGE':
      default:
        return DiscountType.percentage;
    }
  }
}

class DiscountConfig {
  final DiscountType type;
  final double value;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;

  // Response-only fields — null when this instance represents an
  // in-progress edit rather than a value read back from the backend.
  final bool? currentlyEffective;
  final double? effectivePrice;
  final double? effectivePercentage;

  const DiscountConfig({
    required this.type,
    required this.value,
    this.active = true,
    this.startsAt,
    this.endsAt,
    this.currentlyEffective,
    this.effectivePrice,
    this.effectivePercentage,
  });

  factory DiscountConfig.fromJson(Map<String, dynamic> json) {
    return DiscountConfig(
      type:   DiscountType.fromJsonValue(json['type'] as String?),
      value:  _toDouble(json['value']),
      active: json['active'] as bool? ?? true,
      startsAt: _toDateTime(json['startsAt']),
      endsAt:   _toDateTime(json['endsAt']),
      currentlyEffective:  json['currentlyEffective'] as bool?,
      effectivePrice:      json['effectivePrice'] != null ? _toDouble(json['effectivePrice']) : null,
      effectivePercentage: json['effectivePercentage'] != null ? _toDouble(json['effectivePercentage']) : null,
    );
  }

  /// Request body for the add-variants / discount PATCH endpoints — only the
  /// seller-configured fields, never the response-only computed ones.
  Map<String, dynamic> toJson() => {
        'type':     type.toJsonValue(),
        'value':    value,
        'active':   active,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'endsAt':   endsAt?.toUtc().toIso8601String(),
      };

  DiscountConfig copyWith({
    DiscountType? type,
    double? value,
    bool? active,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearStartsAt = false,
    bool clearEndsAt   = false,
  }) {
    return DiscountConfig(
      type:   type   ?? this.type,
      value:  value  ?? this.value,
      active: active ?? this.active,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt:   clearEndsAt   ? null : (endsAt   ?? this.endsAt),
      currentlyEffective:  currentlyEffective,
      effectivePrice:      effectivePrice,
      effectivePercentage: effectivePercentage,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
