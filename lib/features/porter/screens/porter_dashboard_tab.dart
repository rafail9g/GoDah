// lib/features/porter/screens/porter_dashboard_tab.dart
// UPDATED: Porter dapat lihat peta OSM + update GPS posisi + foto barang & bukti kirim
// Berdasarkan materi: GPS stream update + flutter_map display

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';
import '../../../core/services/map_service.dart';

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

  // ── GPS Stream state ──────────────────────────────────────────
  // Slide 12 best practice: stream dengan interval & distance filter
  Stream<Position>? _locationStream;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _load();
    _startGPSStream();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Slide 9: Start GPS stream untuk update posisi porter ──────
  void _startGPSStream() {
    _locationStream = MapService.instance.getLocationStream(
      intervalMs: 5000,     // Update tiap 5 detik
      distanceFilter: 15,   // Min 15 meter baru update (hemat baterai)
    );

    _locationStream?.listen((position) async {
      if (!mounted) return;
      setState(() => _currentPosition = position);

      // Update koordinat porter di database (untuk tracking user)
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      if (porter != null && _isOnline) {
        await _supabase.from('porters').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }).eq('id', porter.id);
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      if (porter == null) return;

      final porterData = await _supabase
          .from('porters')
          .select('is_aktif')
          .eq('id', porter.id)
          .single();
      _isOnline = porterData['is_aktif'] as bool? ?? false;

      final available = await _supabase
          .from('orders')
          .select('*, users(nama, no_hp)')
          .eq('status', 'menunggu')
          .isFilter('porter_id', null)
          .order('waktu_pesan', ascending: false)
          .limit(10);
      _availableOrders = List<Map<String, dynamic>>.from(available);

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
          .update({'is_aktif': newStatus}).eq('id', porter.id);
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

    // Ambil foto barang sebelum angkat (WAJIB)
    final foto = await _ambilFoto(title: 'Foto Barang Sebelum Diangkut');
    if (foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto barang wajib sebelum menerima order'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      // Upload foto barang ke storage
      final fotoUrl = await _uploadFoto(foto, 'barang-order/$orderId-sebelum.jpg');

      await _supabase.from('orders').update({
        'porter_id': porter.id,
        'status': 'diterima',
      }).eq('id', orderId);

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'diterima',
        'catatan': 'Order diterima porter. Foto barang sudah diambil.',
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order berhasil diterima! Foto barang tersimpan.'),
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

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final Map<String, String> nextStatus = {
      'diterima': 'menuju_lokasi',
      'menuju_lokasi': 'dalam_perjalanan',
      'dalam_perjalanan': 'sampai_tujuan',
      'sampai_tujuan': 'selesai',
    };

    final next = nextStatus[currentStatus];
    if (next == null) return;

    // Jika status selesai → wajib foto bukti pengiriman
    if (next == 'selesai') {
      await _selesaikanDenganFoto(orderId);
      return;
    }

    try {
      await _supabase.from('orders').update({'status': next}).eq('id', orderId);

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': next,
        'catatan': _statusLabel(next),
        // Simpan koordinat GPS porter saat update status
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status: ${_statusLabel(next)}'),
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

  // ── Selesaikan order dengan foto bukti pengiriman ─────────────
  Future<void> _selesaikanDenganFoto(String orderId) async {
    final foto = await _ambilFoto(title: 'Foto Bukti Barang Sudah Sampai');
    if (foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto bukti pengiriman wajib diisi'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final keteranganCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(foto, height: 150, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keteranganCtrl,
              decoration: const InputDecoration(
                hintText: 'Keterangan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Konfirmasi Selesai')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      final fotoUrl = await _uploadFoto(foto, 'bukti-pengiriman/$orderId.jpg');

      // Update order status
      await _supabase.from('orders').update({
        'status': 'selesai',
        'waktu_selesai': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Simpan bukti pengiriman
      await _supabase.from('bukti_pengiriman').upsert({
        'order_id': orderId,
        'porter_id': porter?.id,
        'foto_url': fotoUrl,
        'keterangan': keteranganCtrl.text.trim().isEmpty
            ? 'Barang sudah sampai di tujuan'
            : keteranganCtrl.text.trim(),
      });

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'selesai',
        'catatan': 'Order selesai. Barang sudah sampai.',
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Order selesai! Foto bukti tersimpan.'),
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

  // ── Ambil foto menggunakan kamera ─────────────────────────────
  Future<File?> _ambilFoto({String title = 'Ambil Foto'}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // ── Upload foto ke Supabase Storage ──────────────────────────
  Future<String> _uploadFoto(File foto, String path) async {
    await _supabase.storage.from('dokumen-porter').upload(path, foto,
        fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('dokumen-porter').getPublicUrl(path);
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
          SliverAppBar(
            expandedHeight: 200,
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
                                    fontWeight: FontWeight.bold),
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
                                        fontWeight: FontWeight.bold),
                                  ),
                                  // Tampilkan koordinat GPS porter real-time
                                  if (_currentPosition != null)
                                    Text(
                                      '📍 ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.white.withOpacity(0.7)),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded,
                                  color: AppColors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
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
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatsRow(totalSelesai: porter?.totalSelesai ?? 0),
                  const SizedBox(height: 20),

                  if (porter?.statusVerifikasi != 'disetujui') ...[
                    _VerifBanner(
                      status: porter?.statusVerifikasi ?? 'menunggu',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Order Aktif dengan Map Preview
                  if (_myActiveOrders.isNotEmpty) ...[
                    _SectionHeader(
                        title: 'Order Aktif (${_myActiveOrders.length})'),
                    const SizedBox(height: 10),
                    ..._myActiveOrders.map((order) => _ActiveOrderCard(
                          order: order,
                          currentPosition: _currentPosition,
                          onUpdateStatus: () => _updateOrderStatus(
                            order['id'] as String,
                            order['status'] as String,
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  _SectionHeader(
                    title: _isOnline
                        ? 'Order Tersedia (${_availableOrders.length})'
                        : 'Order Tersedia',
                    subtitle: _isOnline
                        ? null
                        : 'Aktifkan mode online untuk melihat order',
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

// ── Widget: Order Aktif dengan Map Preview ───────────────────────────────
class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Position? currentPosition;
  final VoidCallback onUpdateStatus;

  const _ActiveOrderCard({
    required this.order,
    required this.currentPosition,
    required this.onUpdateStatus,
  });

  String _nextLabel(String s) => switch (s) {
        'diterima' => 'Menuju Lokasi Jemput',
        'menuju_lokasi' => 'Sudah di Lokasi Jemput',
        'dalam_perjalanan' => 'Sampai Tujuan',
        'sampai_tujuan' => '📸 Selesai + Foto Bukti',
        _ => '',
      };

  Color _statusColor(String s) => switch (s) {
        'diterima' => AppColors.statusDiterima,
        'menuju_lokasi' => AppColors.statusMenujuLokasi,
        'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
        'sampai_tujuan' => AppColors.statusSampaiTujuan,
        _ => AppColors.grey400,
      };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final color = _statusColor(status);
    final user = order['users'] as Map<String, dynamic>? ?? {};
    final latJemput = (order['lat_jemput'] as num?)?.toDouble() ?? 0;
    final lngJemput = (order['lng_jemput'] as num?)?.toDouble() ?? 0;
    final latTujuan = (order['lat_tujuan'] as num?)?.toDouble() ?? 0;
    final lngTujuan = (order['lng_tujuan'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          // ── Map mini untuk order aktif ──────────────────────
          if (latJemput != 0 && lngJemput != 0)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: currentPosition != null
                        ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
                        : LatLng(latJemput, lngJemput),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.go_dah',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(latJemput, lngJemput),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.radio_button_checked_rounded,
                              color: AppColors.success, size: 30),
                        ),
                        Marker(
                          point: LatLng(latTujuan, lngTujuan),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on_rounded,
                              color: AppColors.error, size: 30),
                        ),
                        if (currentPosition != null)
                          Marker(
                            point: LatLng(currentPosition!.latitude,
                                currentPosition!.longitude),
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3C72),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.directions_run_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: AppTextStyles.labelSm
                            .copyWith(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(user['nama'] as String? ?? 'User',
                        style: AppTextStyles.labelMd
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                _LokasiItem(
                    icon: Icons.radio_button_on_rounded,
                    color: AppColors.success,
                    label: 'Jemput',
                    text: order['lokasi_jemput'] as String? ?? '-'),
                const SizedBox(height: 6),
                _LokasiItem(
                    icon: Icons.location_on_rounded,
                    color: AppColors.error,
                    label: 'Tujuan',
                    text: order['lokasi_tujuan'] as String? ?? '-'),
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
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      child: Text(
                        _nextLabel(status),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reuse widget dari dashboard lama ────────────────────────────────────

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
                  ? [
                      BoxShadow(
                          color: const Color(0xFF38EF7D).withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2)
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnline ? 'ONLINE — Siap Terima Order' : 'OFFLINE — Sedang Istirahat',
              style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          if (loading)
            const SizedBox(
                width: 36,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white))
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
                        color: AppColors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
            gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)]),
        const SizedBox(width: 10),
        _StatCard(
            icon: Icons.star_rounded,
            label: 'Rating Anda',
            value: '5.0',
            gradientColors: const [Color(0xFFF2C94C), Color(0xFFF2994A)]),
        const SizedBox(width: 10),
        _StatCard(
            icon: Icons.local_shipping_rounded,
            label: 'Hari Ini',
            value: '0',
            gradientColors: const [Color(0xFF1E3C72), Color(0xFF2A5298)]),
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
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.h3
                    .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _VerifBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;

  const _VerifBanner({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'menunggu';
    final color = isPending ? AppColors.warning : AppColors.error;
    return GestureDetector(
      onTap: status != 'menunggu' ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isPending
                    ? 'Menunggu verifikasi admin (1×24 jam)'
                    : 'Verifikasi ditolak. Tap untuk upload ulang.',
                style:
                    AppTextStyles.bodyMd.copyWith(color: AppColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.h3.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.grey500)),
        ],
      ],
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccept;

  const _AvailableOrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final user = order['users'] as Map<String, dynamic>? ?? {};
    final biaya = (order['total_biaya'] as num? ?? 0).toInt();
    final layanan = order['jenis_layanan'] as String? ?? 'instant';
    final latJemput = (order['lat_jemput'] as num?)?.toDouble() ?? 0;
    final lngJemput = (order['lng_jemput'] as num?)?.toDouble() ?? 0;
    final latTujuan = (order['lat_tujuan'] as num?)?.toDouble() ?? 0;
    final lngTujuan = (order['lng_tujuan'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Mini map preview order
          if (latJemput != 0)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 140,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(latJemput, lngJemput),
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Read-only map
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.go_dah',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(latJemput, lngJemput),
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.radio_button_checked_rounded,
                              color: AppColors.success, size: 28),
                        ),
                        if (latTujuan != 0)
                          Marker(
                            point: LatLng(latTujuan, lngTujuan),
                            width: 32,
                            height: 32,
                            child: const Icon(Icons.location_on_rounded,
                                color: AppColors.error, size: 28),
                          ),
                      ],
                    ),
                    if (latTujuan != 0)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(latJemput, lngJemput),
                              LatLng(latTujuan, lngTujuan),
                            ],
                            strokeWidth: 3,
                            color: const Color(0xFF1E3C72),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: layanan == 'instant'
                            ? const Color(0xFFF2994A).withOpacity(0.12)
                            : const Color(0xFF2D9CDB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        layanan == 'instant' ? '⚡ Instan' : '📅 Terjadwal',
                        style: AppTextStyles.labelSm.copyWith(
                          color: layanan == 'instant'
                              ? const Color(0xFFF2994A)
                              : const Color(0xFF2D9CDB),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Rp ${_rupiahFormat(biaya)}',
                      style: AppTextStyles.priceMd.copyWith(
                          color: const Color(0xFF1E3C72),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LokasiItem(
                    icon: Icons.radio_button_checked_rounded,
                    color: AppColors.success,
                    label: 'Jemput',
                    text: order['lokasi_jemput'] as String? ?? '-'),
                const SizedBox(height: 4),
                _LokasiItem(
                    icon: Icons.location_on_rounded,
                    color: AppColors.error,
                    label: 'Tujuan',
                    text: order['lokasi_tujuan'] as String? ?? '-'),
                const Divider(height: 20),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        text: order['jenis_barang'] as String? ?? '-'),
                    const SizedBox(width: 10),
                    _InfoChip(
                        icon: Icons.person_outline_rounded,
                        text: user['nama'] as String? ?? 'User'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Terima + Foto Barang',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
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

class _LokasiItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const _LokasiItem(
      {required this.icon,
      required this.color,
      required this.label,
      required this.text});

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
              Text(text,
                  style:
                      AppTextStyles.bodyMd.copyWith(color: AppColors.grey700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
              child: Text(text,
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.grey700),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text('Kamu sedang Offline',
              style: AppTextStyles.h4.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 4),
          Text('Aktifkan mode online untuk menerima pesanan.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
              textAlign: TextAlign.center),
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
          borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text('Belum Ada Order',
              style: AppTextStyles.h4.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 4),
          Text('Tunggu sebentar ya!',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
