// lib/features/user/screens/user_tracking_screen.dart
// UPDATED: Real-time GPS tracking porter kayak Gojek/GoSend
// - Auto-pan ke posisi porter tiap ada update
// - Progress bar status perjalanan
// - Tampil foto bukti penjemputan jika sudah diambil
// - Status info yang lebih informatif

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/call_service.dart';

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
  static const _callCenterPhone = '081234567890';

  LatLng? _porterLatLng;
  String _orderStatus = '';
  String _porterNama = '-';
  String _porterPhone = '-';
  bool _isLoading = true;
  String? _fotoBuktiJemput; // Foto barang saat porter tiba di jemput

  late final RealtimeChannel _channel;

  // Urutan status untuk progress indicator
  static const _statusSteps = [
    'diterima',
    'menuju_lokasi',
    'dalam_perjalanan',
    'sampai_tujuan',
    'selesai',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Data porter (nama, HP, posisi GPS terkini)
      final porterData = await _supabase
          .from('porters')
          .select('nama, no_hp, latitude, longitude')
          .eq('id', widget.porterId)
          .single();

      // Status order terkini
      final orderData = await _supabase
          .from('orders')
          .select('status')
          .eq('id', widget.orderId)
          .single();

      // Cek apakah ada foto bukti jemput
      final buktiJemput = await _supabase
          .from('bukti_pengiriman')
          .select('foto_url')
          .eq('order_id', widget.orderId)
          .eq('jenis_bukti', 'pickup')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _porterNama = porterData['nama'] as String? ?? '-';
          _porterPhone = porterData['no_hp'] as String? ?? '-';
          _orderStatus = orderData['status'] as String? ?? '';
          _fotoBuktiJemput = buktiJemput?['foto_url'] as String?;

          final lat = (porterData['latitude'] as num?)?.toDouble();
          final lng = (porterData['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null && lat != 0 && lng != 0) {
            _porterLatLng = LatLng(lat, lng);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Realtime: posisi porter + status order update otomatis ───────────────
  void _subscribeRealtime() {
    _channel = _supabase
        .channel('tracking-${widget.orderId}')
        // Update posisi GPS porter
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

            if (lat != null && lng != null && lat != 0 && lng != 0 && mounted) {
              setState(() => _porterLatLng = LatLng(lat, lng));
              // Auto-pan kamera ke posisi porter terbaru
              _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
            }
          },
        )
        // Update status order
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
              // Kalau ada foto baru (porter tiba di jemput), reload
              if (newStatus == 'dalam_perjalanan') {
                _loadFotoBuktiJemput();
              }
            }
          },
        )
        // Notif kalau ada foto bukti baru diupload porter
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bukti_pengiriman',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            final jenisBukti = payload.newRecord['jenis_bukti'] as String?;
            if (jenisBukti == 'pickup' && mounted) {
              _loadFotoBuktiJemput();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadFotoBuktiJemput() async {
    try {
      final bukti = await _supabase
          .from('bukti_pengiriman')
          .select('foto_url')
          .eq('order_id', widget.orderId)
          .eq('jenis_bukti', 'pickup')
          .maybeSingle();

      if (mounted && bukti != null) {
        setState(() => _fotoBuktiJemput = bukti['foto_url'] as String?);
      }
    } catch (_) {}
  }

  // ── Helper: warna dan label per status ───────────────────────────────────
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
    'dalam_perjalanan' => '🚚 Barangmu sedang dalam perjalanan',
    'sampai_tujuan' => '📍 Barangmu sudah sampai di tujuan!',
    'selesai' => '🎉 Order selesai!',
    _ => '🕐 Mencari porter...',
  };

  String _statusSubInfo(String s) => switch (s) {
    'diterima' => 'Porter sudah lihat rute ke lokasimu',
    'menuju_lokasi' => 'Lihat posisi porter di peta secara real-time',
    'dalam_perjalanan' => 'Porter sudah foto barangmu saat dijemput',
    'sampai_tujuan' => 'Silakan konfirmasi penerimaan barang',
    'selesai' => 'Jangan lupa beri rating untuk porter!',
    _ => '',
  };

  // Index step untuk progress bar
  int get _currentStep {
    final idx = _statusSteps.indexOf(_orderStatus);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final lokasiJemput = LatLng(widget.latJemput, widget.lngJemput);
    final lokasiTujuan = LatLng(widget.latTujuan, widget.lngTujuan);
    final color = _statusColor(_orderStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lacak Portermu'),
        backgroundColor: const Color(0xFF1E3C72),
        actions: [
          // Tombol center ke posisi porter
          if (_porterLatLng != null)
            IconButton(
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'Ke posisi porter',
              onPressed: () => _mapController.move(_porterLatLng!, 16.0),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // ── STATUS HEADER ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(_orderStatus),
                        style: AppTextStyles.labelLg.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_statusSubInfo(_orderStatus).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _statusSubInfo(_orderStatus),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Progress steps
                      _StatusProgressBar(
                        steps: const [
                          'Diterima',
                          'Menuju Jemput',
                          'Di Perjalanan',
                          'Sampai',
                          'Selesai',
                        ],
                        currentStep: _currentStep,
                        activeColor: color,
                      ),
                    ],
                  ),
                ),

                // ── PETA REAL-TIME ───────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: FlutterMap(
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

                      // Garis rute jemput → tujuan (abu-abu putus)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [lokasiJemput, lokasiTujuan],
                            strokeWidth: 3,
                            color: AppColors.grey300,
                            isDotted: true,
                          ),
                          // Garis porter → destinasi terkini (biru solid)
                          if (_porterLatLng != null)
                            Polyline(
                              points: [
                                _porterLatLng!,
                                // Arahkan ke tujuan relevan berdasarkan status
                                (_orderStatus == 'dalam_perjalanan' ||
                                        _orderStatus == 'sampai_tujuan')
                                    ? lokasiTujuan
                                    : lokasiJemput,
                              ],
                              strokeWidth: 4,
                              color: const Color(0xFF1E3C72),
                            ),
                        ],
                      ),

                      // Markers
                      MarkerLayer(
                        markers: [
                          // Lokasi jemput (hijau)
                          Marker(
                            point: lokasiJemput,
                            width: 44,
                            height: 44,
                            child: _MapPin(
                              icon: Icons.radio_button_checked_rounded,
                              color: AppColors.success,
                              label: 'Jemput',
                            ),
                          ),
                          // Tujuan (merah)
                          if (widget.latTujuan != 0)
                            Marker(
                              point: lokasiTujuan,
                              width: 44,
                              height: 60,
                              child: _MapPin(
                                icon: Icons.location_on_rounded,
                                color: AppColors.error,
                                label: 'Tujuan',
                              ),
                            ),
                          // Porter marker — bergerak real-time
                          if (_porterLatLng != null)
                            Marker(
                              point: _porterLatLng!,
                              width: 54,
                              height: 54,
                              child: _PorterMarker(color: color),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── INFO PANEL PORTER ─────────────────────────────────────
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Porter info row
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
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Portermu', style: AppTextStyles.caption),
                                Text(_porterNama, style: AppTextStyles.h4),
                                Text(
                                  _porterPhone,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.grey500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => CallService.callPhone(
                              context,
                              _porterPhone,
                              targetLabel: 'porter',
                            ),
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Hubungi'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rute ringkas
                      _RouteRow(label: 'Jemput', text: widget.lokasiJemput),
                      const SizedBox(height: 4),
                      _RouteRow(
                        label: 'Tujuan',
                        text: widget.lokasiTujuan,
                        isDestination: true,
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => CallService.callPhone(
                            context,
                            _callCenterPhone,
                            targetLabel: 'call center',
                          ),
                          icon: const Icon(
                            Icons.support_agent_rounded,
                            size: 16,
                          ),
                          label: const Text('Call Center Barang Hilang'),
                        ),
                      ),

                      // Foto barang saat dijemput (muncul ketika porter
                      // sudah tiba & ngambil foto)
                      if (_fotoBuktiJemput != null) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Foto Barang saat Dijemput',
                              style: AppTextStyles.labelLg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.black,
                              child: InteractiveViewer(
                                child: Image.network(
                                  _fotoBuktiJemput!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _fotoBuktiJemput!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
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
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR STATUS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusProgressBar extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final Color activeColor;

  const _StatusProgressBar({
    required this.steps,
    required this.currentStep,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        // Ganjil = connector line, genap = step dot
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone ? activeColor : AppColors.grey200,
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isDone = stepIdx <= currentStep;
        final isCurrent = stepIdx == currentStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 12 : 8,
              height: isCurrent ? 12 : 8,
              decoration: BoxDecoration(
                color: isDone ? activeColor : AppColors.grey200,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: activeColor, width: 2)
                    : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              steps[stepIdx],
              style: TextStyle(
                fontSize: 8,
                color: isDone ? activeColor : AppColors.grey400,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PorterMarker extends StatelessWidget {
  final Color color;
  const _PorterMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E3C72),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.5),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(
        Icons.directions_run_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _MapPin({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Icon(icon, color: color, size: 28),
      ],
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
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey800),
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
