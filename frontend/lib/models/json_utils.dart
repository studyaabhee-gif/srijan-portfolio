typedef Json = Map<String, dynamic>;

List<String> strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

List<T> objects<T>(dynamic v, T Function(Json) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

String str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

String? optStr(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

int integer(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

int? optInt(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
