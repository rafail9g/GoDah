// lib/features/user/screens/user_tracking_screen.dart
// Screen untuk user melacak porter secara real-time (seperti Gojek)
// Menggunakan OpenStreetMap + StreamBuilder untuk update posisi porter

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/map_service.dart';

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

class _UserTrackingScreenState extends State<UserTrackingScreen> {
  final _mapController = MapController();
  LatLng? _porterLatLng;       // Posisi porter real-time
  String _orderStatus = '';
  String _porterNama = '-';
  String _porterPhone = '-';
  bool _isLoading = true;

  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeRealtimePorter();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load data porter
      final porterData = await _supabase
          .from('porters')
          .select('nama, no_hp, latitude, longitude')
          .eq('id', widget.porterId)
          .single();

      // Load status order terkini
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
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Realtime subscription — update lokasi porter otomatis ──────
  // Seperti Gojek: porter bergerak → posisi update di peta user
  void _subscribeRealtimePorter() {
    _channel = _supabase
        .channel('porter-tracking-${widget.porterId}')
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
              setState(() => _porterLatLng = LatLng(lat, lng));
              // Auto-pan kamera ke lokasi porter
              _mapController.move(LatLng(lat, lng), 16.0);
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
        'menuju_lokasi' => '🚶 Porter menuju lokasimu',
        'dalam_perjalanan' => '🚚 Barang sedang dibawa',
        'sampai_tujuan' => '📍 Barang sudah sampai tujuan',
        'selesai' => '🎉 Order selesai!',
        _ => '🕐 Mencari porter...',
      };

  @override
  Widget build(BuildContext context) {
    final lokasiJemput = LatLng(widget.latJemput, widget.lngJemput);
    final lokasiTujuan = LatLng(widget.latTujuan, widget.lngTujuan);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lacak Ordermu'),
        backgroundColor: const Color(0xFF1E3C72),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Status Bar ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  color: _statusColor(_orderStatus).withOpacity(0.12),
                  child: Text(
                    _statusLabel(_orderStatus),
                    style: AppTextStyles.labelLg.copyWith(
                      color: _statusColor(_orderStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ── PETA TRACKING (flutter_map + OSM) ─────────────
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _porterLatLng ?? lokasiJemput,
                      initialZoom: 15.0,
                    ),
                    children: [
                      // Slide 6: TileLayer OSM
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.go_dah',
                      ),

                      // Garis rute: jemput → tujuan
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [lokasiJemput, lokasiTujuan],
                            strokeWidth: 3,
                            color: AppColors.grey300,
                            isDotted: true,
                          ),
                          // Garis porter → tujuan (jika ada)
                          if (_porterLatLng != null)
                            Polyline(
                              points: [_porterLatLng!, lokasiTujuan],
                              strokeWidth: 4,
                              color: const Color(0xFF1E3C72),
                            ),
                        ],
                      ),

                      // Slide 6: MarkerLayer — semua marker
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
                                size: 36),
                          ),
                          // Marker tujuan (merah)
                          Marker(
                            point: lokasiTujuan,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_on_rounded,
                                color: AppColors.error, size: 36),
                          ),
                          // Marker porter (biru animasi)
                          if (_porterLatLng != null)
                            Marker(
                              point: _porterLatLng!,
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3C72),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E3C72)
                                          .withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                    Icons.directions_run_rounded,
                                    color: Colors.white,
                                    size: 24),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Info Panel Porter ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppColors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary100,
                            child: Text(
                              _porterNama.isNotEmpty
                                  ? _porterNama[0].toUpperCase()
                                  : 'P',
                              style: AppTextStyles.h3.copyWith(
                                  color: AppColors.primary),
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
                      const SizedBox(height: 12),
                      // Rute
                      _RouteRow(
                          label: 'Jemput', text: widget.lokasiJemput),
                      const SizedBox(height: 4),
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
          isDestination ? Icons.location_on_rounded : Icons.radio_button_on_rounded,
          color: isDestination ? AppColors.error : AppColors.success,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(text,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
