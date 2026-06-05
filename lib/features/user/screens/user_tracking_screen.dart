// lib/features/user/screens/user_tracking_screen.dart
// User melacak porter secara real-time (seperti Gojek)
// Fix: (1) fallback kalau GPS porter null, (2) pulse animation marker porter

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

final _supabase = Supabase.instance.client;

class UserTrackingScreen extends StatefulWidget {
  final String orderId;
  final String porterId;
  final double latJemput;
  final double lngJemput;
  final double latTujuan;
  final double lngTujuan;
  final String lokasiJemput;
  final String lokasiTujuan;

  const UserTrackingScreen({
    super.key,
    required this.orderId,
    required this.porterId,
    required this.latJemput,
    required this.lngJemput,
    required this.latTujuan,
    required this.lngTujuan,
    required this.lokasiJemput,
    required this.lokasiTujuan,
  });

  @override
  State<UserTrackingScreen> createState() => _UserTrackingScreenState();
}

class _UserTrackingScreenState extends State<UserTrackingScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  LatLng? _porterLatLng;
  String _orderStatus = '';
  String _porterNama = '-';
  String _porterPhone = '-';
  bool _isLoading = true;

  // Pulse animation untuk marker porter
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Polling timer — fallback kalau realtime tidak jalan
  Timer? _pollingTimer;

  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadInitialData();
    _subscribeRealtimePorter();

    // Polling tiap 8 detik sebagai fallback realtime
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollPorterLocation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final porterData = await _supabase
          .from('porters')
          .select('nama, no_hp, latitude, longitude')
          .eq('id', widget.porterId)
          .single();

      final orderData = await _supabase
          .from('orders')
          .select('status')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          _porterNama = porterData['nama'] as String? ?? '-';
          _porterPhone = porterData['no_hp'] as String? ?? '-';
          _orderStatus = orderData['status'] as String? ?? '';

          final lat = (porterData['latitude'] as num?)?.toDouble();
          final lng = (porterData['longitude'] as num?)?.toDouble();

          if (lat != null && lng != null) {
            _porterLatLng = LatLng(lat, lng);
          } else {
            // FIX: GPS porter belum ada → gunakan lokasi jemput sebagai estimasi awal
            // Marker akan update otomatis begitu porter mulai jalan
            _porterLatLng = LatLng(widget.latJemput, widget.lngJemput);
          }
          _isLoading = false;
        });

        // Gerakkan kamera ke posisi porter
        if (_porterLatLng != null) {
          _mapController.move(_porterLatLng!, 15.5);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Polling manual sebagai fallback kalau realtime Supabase lambat/putus
  Future<void> _pollPorterLocation() async {
    if (!mounted) return;
    try {
      final porterData = await _supabase
          .from('porters')
          .select('latitude, longitude')
          .eq('id', widget.porterId)
          .single();

      final lat = (porterData['latitude'] as num?)?.toDouble();
      final lng = (porterData['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null && mounted) {
        final newPos = LatLng(lat, lng);
        // Hanya update kalau posisi benar-benar berubah
        if (_porterLatLng == null ||
            (_porterLatLng!.latitude - lat).abs() > 0.00001 ||
            (_porterLatLng!.longitude - lng).abs() > 0.00001) {
          setState(() => _porterLatLng = newPos);
          _mapController.move(newPos, 15.5);
        }
      }

      // Update status order juga
      final orderData = await _supabase
          .from('orders')
          .select('status')
          .eq('id', widget.orderId)
          .single();
      final newStatus = orderData['status'] as String?;
      if (newStatus != null && newStatus != _orderStatus && mounted) {
        setState(() => _orderStatus = newStatus);
      }
    } catch (_) {}
  }

  void _subscribeRealtimePorter() {
    _channel = _supabase
        .channel('porter-tracking-${widget.porterId}-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'porters',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.porterId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final lat = (newData['latitude'] as num?)?.toDouble();
            final lng = (newData['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null && mounted) {
              final newPos = LatLng(lat, lng);
              setState(() => _porterLatLng = newPos);
              _mapController.move(newPos, 15.5);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus != null && mounted) {
              setState(() => _orderStatus = newStatus);
              // Kalau order selesai → stop polling
              if (newStatus == 'selesai') {
                _pollingTimer?.cancel();
              }
            }
          },
        )
        .subscribe();
  }

  Color _statusColor(String s) => switch (s) {
        'diterima' => AppColors.statusDiterima,
        'menuju_lokasi' => AppColors.statusMenujuLokasi,
        'dalam_perjalanan' => AppColors.statusDalamPerjalanan,
        'sampai_tujuan' => AppColors.statusSampaiTujuan,
        'selesai' => AppColors.statusSelesai,
        _ => AppColors.statusMenunggu,
      };

  String _statusLabel(String s) => switch (s) {
        'diterima' => '✅ Porter menerima ordermu',
        'menuju_lokasi' => '🚶 Porter sedang menuju lokasimu',
        'dalam_perjalanan' => '🚚 Barang sedang dalam perjalanan',
        'sampai_tujuan' => '📍 Barang sudah sampai tujuan',
        'selesai' => '🎉 Order selesai!',
        _ => '🕐 Mencari porter...',
      };

  // Tombol "Pusatkan Peta" — tap untuk kembali lihat posisi porter
  void _centerOnPorter() {
    if (_porterLatLng != null) {
      _mapController.move(_porterLatLng!, 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lokasiJemput = LatLng(widget.latJemput, widget.lngJemput);
    final lokasiTujuan = LatLng(widget.latTujuan, widget.lngTujuan);
    final statusColor = _statusColor(_orderStatus);
    final isSelesai = _orderStatus == 'selesai';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lacak Porter'),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          // Tombol pusatkan peta ke posisi porter
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Pusatkan ke porter',
            onPressed: _centerOnPorter,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Status Bar ──────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  color: statusColor.withOpacity(0.12),
                  child: Row(
                    children: [
                      // Dot animasi kalau order masih aktif
                      if (!isSelesai)
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _statusLabel(_orderStatus),
                          style: AppTextStyles.labelLg.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── PETA TRACKING ────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _porterLatLng ?? lokasiJemput,
                          initialZoom: 15.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.go_dah',
                          ),

                          // Garis rute putus-putus: jemput → tujuan
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [lokasiJemput, lokasiTujuan],
                                strokeWidth: 3,
                                color: Colors.grey.shade300,
                                isDotted: true,
                              ),
                              // Garis solid: posisi porter → tujuan
                              if (_porterLatLng != null)
                                Polyline(
                                  points: [_porterLatLng!, lokasiTujuan],
                                  strokeWidth: 4,
                                  color: const Color(0xFF1E3C72),
                                ),
                            ],
                          ),

                          MarkerLayer(
                            markers: [
                              // Marker lokasi jemput (hijau)
                              Marker(
                                point: lokasiJemput,
                                width: 44,
                                height: 44,
                                child: const Icon(
                                  Icons.radio_button_checked_rounded,
                                  color: AppColors.success,
                                  size: 36,
                                ),
                              ),
                              // Marker tujuan (merah)
                              Marker(
                                point: lokasiTujuan,
                                width: 44,
                                height: 44,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.error,
                                  size: 36,
                                ),
                              ),
                              // Marker porter dengan pulse animation
                              if (_porterLatLng != null)
                                Marker(
                                  point: _porterLatLng!,
                                  width: 60,
                                  height: 60,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (_, child) => Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Lingkaran pulse di luar
                                        if (!isSelesai)
                                          Container(
                                            width: 60 * _pulseAnim.value,
                                            height: 60 * _pulseAnim.value,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3C72)
                                                  .withOpacity(
                                                      0.25 * (1 - (_pulseAnim.value - 0.6) / 0.4)),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        // Ikon porter
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3C72),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF1E3C72)
                                                    .withOpacity(0.4),
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
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Label jemput & tujuan di atas peta
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _MapLabel(
                            icon: Icons.radio_button_on_rounded,
                            color: AppColors.success,
                            text: 'Jemput'),
                      ),
                      Positioned(
                        top: 10,
                        left: 90,
                        child: _MapLabel(
                            icon: Icons.location_on_rounded,
                            color: AppColors.error,
                            text: 'Tujuan'),
                      ),
                    ],
                  ),
                ),

                // ── Info Panel Porter ────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primary100,
                            child: Text(
                              _porterNama.isNotEmpty
                                  ? _porterNama[0].toUpperCase()
                                  : 'P',
                              style: AppTextStyles.h3
                                  .copyWith(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Porter Kamu',
                                    style: AppTextStyles.caption),
                                Text(_porterNama,
                                    style: AppTextStyles.h4),
                                Text(_porterPhone,
                                    style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.grey500)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Hubungi'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _RouteRow(
                          label: 'Jemput', text: widget.lokasiJemput),
                      const SizedBox(height: 6),
                      _RouteRow(
                          label: 'Tujuan',
                          text: widget.lokasiTujuan,
                          isDestination: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MapLabel(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String label;
  final String text;
  final bool isDestination;

  const _RouteRow({
    required this.label,
    required this.text,
    this.isDestination = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isDestination
              ? Icons.location_on_rounded
              : Icons.radio_button_on_rounded,
          color: isDestination ? AppColors.error : AppColors.success,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                text,
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.grey800),
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