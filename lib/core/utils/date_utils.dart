abstract final class AppDateUtils {

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


  static String toFullDate(DateTime dt) =>
      '${_dayName(dt.weekday)}, ${dt.day} ${_monthName(dt.month)} ${dt.year}';

  static String toShortDate(DateTime dt) =>
      '${dt.day} ${_monthName(dt.month)} ${dt.year}';

  static String toNumericDate(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';

  static String toIsoDate(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';


  static String toTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  static String toTimeFull(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';


  static String toDateTimeShort(DateTime dt) =>
      '${toShortDate(dt)}, ${toTime(dt)}';

  static String toDateTimeFull(DateTime dt) =>
      '${toFullDate(dt)} pukul ${toTime(dt)}';


  static String formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h == 0) return '$m menit';
    if (m == 0) return '$h jam';
    return '$h jam $m menit';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _monthName(int month) => const [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ][month];

  static String _dayName(int weekday) => const [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ][weekday];
}
