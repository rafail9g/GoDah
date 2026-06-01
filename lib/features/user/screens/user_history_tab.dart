import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

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
            porters(nama, no_hp, foto_profil),
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
            porters(nama, no_hp, foto_profil),
            bukti_pengiriman(foto_url, keterangan),
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
          title: const Text('Beri Penilaian'),
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
                _ActiveOrderList(orders: _activeOrders, onBatal: _batalOrder),
                _CompletedOrderList(
                  orders: _completedOrders,
                  onKirimRating: _kirimRating,
                ),
              ],
            ),
    );
  }
}

// ── Active Order List ──────────────────────────────────────────────────────

class _ActiveOrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final void Function(String) onBatal;

  const _ActiveOrderList({required this.orders, required this.onBatal});

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
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onBatal;

  const _ActiveOrderCard({required this.order, required this.onBatal});

  Color _statusColor(String s) => switch (s) {
    'menunggu' => AppColors.statusMenunggu,
    'diterima' => AppColors.statusDiterima,
    'menuju_lokasi' => AppColors.statusMenujuLokasi,
    'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
    'sampai_tujuan' => AppColors.statusSampaiTujuan,
    _ => AppColors.grey400,
  };

  String _statusLabel(String s) => switch (s) {
    'menunggu' => '🕐 Menunggu Porter',
    'diterima' => '✅ Porter Menerima',
    'menuju_lokasi' => '🚶 Menuju Lokasi',
    'dalam_perjalanan' => '🚚 Dalam Perjalanan',
    'sampai_tujuan' => '📍 Sampai Tujuan',
    _ => s,
  };

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
            ),
            child: Text(
              _statusLabel(status),
              style: AppTextStyles.labelLg.copyWith(color: color),
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

                // Info row
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

                // Porter info
                if (porter != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary100,
                        child: Text(
                          (porter['nama'] as String? ?? 'P')[0].toUpperCase(),
                          style: AppTextStyles.labelLg.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Porter Kamu', style: AppTextStyles.caption),
                            Text(
                              porter['nama'] as String? ?? '-',
                              style: AppTextStyles.labelLg,
                            ),
                          ],
                        ),
                      ),
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
                ],

                // Tracking steps (last 3)
                if (tracking != null && tracking.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text('Riwayat Status', style: AppTextStyles.labelLg),
                  const SizedBox(height: 8),
                  ...tracking
                      .cast<Map<String, dynamic>>()
                      .take(3)
                      .map((t) => _TrackingItem(tracking: t)),
                ],

                // Batalkan (hanya kalau masih menunggu)
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.primary200),
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

// ── Completed Order List ──────────────────────────────────────────────────

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
        final porterId = porter?['id'] as String? ?? '';
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
    final bukti = order['bukti_pengiriman'];
    final Map<String, dynamic>? buktiData = bukti is List && bukti.isNotEmpty
        ? bukti[0] as Map<String, dynamic>
        : null;
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

                // Detail chips
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

                // Porter
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

                // Bukti
                if (buktiData != null) ...[
                  const Divider(height: 20),
                  Text('Bukti Pengiriman', style: AppTextStyles.labelLg),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    child: Image.network(
                      buktiData['foto_url'] as String,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, err, _s) => Container(
                        height: 80,
                        color: AppColors.grey100,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.grey400,
                          ),
                        ),
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
                          ratingData['ulasan'] as String? ?? 'Tidak ada ulasan',
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
                    label: const Text('Beri Penilaian'),
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

// ── Shared Widgets ────────────────────────────────────────────────────────

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
