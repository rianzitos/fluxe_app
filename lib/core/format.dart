/// Formatação em português do Brasil (sem depender de intl).
library;

String fmtNum(num v, {int decimals = 0}) {
  final negative = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final out = parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  return negative ? '-$out' : out;
}

/// Valor de card: inteiro quando for redondo ("106"), senão 1 casa ("84,2").
String fmtValor(double v) => fmtNum(v, decimals: v == v.roundToDouble() ? 0 : 1);

/// "+3,5%" / "-80,8%" / "+0,0%".
String fmtVariacao(double v) => '${v >= 0 ? '+' : '-'}${fmtNum(v.abs(), decimals: 1)}%';

String two(int n) => n.toString().padLeft(2, '0');

String fmtData(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// 'yyyy-MM-dd' usado pela API.
String isoData(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime? parseIso(String? s) {
  if (s == null || s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

/// "2026-10-06" -> "06/10/2026".
String isoParaBr(String? s) {
  final d = parseIso(s);
  return d == null ? (s ?? '') : fmtData(d);
}

String iniciais(String nome) {
  final p = nome.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p.first[0].toUpperCase();
  return (p.first[0] + p.last[0]).toUpperCase();
}
