import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class PorterDashboardTab extends StatefulWidget {
  const PorterDashboardTab({super.key});

  @override
  State<PorterDashboardTab> createState() => _PorterDashboardTabState();
}

class _PorterDashboardTabState extends State<PorterDashboardTab> {
  bool _isOnline = false;
  bool _togglingOnline = false;
  List<Map<String, dynamic>> _availableOrders = [];
  List<Map<String, dynamic>> _myActiveOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      if (porter == null) return;

      // Load current porter status
      final porterData = await _supabase
          .from('porters')
          .select('is_aktif')
          .eq('id', porter.id)
          .single();
      _isOnline = porterData['is_aktif'] as bool? ?? false;

      // Load available orders (menunggu, no porter yet)
      final available = await _supabase
          .from('orders')
          .select('*, users(nama, no_hp)')
          .eq('status', 'menunggu')
          .isFilter('porter_id', null)
          .order('waktu_pesan', ascending: false)
          .limit(10);
      _availableOrders = List<Map<String, dynamic>>.from(available);

      // Load my active orders
      final myActive = await _supabase
          .from('orders')
          .select('*, users(nama, no_hp)')
          .eq('porter_id', porter.id)
          .inFilter('status', ['diterima', 'menuju_lokasi', 'dalam_perjalanan', 'sampai_tujuan'])
          .order('waktu_pesan', ascending: false);
      _myActiveOrders = List<Map<String, dynamic>>.from(myActive);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline() async {
    final auth = context.read<AuthProvider>();
    final porter = auth.currentPorter;
    if (porter == null) return;

    // Check verification first
    if (porter.statusVerifikasi != 'disetujui') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun belum terverifikasi. Selesaikan verifikasi dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _togglingOnline = true);
    try {
      final newStatus = !_isOnline;
      await _supabase
          .from('porters')
          .update({'is_aktif': newStatus})
          .eq('id', porter.id);
      setState(() => _isOnline = newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    final auth = context.read<AuthProvider>();
    final porter = auth.currentPorter;
    if (porter == null) return;

    try {
      await _supabase.from('orders').update({
        'porter_id': porter.id,
        'status': 'diterima',
      }).eq('id', orderId);

      // Insert tracking
      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'diterima',
        'catatan': 'Order diterima oleh porter',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order berhasil diterima!'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menerima order: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final Map<String, String> nextStatus = {
      'diterima': 'menuju_lokasi',
      'menuju_lokasi': 'dalam_perjalanan',
      'dalam_perjalanan': 'sampai_tujuan',
      'sampai_tujuan': 'selesai',
    };

    final next = nextStatus[currentStatus];
    if (next == null) return;

    try {
      await _supabase.from('orders').update({
        'status': next,
        if (next == 'selesai') 'waktu_selesai': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': next,
        'catatan': _statusLabel(next),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status diperbarui: ${_statusLabel(next)}'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  String _statusLabel(String s) => switch (s) {
    'menuju_lokasi' => 'Menuju Lokasi Jemput',
    'dalam_perjalanan' => 'Dalam Perjalanan ke Tujuan',
    'sampai_tujuan' => 'Sampai di Tujuan',
    'selesai' => 'Order Selesai',
    _ => s,
  };

  Color _statusColor(String s) => switch (s) {
    'menunggu' => AppColors.statusMenunggu,
    'diterima' => AppColors.statusDiterima,
    'menuju_lokasi' => AppColors.statusMenujuLokasi,
    'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
    'sampai_tujuan' => AppColors.statusSampaiTujuan,
    'selesai' => AppColors.statusSelesai,
    _ => AppColors.grey400,
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final porter = auth.currentPorter;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            backgroundColor: const Color(0xFF1E3C72),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.white.withOpacity(0.2),
                              child: Text(
                                porter?.nama.isNotEmpty == true
                                    ? porter!.nama[0].toUpperCase()
                                    : 'P',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo, ${porter?.nama ?? 'Porter'}! 👋',
                                    style: AppTextStyles.h4.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    porter?.statusVerifikasi == 'disetujui'
                                        ? '✅ Akun Terverifikasi'
                                        : porter?.statusVerifikasi == 'menunggu'
                                            ? '⏳ Menunggu Verifikasi'
                                            : '❌ Belum Terverifikasi',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Online Toggle
                        _OnlineToggleCard(
                          isOnline: _isOnline,
                          loading: _togglingOnline,
                          onToggle: _toggleOnline,
                          isVerified: porter?.statusVerifikasi == 'disetujui',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Row
                  _StatsRow(totalSelesai: porter?.totalSelesai ?? 0),
                  const SizedBox(height: 20),

                  // Verifikasi Banner (jika belum)
                  if (porter?.statusVerifikasi != 'disetujui') ...[
                    _VerifBanner(
                      status: porter?.statusVerifikasi ?? 'menunggu',
                      onTap: () => context.push('/porter/verification'),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // My Active Orders
                  if (_myActiveOrders.isNotEmpty) ...[
                    _SectionHeader(title: 'Order Aktif Saya (${_myActiveOrders.length})'),
                    const SizedBox(height: 10),
                    ..._myActiveOrders.map((order) => _ActiveOrderCard(
                          order: order,
                          onUpdateStatus: () => _updateOrderStatus(
                            order['id'] as String,
                            order['status'] as String,
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Available Orders
                  _SectionHeader(
                    title: _isOnline
                        ? 'Order Tersedia (${_availableOrders.length})'
                        : 'Order Tersedia',
                    subtitle: _isOnline ? null : 'Aktifkan mode online untuk melihat order',
                  ),
                  const SizedBox(height: 10),
                  if (!_isOnline)
                    _OfflinePlaceholder()
                  else if (_availableOrders.isEmpty)
                    _EmptyOrdersPlaceholder()
                  else
                    ..._availableOrders.map((order) => _AvailableOrderCard(
                          order: order,
                          onAccept: () => _acceptOrder(order['id'] as String),
                        )),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Online Toggle Card ──────────────────────────────────────────────────────

class _OnlineToggleCard extends StatelessWidget {
  final bool isOnline;
  final bool loading;
  final VoidCallback onToggle;
  final bool isVerified;

  const _OnlineToggleCard({
    required this.isOnline,
    required this.loading,
    required this.onToggle,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF38EF7D) : AppColors.grey400,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [BoxShadow(color: const Color(0xFF38EF7D).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnline ? 'Status: ONLINE (Siap Terima Kerja)' : 'Status: OFFLINE (Sedang Istirahat)',
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 36,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
          else
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 28,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF38EF7D) : AppColors.grey500,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalSelesai;
  const _StatsRow({required this.totalSelesai});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.check_circle_rounded,
          label: 'Order Selesai',
          value: '$totalSelesai',
          gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.star_rounded,
          label: 'Rating Anda',
          value: '5.0',
          gradientColors: const [Color(0xFFF2C94C), Color(0xFFF2994A)],
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.local_shipping_rounded,
          label: 'Hari Ini',
          value: '0',
          gradientColors: const [Color(0xFF1E3C72), Color(0xFF2A5298)],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verif Banner ──────────────────────────────────────────────────────────

class _VerifBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;

  const _VerifBanner({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'menunggu';
    final color = isPending ? AppColors.warning : AppColors.error;
    final icon = isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded;
    final title = isPending ? 'Menunggu Verifikasi' : 'Verifikasi Akun Ditolak';
    final sub = isPending
        ? 'Dokumenmu sedang ditinjau admin. Harap tunggu 1×24 jam.'
        : 'Mohon maaf dokumen ditolak. Tap di sini untuk upload ulang.';

    return GestureDetector(
      onTap: status != 'menunggu' ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600, height: 1.3),
                  ),
                ],
              ),
            ),
            if (status != 'menunggu')
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.grey500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Available Order Card ──────────────────────────────────────────────────

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccept;

  const _AvailableOrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final user = order['users'] as Map<String, dynamic>? ?? {};
    final biaya = (order['total_biaya'] as num? ?? 0).toStringAsFixed(0);
    final layanan = order['jenis_layanan'] as String? ?? 'instant';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: layanan == 'instant'
                        ? const Color(0xFFF2994A).withOpacity(0.12)
                        : const Color(0xFF2D9CDB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    layanan == 'instant' ? '⚡ Instan' : '📅 Terjadwal',
                    style: AppTextStyles.labelSm.copyWith(
                      color: layanan == 'instant' ? const Color(0xFFF2994A) : const Color(0xFF2D9CDB),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rp ${_formatRupiah(biaya)}',
                  style: AppTextStyles.priceMd.copyWith(
                    color: const Color(0xFF1E3C72),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Lokasi
            Stack(
              children: [
                Positioned(
                  left: 7,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 2,
                    color: AppColors.grey200,
                  ),
                ),
                Column(
                  children: [
                    _LocationRow(
                      icon: Icons.radio_button_checked_rounded,
                      color: AppColors.success,
                      label: 'Jemput',
                      address: order['lokasi_jemput'] as String? ?? '-',
                    ),
                    const SizedBox(height: 12),
                    _LocationRow(
                      icon: Icons.location_on_rounded,
                      color: AppColors.error,
                      label: 'Tujuan',
                      address: order['lokasi_tujuan'] as String? ?? '-',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Barang & pemesan
            Row(
              children: [
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  text: order['jenis_barang'] as String? ?? 'Tidak disebutkan',
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  text: user['nama'] as String? ?? 'User',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Terima Order',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRupiah(String s) {
    final n = int.tryParse(s) ?? 0;
    final str = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onUpdateStatus;

  const _ActiveOrderCard({required this.order, required this.onUpdateStatus});

  String _nextLabel(String s) => switch (s) {
    'diterima' => 'Menuju Lokasi Jemput',
    'menuju_lokasi' => 'Sudah di Lokasi Jemput',
    'dalam_perjalanan' => 'Sampai Tujuan',
    'sampai_tujuan' => 'Selesaikan Order',
    _ => '',
  };

  Color _statusColor(String s) => switch (s) {
    'diterima' => AppColors.statusDiterima,
    'menuju_lokasi' => AppColors.statusMenujuLokasi,
    'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
    'sampai_tujuan' => AppColors.statusSampaiTujuan,
    _ => AppColors.grey400,
  };

  String _statusLabelDisplay(String s) => switch (s) {
    'diterima' => 'Diterima',
    'menuju_lokasi' => 'Menuju Lokasi',
    'dalam_perjalanan' => 'Dalam Perjalanan',
    'sampai_tujuan' => 'Sampai Tujuan',
    _ => s,
  };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final color = _statusColor(status);
    final user = order['users'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabelDisplay(status),
                    style: AppTextStyles.labelSm.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  user['nama'] as String? ?? 'User',
                  style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Lokasi
            Stack(
              children: [
                Positioned(
                  left: 7,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 2,
                    color: AppColors.grey200,
                  ),
                ),
                Column(
                  children: [
                    _LocationRow(
                      icon: Icons.radio_button_checked_rounded,
                      color: AppColors.success,
                      label: 'Jemput',
                      address: order['lokasi_jemput'] as String? ?? '-',
                    ),
                    const SizedBox(height: 12),
                    _LocationRow(
                      icon: Icons.location_on_rounded,
                      color: AppColors.error,
                      label: 'Tujuan',
                      address: order['lokasi_tujuan'] as String? ?? '-',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_nextLabel(status).isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpdateStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    _nextLabel(status),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Offline & Empty Placeholders ──────────────────────────────────────────

class _OfflinePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text(
            'Kamu sedang Offline',
            style: AppTextStyles.h4.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktifkan mode online untuk mulai menerima pesanan dari mahasiswa.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyOrdersPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Order',
            style: AppTextStyles.h4.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada order yang tersedia saat ini. Tunggu sebentar ya!',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSm),
              Text(
                address,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.grey500),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.labelSm.copyWith(color: AppColors.grey700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
