/// A single week's worth of seller activity stats (products/views/comments)
/// with optional week-over-week percent changes.
class ActivityWeek {
  final String weekLabel;
  final int products;
  final double? productsChangePct;
  final int views;
  final double? viewsChangePct;
  final int comments;
  final double? commentsChangePct;

  const ActivityWeek({
    required this.weekLabel,
    required this.products,
    this.productsChangePct,
    required this.views,
    this.viewsChangePct,
    required this.comments,
    this.commentsChangePct,
  });

  factory ActivityWeek.fromJson(Map<String, dynamic> json) {
    return ActivityWeek(
      weekLabel:         json['weekLabel'] as String? ?? '',
      products:           _toInt(json['products']),
      productsChangePct: (json['productsChangePct'] as num?)?.toDouble(),
      views:              _toInt(json['views']),
      viewsChangePct:    (json['viewsChangePct'] as num?)?.toDouble(),
      comments:           _toInt(json['comments']),
      commentsChangePct: (json['commentsChangePct'] as num?)?.toDouble(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
