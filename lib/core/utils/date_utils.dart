/// Utilitas format tanggal dan waktu untuk Go-Dah.
abstract final class AppDateUtils {
  // ── Relative time ("time ago") ────────────────────────────────────

  /// Kembalikan label relatif dari sebuah DateTime.
  /// "Baru saja", "5 menit lalu", "2 jam lalu", "Kemarin", dll.
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60)   return 'Baru saja';
    if (diff.inMinutes < 60)   return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24)     return '${diff.inHours} jam lalu';
    if (diff.inDays == 1)      return 'Kemarin';
    if (diff.inDays < 7)       return '${diff.inDays} hari lalu';
    if (diff.inDays < 30)      return '${(diff.inDays / 7).floor()} minggu lalu';
    if (diff.inDays < 365)     return '${(diff.inDays / 30).floor()} bulan lalu';
    return '${(diff.inDays / 365).floor()} tahun lalu';
  }

  // ── Format tanggal ─────────────────────────────────────────────────

  /// "Senin, 18 Mei 2026"
  static String toFullDate(DateTime dt) =>
      '${_dayName(dt.weekday)}, ${dt.day} ${_monthName(dt.month)} ${dt.year}';

  /// "18 Mei 2026"
  static String toShortDate(DateTime dt) =>
      '${dt.day} ${_monthName(dt.month)} ${dt.year}';

  /// "18/05/2026"
  static String toNumericDate(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';

  /// "2026-05-18" (format ISO untuk API)
  static String toIsoDate(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';

  // ── Format waktu ────────────────────────────────────────────────────

  /// "14:35"
  static String toTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  /// "14:35:20"
  static String toTimeFull(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';

  // ── Format gabungan ────────────────────────────────────────────────

  /// "18 Mei 2026, 14:35"
  static String toDateTimeShort(DateTime dt) =>
      '${toShortDate(dt)}, ${toTime(dt)}';

  /// "Senin, 18 Mei 2026 pukul 14:35"
  static String toDateTimeFull(DateTime dt) =>
      '${toFullDate(dt)} pukul ${toTime(dt)}';

  // ── Duration ───────────────────────────────────────────────────────

  /// "2 jam 15 menit"
  static String formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h == 0) return '$m menit';
    if (m == 0) return '$h jam';
    return '$h jam $m menit';
  }

  // ── Helpers ────────────────────────────────────────────────────────
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _monthName(int month) => const [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ][month];

  static String _dayName(int weekday) => const [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ][weekday];
}
