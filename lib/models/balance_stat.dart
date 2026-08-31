/// A single balance/stat tile with an optional sparkline trend.
class BalanceStat {
  final String label;
  final String value; // pre-formatted display value, e.g. "₹849"
  final double changePct;
  final List<double> sparkline;

  const BalanceStat({
    required this.label,
    required this.value,
    required this.changePct,
    required this.sparkline,
  });

  factory BalanceStat.fromJson(Map<String, dynamic> json) {
    final rawSparkline = json['sparkline'];
    return BalanceStat(
      label:     json['label'] as String? ?? '',
      value:     json['value'] as String? ?? '',
      changePct: (json['changePct'] as num?)?.toDouble() ?? 0.0,
      sparkline: rawSparkline is List
          ? rawSparkline
              .map((e) => (e as num?)?.toDouble() ?? 0.0)
              .toList()
          : const [],
    );
  }
}
