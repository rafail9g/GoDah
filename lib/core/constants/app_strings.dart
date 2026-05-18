abstract final class AppStrings {
  // App info
  static const String appName = 'Go-Dah';
  static const String appTagline = 'Jasa angkut barang untuk mahasiswa';

  // Auth
  static const String login = 'Masuk';
  static const String register = 'Daftar';
  static const String logout = 'Keluar';
  static const String email = 'Email';
  static const String password = 'Kata sandi';
  static const String forgotPassword = 'Lupa kata sandi?';
  static const String noAccount = 'Belum punya akun?';
  static const String hasAccount = 'Sudah punya akun?';

  // Order
  static const String orderNow = 'Pesan Sekarang';
  static const String orderHistory = 'Riwayat Pesanan';
  static const String orderDetail = 'Detail Pesanan';
  static const String pickupLocation = 'Lokasi Jemput';
  static const String destination = 'Tujuan';
  static const String itemType = 'Jenis Barang';
  static const String estimatedWeight = 'Estimasi Berat (kg)';
  static const String serviceType = 'Jenis Layanan';
  static const String instant = 'Instan';
  static const String scheduled = 'Terjadwal';
  static const String totalCost = 'Total Biaya';
  static const String notes = 'Catatan untuk Porter';

  // Order status
  static const String statusMenunggu = 'Menunggu Porter';
  static const String statusDiterima = 'Diterima';
  static const String statusMenujuLokasi = 'Menuju Lokasi';
  static const String statusDalamPerjalanan = 'Dalam Perjalanan';
  static const String statusSampaiTujuan = 'Sampai Tujuan';
  static const String statusSelesai = 'Selesai';
  static const String statusBatal = 'Dibatalkan';

  // Porter
  static const String porter = 'Porter';
  static const String porterProfile = 'Profil Porter';
  static const String trackPorter = 'Lacak Porter';
  static const String rating = 'Penilaian';
  static const String review = 'Ulasan';

  // General UI
  static const String save = 'Simpan';
  static const String cancel = 'Batal';
  static const String confirm = 'Konfirmasi';
  static const String back = 'Kembali';
  static const String next = 'Lanjut';
  static const String done = 'Selesai';
  static const String retry = 'Coba Lagi';
  static const String search = 'Cari';
  static const String filter = 'Filter';
  static const String seeAll = 'Lihat Semua';
  static const String loading = 'Memuat...';
  static const String noData = 'Tidak ada data';

  // Error messages
  static const String errorGeneral = 'Terjadi kesalahan. Coba lagi.';
  static const String errorNetwork =
      'Koneksi bermasalah. Periksa internet kamu.';
  static const String errorUnauthorized = 'Sesi habis. Silakan login ulang.';
  static const String errorNotFound = 'Data tidak ditemukan.';
  static const String errorServer =
      'Server sedang bermasalah. Coba beberapa saat lagi.';

  // Validation
  static const String validRequired = 'Wajib diisi';
  static const String validEmail = 'Format email tidak valid';
  static const String validPhone = 'Nomor HP tidak valid';
  static const String validPasswordMin = 'Minimal 8 karakter';
  static const String validPasswordMatch = 'Kata sandi tidak cocok';

  // Empty state
  static const String emptyOrder = 'Belum ada pesanan';
  static const String emptyNotif = 'Tidak ada notifikasi';
  static const String emptyHistory = 'Riwayat masih kosong';
}
