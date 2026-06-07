// lib/features/porter/screens/porter_dashboard_tab.dart
// CHANGES:
// 1. Accept order: ATOMIC (race-condition safe) - porter pertama yang klik menang
// 2. Setelah accept: porter langsung lihat map ke lokasi jemput
// 3. Available orders: TANPA map preview (map muncul hanya setelah terima)
// 4. Foto WAJIB saat tiba di lokasi jemput (bukan cuma saat selesai)
// 5. GPS stream update real-time (user bisa lacak porter)

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
import '../../../core/services/call_service.dart';
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
  int _totalSelesai = 0;
  int _selesaiHariIni = 0;
  double _avgRating = 0;

  // Track order mana yang sedang dalam proses accept (prevent double tap)
  String? _acceptingOrderId;

  // GPS Stream state
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

  void _startGPSStream() {
    _locationStream = MapService.instance.getLocationStream(
      intervalMs: 5000,
      distanceFilter: 10,
    );

    _locationStream?.listen((position) async {
      if (!mounted) return;
      setState(() => _currentPosition = position);

      // Update koordinat porter ke DB agar user bisa tracking real-time
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      if (porter != null && _isOnline) {
        await _supabase
            .from('porters')
            .update({
              'latitude': position.latitude,
              'longitude': position.longitude,
            })
            .eq('id', porter.id);
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

      // Hanya tampilkan order yang BELUM ada porter (porter_id IS NULL)
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
          .inFilter('status', [
            'diterima',
            'menuju_lokasi',
            'dalam_perjalanan',
            'sampai_tujuan',
          ])
          .order('waktu_pesan', ascending: false);
      _myActiveOrders = List<Map<String, dynamic>>.from(myActive);

      final completed = await _supabase
          .from('orders')
          .select('id, waktu_selesai')
          .eq('porter_id', porter.id)
          .eq('status', 'selesai');
      final completedList = List<Map<String, dynamic>>.from(completed);
      final today = DateTime.now();
      _totalSelesai = completedList.length;
      _selesaiHariIni = completedList.where((order) {
        final raw = order['waktu_selesai'] as String?;
        if (raw == null) return false;
        final dt = DateTime.tryParse(raw)?.toLocal();
        return dt != null &&
            dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day;
      }).length;

      final ratings = await _supabase
          .from('ratings')
          .select('nilai')
          .eq('porter_id', porter.id);
      final ratingList = List<Map<String, dynamic>>.from(ratings);
      if (ratingList.isEmpty) {
        _avgRating = 0;
      } else {
        final total = ratingList.fold<num>(
          0,
          (sum, item) => sum + (item['nilai'] as num? ?? 0),
        );
        _avgRating = total / ratingList.length;
      }
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
          content: Text(
            'Akun belum terverifikasi. Selesaikan verifikasi dahulu.',
          ),
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
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  // ── ACCEPT ORDER: ATOMIC — Porter pertama yang klik, dia yang dapat ──────
  // Tidak perlu foto dulu. Foto wajib saat tiba di lokasi jemput.
  Future<void> _acceptOrder(String orderId) async {
    final auth = context.read<AuthProvider>();
    final porter = auth.currentPorter;
    if (porter == null) return;

    setState(() => _acceptingOrderId = orderId);

    try {
      // STEP 1: Update DENGAN kondisi — hanya jika status masih 'menunggu'
      // DAN porter_id masih null. Ini mencegah race condition.
      await _supabase
          .from('orders')
          .update({'porter_id': porter.id, 'status': 'diterima'})
          .eq('id', orderId)
          .eq('status', 'menunggu')
          .isFilter('porter_id', null);

      // STEP 2: Verifikasi apakah kita yang berhasil mendapatkan order
      final verify = await _supabase
          .from('orders')
          .select('porter_id, status')
          .eq('id', orderId)
          .single();

      if (verify['porter_id'] != porter.id) {
        // Porter lain lebih cepat klik!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚡ Order sudah diambil porter lain!\nCoba cari order lain.',
              ),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
            ),
          );
        }
        _load(); // Refresh list
        return;
      }

      // STEP 3: Kita berhasil! Simpan tracking awal
      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'diterima',
        'catatan': 'Order diterima porter. Segera menuju lokasi penjemputan.',
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Order berhasil diterima!\nSegera menuju lokasi penjemputan.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal terima order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingOrderId = null);
    }
  }

  // ── UPDATE STATUS dengan routing foto yang benar ──────────────────────
  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final Map<String, String> nextStatus = {
      'diterima': 'menuju_lokasi',
      'menuju_lokasi': 'dalam_perjalanan', // ← WAJIB foto barang di jemput
      'dalam_perjalanan': 'sampai_tujuan',
      'sampai_tujuan': 'selesai', // ← WAJIB foto bukti pengiriman
    };

    final next = nextStatus[currentStatus];
    if (next == null) return;

    // Foto WAJIB saat tiba di lokasi jemput (sebelum angkat barang)
    if (next == 'dalam_perjalanan') {
      await _fotoTibaLokasi(orderId);
      return;
    }

    // Foto WAJIB saat selesai mengantarkan barang
    if (next == 'selesai') {
      await _selesaikanDenganFoto(orderId);
      return;
    }

    // Status lain: langsung update tanpa foto
    try {
      await _supabase.from('orders').update({'status': next}).eq('id', orderId);

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': next,
        'catatan': _statusLabel(next),
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status diperbarui: ${_statusLabel(next)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── FOTO WAJIB: Tiba di lokasi jemput → foto barang sebelum diangkut ──
  Future<void> _fotoTibaLokasi(String orderId) async {
    final foto = await _ambilFoto(title: 'Foto Barang di Lokasi Penjemputan');
    if (foto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '📸 Foto barang di lokasi jemput WAJIB sebelum mengangkut!',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Konfirmasi
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Tiba di Lokasi Jemput'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                foto,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pastikan foto barang jelas sebelum diangkut.\n'
              'Foto ini sebagai bukti kondisi barang saat dijemput.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Angkut Barang Sekarang'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final fotoUrl = await _uploadFoto(
        foto,
        'foto-jemput/$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await _supabase
          .from('orders')
          .update({'status': 'dalam_perjalanan'})
          .eq('id', orderId);

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'dalam_perjalanan',
        'catatan':
            'Porter sudah tiba di lokasi jemput & mengangkut barang. '
            'Dalam perjalanan menuju tujuan.',
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      // Simpan foto jemput di tabel bukti_pengiriman dengan flag 'jemput'
      final auth = context.read<AuthProvider>();
      await _supabase.from('bukti_pengiriman').upsert({
        'order_id': orderId,
        'porter_id': auth.currentPorter?.id,
        'foto_url': fotoUrl,
        'keterangan': 'Foto barang saat penjemputan',
        'jenis_bukti': 'pickup',
      }, onConflict: 'order_id, jenis_bukti');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Foto tersimpan! Barang siap diantar ke tujuan.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── FOTO WAJIB: Bukti pengiriman selesai ─────────────────────────────
  Future<void> _selesaikanDenganFoto(String orderId) async {
    final foto = await _ambilFoto(title: 'Foto Bukti Barang Sudah Sampai');
    if (foto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '📸 Foto bukti pengiriman WAJIB untuk menyelesaikan order!',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final keteranganCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Order Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                foto,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Selesaikan Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      final porter = auth.currentPorter;
      final fotoUrl = await _uploadFoto(
        foto,
        'bukti-pengiriman/$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await _supabase
          .from('orders')
          .update({
            'status': 'selesai',
            'waktu_selesai': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      await _supabase.from('bukti_pengiriman').upsert({
        'order_id': orderId,
        'porter_id': porter?.id,
        'foto_url': fotoUrl,
        'keterangan': keteranganCtrl.text.trim().isEmpty
            ? 'Barang sudah sampai di tujuan'
            : keteranganCtrl.text.trim(),
        'jenis_bukti': 'delivery',
      }, onConflict: 'order_id, jenis_bukti');

      await _supabase.from('order_tracking').insert({
        'order_id': orderId,
        'status_perjalanan': 'selesai',
        'catatan': 'Order selesai. Barang sudah sampai di tujuan.',
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Order selesai! Terima kasih sudah bekerja keras.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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

  Future<String> _uploadFoto(File foto, String path) async {
    await _supabase.storage
        .from('dokumen-porter')
        .upload(path, foto, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('dokumen-porter').getPublicUrl(path);
  }

  String _statusLabel(String s) => switch (s) {
    'diterima' => 'Order Diterima — Menuju Lokasi Jemput',
    'menuju_lokasi' => 'Menuju Lokasi Jemput',
    'dalam_perjalanan' => 'Barang Sudah Diambil — Dalam Perjalanan',
    'sampai_tujuan' => 'Sampai di Tujuan',
    'selesai' => 'Order Selesai',
    _ => s,
  };

  Color statusColor(String s) => switch (s) {
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                                  if (_currentPosition != null)
                                    Text(
                                      '📍 GPS aktif — posisi terkirim ke user',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.white.withOpacity(0.7),
                                      ),
                                    ),
                                ],
                              ),
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
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatsRow(
                    totalSelesai: _totalSelesai,
                    avgRating: _avgRating,
                    selesaiHariIni: _selesaiHariIni,
                  ),
                  const SizedBox(height: 20),

                  if (porter?.statusVerifikasi != 'disetujui') ...[
                    _VerifBanner(
                      status: porter?.statusVerifikasi ?? 'menunggu',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── ORDER AKTIF: Tampilkan map real-time GPS tracking ──
                  if (_myActiveOrders.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Order Aktifmu (${_myActiveOrders.length})',
                      subtitle:
                          'Posisi GPS-mu terkirim ke user secara real-time',
                    ),
                    const SizedBox(height: 10),
                    ..._myActiveOrders.map(
                      (order) => _ActiveOrderCard(
                        order: order,
                        currentPosition: _currentPosition,
                        onUpdateStatus: () => _updateOrderStatus(
                          order['id'] as String,
                          order['status'] as String,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── AVAILABLE ORDERS: Tanpa map, cukup detail order ──
                  _SectionHeader(
                    title: _isOnline
                        ? 'Order Tersedia (${_availableOrders.length})'
                        : 'Order Tersedia',
                    subtitle: _isOnline
                        ? 'Klik "Terima" — yang duluan klik, yang dapat!'
                        : 'Aktifkan mode online untuk melihat order',
                  ),
                  const SizedBox(height: 10),
                  if (!_isOnline)
                    _OfflinePlaceholder()
                  else if (_availableOrders.isEmpty)
                    _EmptyOrdersPlaceholder()
                  else
                    ..._availableOrders.map(
                      (order) => _AvailableOrderCard(
                        order: order,
                        isAccepting: _acceptingOrderId == order['id'],
                        onAccept: _acceptingOrderId == null
                            ? () => _acceptOrder(order['id'] as String)
                            : null,
                      ),
                    ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE ORDER CARD — dengan map real-time GPS porter
// ─────────────────────────────────────────────────────────────────────────────

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
    'diterima' => '🚶 Mulai Menuju Lokasi Jemput',
    'menuju_lokasi' => '📸 Tiba di Jemput — Foto Barang',
    'dalam_perjalanan' => '📍 Konfirmasi Sampai Tujuan',
    'sampai_tujuan' => '📸 Selesai + Foto Bukti Kirim',
    _ => '',
  };

  String _statusInfo(String s) => switch (s) {
    'diterima' => 'Berangkat ke lokasi penjemputan sekarang',
    'menuju_lokasi' => 'Sudah di lokasi jemput? Foto barang dulu!',
    'dalam_perjalanan' => 'Barang sudah diambil, antar ke tujuan',
    'sampai_tujuan' => 'Sudah sampai? Ambil foto bukti pengiriman',
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
            color: color.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── MAP real-time: Porter lihat posisinya sendiri + rute ──────
          if (latJemput != 0 && lngJemput != 0)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: currentPosition != null
                        ? LatLng(
                            currentPosition!.latitude,
                            currentPosition!.longitude,
                          )
                        : LatLng(latJemput, lngJemput),
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.go_dah',
                    ),
                    // Garis rute
                    if (latTujuan != 0)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(latJemput, lngJemput),
                              LatLng(latTujuan, lngTujuan),
                            ],
                            strokeWidth: 3,
                            color: color.withOpacity(0.6),
                            isDotted: true,
                          ),
                          if (currentPosition != null)
                            Polyline(
                              points: [
                                LatLng(
                                  currentPosition!.latitude,
                                  currentPosition!.longitude,
                                ),
                                // Garis dari posisi porter ke tujuan relevan
                                status == 'dalam_perjalanan' ||
                                        status == 'sampai_tujuan'
                                    ? LatLng(latTujuan, lngTujuan)
                                    : LatLng(latJemput, lngJemput),
                              ],
                              strokeWidth: 3.5,
                              color: const Color(0xFF1E3C72),
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Lokasi jemput (hijau)
                        Marker(
                          point: LatLng(latJemput, lngJemput),
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.radio_button_checked_rounded,
                            color: AppColors.success,
                            size: 30,
                          ),
                        ),
                        // Lokasi tujuan (merah)
                        if (latTujuan != 0)
                          Marker(
                            point: LatLng(latTujuan, lngTujuan),
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.error,
                              size: 30,
                            ),
                          ),
                        // Posisi porter saat ini (biru bergerak)
                        if (currentPosition != null)
                          Marker(
                            point: LatLng(
                              currentPosition!.latitude,
                              currentPosition!.longitude,
                            ),
                            width: 48,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3C72),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1E3C72,
                                    ).withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_run_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
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
                // Status badge + nama user
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: AppTextStyles.labelSm.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: AppColors.grey500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user['nama'] as String? ?? 'User',
                          style: AppTextStyles.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Info hint untuk porter
                if (_statusInfo(status).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _statusInfo(status),
                            style: AppTextStyles.bodySm.copyWith(
                              color: color,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _LokasiItem(
                  icon: Icons.radio_button_on_rounded,
                  color: AppColors.success,
                  label: 'Lokasi Jemput',
                  text: order['lokasi_jemput'] as String? ?? '-',
                ),
                const SizedBox(height: 6),
                _LokasiItem(
                  icon: Icons.location_on_rounded,
                  color: AppColors.error,
                  label: 'Tujuan',
                  text: order['lokasi_tujuan'] as String? ?? '-',
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () => CallService.callPhone(
                    context,
                    user['no_hp'] as String?,
                    targetLabel: 'user',
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Hubungi User'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: const Color(0xFF1E3C72),
                    side: const BorderSide(color: Color(0xFF1E3C72)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (_nextLabel(status).isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onUpdateStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _nextLabel(status),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// AVAILABLE ORDER CARD — TANPA map, hanya info order. Map muncul setelah terima.
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isAccepting;
  final VoidCallback? onAccept;

  const _AvailableOrderCard({
    required this.order,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final user = order['users'] as Map<String, dynamic>? ?? {};
    final biaya = (order['total_biaya'] as num? ?? 0).toInt();
    final layanan = order['jenis_layanan'] as String? ?? 'instant';
    final jenisBrg = order['jenis_barang'] as String? ?? '-';
    final berat = order['estimasi_berat'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            // Header: layanan + harga
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rp ${_rupiahFormat(biaya)}',
                  style: AppTextStyles.priceMd.copyWith(
                    color: const Color(0xFF1E3C72),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Rute: jemput → tujuan
            _LokasiItem(
              icon: Icons.radio_button_checked_rounded,
              color: AppColors.success,
              label: 'Lokasi Jemput',
              text: order['lokasi_jemput'] as String? ?? '-',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 7.5),
              child: Container(width: 2, height: 16, color: AppColors.grey200),
            ),
            _LokasiItem(
              icon: Icons.location_on_rounded,
              color: AppColors.error,
              label: 'Tujuan',
              text: order['lokasi_tujuan'] as String? ?? '-',
            ),
            const Divider(height: 20),

            // Chips: jenis barang, berat, user
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(icon: Icons.inventory_2_outlined, text: jenisBrg),
                if (berat != null)
                  _InfoChip(icon: Icons.scale_rounded, text: '$berat kg'),
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  text: user['nama'] as String? ?? 'User',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Info: peta tersedia setelah terima
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Peta & rute detail tersedia setelah menerima order',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tombol terima — PERTAMA yang klik yang menang!
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAccepting ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  disabledBackgroundColor: AppColors.grey300,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: isAccepting ? 0 : 3,
                ),
                child: isAccepting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Memproses...',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Terima Pesanan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnline
                  ? 'ONLINE — Siap Terima Order'
                  : 'OFFLINE — Sedang Istirahat',
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
                  alignment: isOnline
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
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

class _StatsRow extends StatelessWidget {
  final int totalSelesai;
  final double avgRating;
  final int selesaiHariIni;

  const _StatsRow({
    required this.totalSelesai,
    required this.avgRating,
    required this.selesaiHariIni,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.check_circle_rounded,
          label: 'Order Selesai',
          value: '$totalSelesai',
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.star_rounded,
          label: 'Rating',
          value: avgRating == 0 ? '-' : avgRating.toStringAsFixed(1),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.local_shipping_rounded,
          label: 'Hari Ini',
          value: '$selesaiHariIni',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3C72),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3C72).withOpacity(0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
              isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isPending
                    ? 'Menunggu verifikasi admin (1×24 jam)'
                    : 'Verifikasi ditolak. Tap untuk upload ulang.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey700),
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
    );
  }
}

class _LokasiItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const _LokasiItem({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.grey500),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.grey700),
          ),
        ],
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
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.grey300,
          ),
          const SizedBox(height: 12),
          Text(
            'Kamu sedang Offline',
            style: AppTextStyles.h4.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktifkan mode online untuk menerima pesanan.',
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
          const Icon(Icons.inbox_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Order Masuk',
            style: AppTextStyles.h4.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 4),
          Text(
            'Tunggu sebentar ya, order akan muncul otomatis!',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
