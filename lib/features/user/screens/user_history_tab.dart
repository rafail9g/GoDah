// lib/features/user/screens/user_history_tab.dart
// CHANGES:
// 1. Active orders dengan porter assigned → tambah tombol "Lacak Porter"
// 2. Navigasi ke UserTrackingScreen (real-time GPS maps, kayak Gojek)
// 3. Tombol muncul hanya jika porter sudah menerima (bukan status 'menunggu')

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';
import 'user_tracking_screen.dart';

final _supabase = Supabase.instance.client;

class UserHistoryTab extends StatefulWidget {
  const UserHistoryTab({super.key});

  @override
  State<UserHistoryTab> createState() => _UserHistoryTabState();
}

class _UserHistoryTabState extends State<UserHistoryTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;

      final active = await _supabase
          .from('orders')
          .select('''
            *,
            porters(id, nama, no_hp, foto_profil, latitude, longitude),
            order_tracking(status_perjalanan, waktu_update, catatan)
          ''')
          .eq('user_id', user.id)
          .inFilter('status', [
            'menunggu',
            'diterima',
            'menuju_lokasi',
            'dalam_perjalanan',
            'sampai_tujuan',
          ])
          .order('waktu_pesan', ascending: false);

      final completed = await _supabase
          .from('orders')
          .select('''
            *,
            porters(id, nama, no_hp, foto_profil),
            bukti_pengiriman(foto_url, keterangan, jenis_bukti),
            ratings(nilai, ulasan)
          ''')
          .eq('user_id', user.id)
          .inFilter('status', ['selesai', 'batal'])
          .order('waktu_pesan', ascending: false);

      setState(() {
        _activeOrders = List<Map<String, dynamic>>.from(active);
        _completedOrders = List<Map<String, dynamic>>.from(completed);
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _batalOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Order?'),
        content: const Text('Apakah kamu yakin ingin membatalkan order ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('orders')
          .update({'status': 'batal'})
          .eq('id', orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order dibatalkan.'),
          backgroundColor: AppColors.grey700,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _kirimRating(String orderId, String porterId) async {
    int nilaiRating = 5;
    final ulasanCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Beri Penilaian Porter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bagaimana layanan porter kali ini?',
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setDialogState(() => nilaiRating = i + 1),
                    child: Icon(
                      i < nilaiRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.warning,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ulasanCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Tulis ulasan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) return;

    try {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      await _supabase.from('ratings').insert({
        'order_id': orderId,
        'user_id': user?.id,
        'porter_id': porterId,
        'nilai': nilaiRating,
        if (ulasanCtrl.text.trim().isNotEmpty) 'ulasan': ulasanCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Terima kasih atas penilaiannya!'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Navigasi ke real-time tracking screen ────────────────────────────
  void _lacakPorter(Map<String, dynamic> order) {
    final porter = order['porters'] as Map<String, dynamic>?;
    final porterId = porter?['id'] as String? ?? order['porter_id'] as String?;

    if (porterId == null) return;

    final latJemput = (order['lat_jemput'] as num?)?.toDouble() ?? 0;
    final lngJemput = (order['lng_jemput'] as num?)?.toDouble() ?? 0;
    final latTujuan = (order['lat_tujuan'] as num?)?.toDouble() ?? 0;
    final lngTujuan = (order['lng_tujuan'] as num?)?.toDouble() ?? 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserTrackingScreen(
          orderId: order['id'] as String,
          porterId: porterId,
          latJemput: latJemput,
          lngJemput: lngJemput,
          latTujuan: latTujuan,
          lngTujuan: lngTujuan,
          lokasiJemput: order['lokasi_jemput'] as String? ?? '-',
          lokasiTujuan: order['lokasi_tujuan'] as String? ?? '-',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          tabs: [
            Tab(text: 'Aktif (${_activeOrders.length})'),
            Tab(text: 'Selesai (${_completedOrders.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _ActiveOrderList(
                  orders: _activeOrders,
                  onBatal: _batalOrder,
                  onLacak: _lacakPorter,
                ),
                _CompletedOrderList(
                  orders: _completedOrders,
                  onKirimRating: _kirimRating,
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE ORDER LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveOrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final void Function(String) onBatal;
  final void Function(Map<String, dynamic>) onLacak;

  const _ActiveOrderList({
    required this.orders,
    required this.onBatal,
    required this.onLacak,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Tidak Ada Order Aktif',
        subtitle: 'Buat pesanan baru dari tab Pesan.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => _ActiveOrderCard(
          order: orders[i],
          onBatal: () => onBatal(orders[i]['id'] as String),
          onLacak: () => onLacak(orders[i]),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onBatal;
  final VoidCallback onLacak;

  const _ActiveOrderCard({
    required this.order,
    required this.onBatal,
    required this.onLacak,
  });

  Color _statusColor(String s) => switch (s) {
    'menunggu' => AppColors.statusMenunggu,
    'diterima' => AppColors.statusDiterima,
    'menuju_lokasi' => AppColors.statusMenujuLokasi,
    'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
    'sampai_tujuan' => AppColors.statusSampaiTujuan,
    _ => AppColors.grey400,
  };

  String _statusLabel(String s) => switch (s) {
    'menunggu' => '🕐 Mencari Porter...',
    'diterima' => '✅ Porter Menerima Ordermu',
    'menuju_lokasi' => '🚶 Porter Menuju Lokasimu',
    'dalam_perjalanan' => '🚚 Barang Sedang Dibawa',
    'sampai_tujuan' => '📍 Barang Sudah Sampai',
    _ => s,
  };

  String _statusSubtitle(String s) => switch (s) {
    'menunggu' => 'Menunggu porter terdekat menerima',
    'diterima' => 'Porter sedang dalam perjalanan ke lokasimu',
    'menuju_lokasi' => 'Porter sedang menuju titik penjemputan',
    'dalam_perjalanan' => 'Barangmu sedang diantar ke tujuan',
    'sampai_tujuan' => 'Barangmu sudah tiba di tujuan!',
    _ => '',
  };

  // Apakah porter sudah assigned dan bisa dilacak di maps
  bool get _bisaDilacak {
    final status = order['status'] as String? ?? '';
    final porterId = order['porter_id'];
    return porterId != null && status != 'menunggu';
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final color = _statusColor(status);
    final porter = order['porters'] as Map<String, dynamic>?;
    final biaya = (order['total_biaya'] as num? ?? 0).toInt();
    final tracking = order['order_tracking'] as List?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(status),
                  style: AppTextStyles.labelLg.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_statusSubtitle(status).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _statusSubtitle(status),
                    style: AppTextStyles.caption.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lokasi
                _LokasiRow(
                  icon: Icons.radio_button_on_rounded,
                  color: AppColors.success,
                  label: 'Jemput',
                  text: order['lokasi_jemput'] as String? ?? '-',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: AppColors.grey200,
                  ),
                ),
                _LokasiRow(
                  icon: Icons.location_on_rounded,
                  color: AppColors.error,
                  label: 'Tujuan',
                  text: order['lokasi_tujuan'] as String? ?? '-',
                ),
                const Divider(height: 20),

                // Info chips
                Row(
                  children: [
                    _InfoChipUser(
                      icon: Icons.category_outlined,
                      text: order['jenis_barang'] as String? ?? '-',
                    ),
                    const SizedBox(width: 8),
                    _InfoChipUser(
                      icon: Icons.scale_rounded,
                      text: '${order['estimasi_berat'] ?? '-'} kg',
                    ),
                    const Spacer(),
                    Text(
                      'Rp ${_rupiahFormat(biaya)}',
                      style: AppTextStyles.priceMd,
                    ),
                  ],
                ),

                // ── Porter info + Tombol Lacak ───────────────────────
                if (porter != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary100,
                        child: Text(
                          (porter['nama'] as String? ?? 'P')[0].toUpperCase(),
                          style: AppTextStyles.labelLg.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Portermu', style: AppTextStyles.caption),
                            Text(
                              porter['nama'] as String? ?? '-',
                              style: AppTextStyles.labelLg,
                            ),
                          ],
                        ),
                      ),
                      // Tombol Hubungi
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: const Text('Hubungi'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ],
                  ),

                  // ── TOMBOL LACAK PORTER (kayak Gojek) ───────────────
                  if (_bisaDilacak) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onLacak,
                        icon: const Icon(
                          Icons.location_searching_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Lacak Porter di Peta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3C72),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ],

                // Tracking steps timeline
                if (tracking != null && tracking.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.timeline_rounded,
                        size: 14,
                        color: AppColors.grey500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Riwayat Status',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...tracking
                      .cast<Map<String, dynamic>>()
                      .take(3)
                      .map((t) => _TrackingItem(tracking: t)),
                ],

                // Batalkan order (hanya saat masih menunggu)
                if (status == 'menunggu') ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onBatal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Batalkan Order'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rupiahFormat(int n) {
    final str = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }
}

class _TrackingItem extends StatelessWidget {
  final Map<String, dynamic> tracking;
  const _TrackingItem({required this.tracking});

  @override
  Widget build(BuildContext context) {
    String waktu = '-';
    try {
      final dt = DateTime.parse(tracking['waktu_update'] as String).toLocal();
      waktu =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 7, color: AppColors.primary200),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tracking['catatan'] as String? ??
                  tracking['status_perjalanan'] as String? ??
                  '-',
              style: AppTextStyles.bodySm,
            ),
          ),
          Text(waktu, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETED ORDER LIST
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedOrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final void Function(String orderId, String porterId) onKirimRating;

  const _CompletedOrderList({
    required this.orders,
    required this.onKirimRating,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'Belum Ada Riwayat',
        subtitle: 'Order yang selesai akan tampil di sini.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final order = orders[i];
        final porter = order['porters'] as Map<String, dynamic>?;
        final porterId =
            porter?['id'] as String? ?? order['porter_id'] as String? ?? '';
        return _CompletedOrderCard(
          order: order,
          onKirimRating: porterId.isNotEmpty
              ? () => onKirimRating(order['id'] as String, porterId)
              : null,
        );
      },
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onKirimRating;

  const _CompletedOrderCard({required this.order, this.onKirimRating});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final isSelesai = status == 'selesai';
    final statusColor = isSelesai
        ? AppColors.statusSelesai
        : AppColors.statusBatal;
    final porter = order['porters'] as Map<String, dynamic>?;

    // Bukti pengiriman bisa multiple (jemput + antar)
    final buktis = order['bukti_pengiriman'];
    final List<Map<String, dynamic>> buktiList = buktis is List
        ? buktis.cast<Map<String, dynamic>>()
        : [];
    final buktiAntar = buktiList
        .where((b) => b['jenis_bukti'] == 'delivery')
        .firstOrNull;
    final buktiJemput = buktiList
        .where((b) => b['jenis_bukti'] == 'pickup')
        .firstOrNull;

    final ratings = order['ratings'];
    final Map<String, dynamic>? ratingData =
        ratings is List && ratings.isNotEmpty
        ? ratings[0] as Map<String, dynamic>
        : null;

    final biaya = (order['total_biaya'] as num? ?? 0).toInt();
    final hasRating = ratingData != null;

    String tanggal = '-';
    try {
      final dt = DateTime.parse(order['waktu_pesan'] as String).toLocal();
      tanggal = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusRound),
                  ),
                  child: Text(
                    isSelesai ? '✅ Selesai' : '❌ Dibatalkan',
                    style: AppTextStyles.labelSm.copyWith(color: statusColor),
                  ),
                ),
                const Spacer(),
                Text(tanggal, style: AppTextStyles.caption),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LokasiRow(
                  icon: Icons.radio_button_on_rounded,
                  color: AppColors.success,
                  label: 'Jemput',
                  text: order['lokasi_jemput'] as String? ?? '-',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: AppColors.grey200,
                  ),
                ),
                _LokasiRow(
                  icon: Icons.location_on_rounded,
                  color: AppColors.error,
                  label: 'Tujuan',
                  text: order['lokasi_tujuan'] as String? ?? '-',
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChipUser(
                      icon: Icons.category_outlined,
                      text: order['jenis_barang'] as String? ?? '-',
                    ),
                    _InfoChipUser(
                      icon: Icons.bolt_rounded,
                      text: (order['jenis_layanan'] as String?) == 'instant'
                          ? 'Instan'
                          : 'Terjadwal',
                    ),
                    _InfoChipUser(
                      icon: Icons.payments_outlined,
                      text: 'Rp ${_rupiahFormat(biaya)}',
                    ),
                  ],
                ),

                if (porter != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary100,
                        child: Text(
                          (porter['nama'] as String? ?? 'P')[0].toUpperCase(),
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          porter['nama'] as String? ?? '-',
                          style: AppTextStyles.labelLg,
                        ),
                      ),
                    ],
                  ),
                ],

                // Bukti foto jemput
                if (buktiJemput != null) ...[
                  const Divider(height: 20),
                  Text(
                    '📸 Foto Barang saat Penjemputan',
                    style: AppTextStyles.labelLg,
                  ),
                  const SizedBox(height: 8),
                  _FotoBuktiTile(url: buktiJemput['foto_url'] as String),
                ],

                // Bukti foto antar
                if (buktiAntar != null) ...[
                  const Divider(height: 20),
                  Text('📸 Bukti Pengiriman', style: AppTextStyles.labelLg),
                  const SizedBox(height: 8),
                  _FotoBuktiTile(url: buktiAntar['foto_url'] as String),
                  if ((buktiAntar['keterangan'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        buktiAntar['keterangan'] as String,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ),
                ],

                // Rating
                if (hasRating) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < (ratingData['nilai'] as int? ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ratingData['ulasan'] as String? ??
                              'Tidak ada ulasan',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isSelesai && onKirimRating != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onKirimRating,
                    icon: const Icon(Icons.star_outline_rounded, size: 16),
                    label: const Text('Beri Penilaian Porter'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rupiahFormat(int n) {
    final str = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }
}

class _FotoBuktiTile extends StatelessWidget {
  final String url;
  const _FotoBuktiTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Image.network(
          url,
          height: 130,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  height: 130,
                  color: AppColors.grey100,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
          errorBuilder: (_, __, ___) => Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: 36,
                color: AppColors.grey400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _LokasiRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const _LokasiRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                text,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChipUser extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChipUser({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.grey600),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.grey700),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.grey200),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(color: AppColors.grey400),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
