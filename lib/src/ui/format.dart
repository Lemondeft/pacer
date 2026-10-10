/// Shared display formatters for activity values (Indonesian number style).
/// Used by the home, history, and tracker screens so pace/distance render
/// identically everywhere.
library;

/// d/M/yyyy; '' when null.
String fmtDate(DateTime? d) => d == null ? '' : '${d.day}/${d.month}/${d.year}';

/// h.mm.ss (or mm.ss under an hour) like the Figma cards; '' when null.
String fmtDurasi(int? s) {
  if (s == null) return '';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h.${two(m)}.${two(sec)}' : '${two(m)}.${two(sec)}';
}

/// Min/km pace as 5'12" from seconds + meters; '' when not computable.
/// Rounds total seconds first so seconds never print as 60.
String fmtPace(int? durasiS, double? jarakM) {
  if (durasiS == null || jarakM == null || jarakM <= 0) return '';
  final totalS = (durasiS / (jarakM / 1000)).round();
  final m = totalS ~/ 60;
  final s = totalS % 60;
  return "$m'${s.toString().padLeft(2, '0')}\"";
}

/// '15,00 Km' from meters; '' when null.
String fmtKm(double? m) =>
    m == null ? '' : '${(m / 1000).toStringAsFixed(2).replaceAll('.', ',')} Km';

/// Plain km number ('15,00') for hero displays.
String fmtKmNum(double? m) =>
    m == null ? '' : (m / 1000).toStringAsFixed(2).replaceAll('.', ',');
