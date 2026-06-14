import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/widgets/brand_video_logo.dart';
import '../../../state/providers/auth_provider.dart';
import 'user_payment_screen.dart';

final _supabase = Supabase.instance.client;

class UserOrderTab extends StatefulWidget {
  const UserOrderTab({super.key});

  @override
  State<UserOrderTab> createState() => _UserOrderTabState();
}

class _UserOrderTabState extends State<UserOrderTab> {
  final _tujuanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _mapController = MapController();

  LatLng? _lokasiJemput;
  LatLng? _lokasiTujuan;
  String _alamatJemput = '';
  bool _loadingGPS = false;
  bool _loadingSubmit = false;
  bool _mapSelectingTujuan = false;

  String _jenisBrg = 'Koper / Tas Besar';
  String _jenisLayanan = 'instant';
  double _estimasiBerat = 5;
  double _estimasiBiaya = 0;
  double _jarakMeter = 0;
  bool _showEstimasi = false;

  List<Map<String, dynamic>> _tarifList = [];
  Timer? _autoRefreshTimer;
  bool _refreshingTarif = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(),
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tujuanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_refreshingTarif) return;
    _refreshingTarif = true;

    try {
      final tarif = await _supabase.from('tarif').select().eq('is_aktif', true);
      if (mounted) {
        setState(() => _tarifList = List<Map<String, dynamic>>.from(tarif));
      }
    } catch (_) {
    } finally {
      _refreshingTarif = false;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingGPS = true);
    try {
      final position = await MapService.instance.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _lokasiJemput = LatLng(position.latitude, position.longitude);
          _alamatJemput =
              'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
        });
        _mapController.move(_lokasiJemput!, 16.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal ambil lokasi GPS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGPS = false);
    }
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_mapSelectingTujuan) {
      setState(() {
        _lokasiTujuan = latlng;
        _tujuanCtrl.text =
            'Lat: ${latlng.latitude.toStringAsFixed(5)}, Lng: ${latlng.longitude.toStringAsFixed(5)}';
        _mapSelectingTujuan = false;
        _showEstimasi = false;
      });
    }
  }

  void _hitungEstimasi() {
    if (_lokasiJemput == null || _lokasiTujuan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tentukan lokasi jemput dan tujuan terlebih dahulu'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final jarakMeter = MapService.instance.calculateDistance(
      startLat: _lokasiJemput!.latitude,
      startLng: _lokasiJemput!.longitude,
      endLat: _lokasiTujuan!.latitude,
      endLng: _lokasiTujuan!.longitude,
    );

    final tarif = _tarifList.isNotEmpty
        ? _tarifList.firstWhere(
            (t) {
              final jenis = t['jenis_layanan'] as String? ?? 'semua';
              return jenis == _jenisLayanan || jenis == 'semua';
            },
            orElse: () => {
              'harga_dasar': 5000,
              'harga_per_km': 2000,
              'harga_per_kg': 500,
            },
          )
        : {'harga_dasar': 5000, 'harga_per_km': 2000, 'harga_per_kg': 500};

    final biaya = MapService.instance.calculateCostByDistance(
      distanceMeters: jarakMeter,
      hargaDasar: (tarif['harga_dasar'] as num? ?? 5000).toDouble(),
      hargaPerKm: (tarif['harga_per_km'] as num? ?? 2000).toDouble(),
      hargaPerKg: (tarif['harga_per_kg'] as num? ?? 500).toDouble(),
      beratKg: _estimasiBerat,
    );

    setState(() {
      _jarakMeter = jarakMeter;
      _estimasiBiaya = biaya;
      _showEstimasi = true;
    });
  }

  Future<void> _buatOrder() async {
    if (_lokasiJemput == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktifkan GPS untuk menentukan lokasi jemput'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_lokasiTujuan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lokasi tujuan di peta'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _loadingSubmit = true);

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user == null) return;

      final tarif = _tarifList.isNotEmpty
          ? _tarifList.firstWhere((t) {
              final jenis = t['jenis_layanan'] as String? ?? 'semua';
              return jenis == _jenisLayanan || jenis == 'semua';
            }, orElse: () => _tarifList.first)
          : null;

      final totalBiaya = _estimasiBiaya > 0 ? _estimasiBiaya : 15000.0;

      final lokasiJemputStr = _alamatJemput.isNotEmpty
          ? _alamatJemput
          : 'Lokasi GPS (${_lokasiJemput!.latitude.toStringAsFixed(4)}, ${_lokasiJemput!.longitude.toStringAsFixed(4)})';

      final lokasiTujuanStr = _tujuanCtrl.text.trim().isNotEmpty
          ? _tujuanCtrl.text.trim()
          : 'Tujuan (${_lokasiTujuan!.latitude.toStringAsFixed(4)}, ${_lokasiTujuan!.longitude.toStringAsFixed(4)})';

      final insertRes = await _supabase
          .from('orders')
          .insert({
            'user_id': user.id,
            'lokasi_jemput': lokasiJemputStr,
            'lokasi_tujuan': lokasiTujuanStr,
            'lat_jemput': _lokasiJemput!.latitude,
            'lng_jemput': _lokasiJemput!.longitude,
            'lat_tujuan': _lokasiTujuan!.latitude,
            'lng_tujuan': _lokasiTujuan!.longitude,
            'jenis_barang': _jenisBrg,
            'estimasi_berat': _estimasiBerat,
            'jenis_layanan': _jenisLayanan,
            'total_biaya': totalBiaya,
            if (_catatanCtrl.text.trim().isNotEmpty)
              'catatan': _catatanCtrl.text.trim(),
            if (tarif != null) 'tarif_id': tarif['id'],
          })
          .select('id')
          .single();

      if (!mounted) return;
      setState(() => _loadingSubmit = false);

      final orderId = insertRes['id'] as String;

      final paymentSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UserPaymentScreen(
            orderId: orderId,
            totalBiaya: totalBiaya,
            lokasiJemput: lokasiJemputStr,
            lokasiTujuan: lokasiTujuanStr,
            jenisBrg: _jenisBrg,
            customerName: user.nama,
            customerEmail: user.email,
          ),
        ),
      );

      if (paymentSuccess == true && mounted) {
        await _kirimNotifOrderBaruKePorterOnline(
          orderId: orderId,
          lokasiJemput: lokasiJemputStr,
          lokasiTujuan: lokasiTujuanStr,
          jenisBrg: _jenisBrg,
        );

        if (!mounted) return;

        setState(() {
          _lokasiTujuan = null;
          _tujuanCtrl.clear();
          _catatanCtrl.clear();
          _showEstimasi = false;
          _estimasiBiaya = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order berhasil dibuat! Porter sedang dicari...'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSubmit = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat order: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _kirimNotifOrderBaruKePorterOnline({
    required String orderId,
    required String lokasiJemput,
    required String lokasiTujuan,
    required String jenisBrg,
  }) async {
    try {
      final porters = await _supabase
          .from('porters')
          .select('id')
          .eq('status', 'aktif')
          .eq('is_aktif', true)
          .eq('status_verifikasi', 'disetujui')
          .not('fcm_token', 'is', null)
          .limit(20);

      for (final porter in List<Map<String, dynamic>>.from(porters)) {
        final porterId = porter['id'] as String?;
        if (porterId == null) continue;

        await FcmService.instance.sendNewOrderNotifToPorter(
          targetPorterId: porterId,
          orderId: orderId,
          lokasiJemput: lokasiJemput,
          lokasiTujuan: lokasiTujuan,
          jenisBrg: jenisBrg,
        );
      }
    } catch (e) {
      debugPrint('Gagal kirim notif order baru ke porter: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const BrandVideoLogo(
                    asset: 'assets/branding/order_logo.mp4',
                    width: 34,
                    height: 34,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Pesan GoDah',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  _buildDetailBarangCard(),
                  const SizedBox(height: 16),
                  _buildLayananCard(),
                  const SizedBox(height: 16),
                  _buildCatatanCard(),
                  const SizedBox(height: 20),

                  if (_showEstimasi) ...[
                    _EstimasiCard(
                      biaya: _estimasiBiaya,
                      jarakMeter: _jarakMeter,
                      berat: _estimasiBerat,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (!_showEstimasi)
                    OutlinedButton.icon(
                      onPressed: _hitungEstimasi,
                      icon: const Icon(Icons.calculate_rounded, size: 20),
                      label: const Text('Hitung Estimasi Biaya'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _loadingSubmit ? null : _buatOrder,
                      icon: _loadingSubmit
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.payment_rounded, size: 20),
                      label: Text(
                        _loadingSubmit
                            ? 'Menyiapkan...'
                            : 'Lanjut ke Pembayaran',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Pilih Lokasi',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: _loadingGPS
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primary,
                        ),
                  tooltip: 'Refresh GPS',
                  onPressed: _loadingGPS ? null : _getCurrentLocation,
                ),
              ],
            ),
          ),
          ClipRRect(
            child: SizedBox(
              height: 300,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _lokasiJemput ?? const LatLng(-7.9797, 113.6175),
                  initialZoom: 15.0,
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.go_dah',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_lokasiJemput != null)
                        Marker(
                          point: _lokasiJemput!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.radio_button_checked_rounded,
                            color: AppColors.success,
                            size: 36,
                          ),
                        ),
                      if (_lokasiTujuan != null)
                        Marker(
                          point: _lokasiTujuan!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.error,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                  if (_lokasiJemput != null && _lokasiTujuan != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_lokasiJemput!, _lokasiTujuan!],
                          strokeWidth: 3.5,
                          color: AppColors.primary,
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
              children: [
                _LokasiRow(
                  icon: Icons.radio_button_checked_rounded,
                  color: AppColors.success,
                  label: 'Lokasi Jemput (GPS)',
                  text: _loadingGPS
                      ? 'Mengambil lokasi GPS...'
                      : _lokasiJemput != null
                      ? _alamatJemput.isNotEmpty
                            ? _alamatJemput
                            : '${_lokasiJemput!.latitude.toStringAsFixed(5)}, ${_lokasiJemput!.longitude.toStringAsFixed(5)}'
                      : 'Ketuk ikon GPS di atas untuk deteksi lokasi',
                  isLoading: _loadingGPS,
                ),
                const SizedBox(height: 10),
                if (_lokasiTujuan == null)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _mapSelectingTujuan = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ketuk peta untuk pilih lokasi tujuan'),
                          duration: Duration(seconds: 3),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: Icon(
                      _mapSelectingTujuan
                          ? Icons.touch_app_rounded
                          : Icons.add_location_alt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _mapSelectingTujuan
                          ? 'Ketuk peta untuk pilih tujuan...'
                          : 'Pilih Lokasi Tujuan di Peta',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: _mapSelectingTujuan
                          ? AppColors.warning
                          : AppColors.primary,
                      side: BorderSide(
                        color: _mapSelectingTujuan
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                  )
                else
                  _LokasiRow(
                    icon: Icons.location_on_rounded,
                    color: AppColors.error,
                    label: 'Lokasi Tujuan',
                    text: _tujuanCtrl.text.isNotEmpty
                        ? _tujuanCtrl.text
                        : '${_lokasiTujuan!.latitude.toStringAsFixed(5)}, ${_lokasiTujuan!.longitude.toStringAsFixed(5)}',
                    onEdit: () {
                      setState(() {
                        _lokasiTujuan = null;
                        _tujuanCtrl.clear();
                        _showEstimasi = false;
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBarangCard() {
    final kategoriList = [
      ('Koper / Tas Besar', Icons.backpack_rounded),
      ('Kardus / Dus', Icons.inventory_2_rounded),
      ('Elektronik', Icons.devices_rounded),
      ('Furnitur Kecil', Icons.chair_rounded),
      ('Barang Campuran', Icons.layers_rounded),
      ('Lainnya', Icons.more_horiz_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Barang',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori Barang',
            style: AppTextStyles.labelLg.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: kategoriList
                .map(
                  (k) => _KategoriCard(
                    label: k.$1,
                    icon: k.$2,
                    selected: _jenisBrg == k.$1,
                    onTap: () => setState(() => _jenisBrg = k.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Estimasi Berat',
                style: AppTextStyles.labelLg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.grey700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                onPressed: _estimasiBerat > 1
                    ? () => setState(() {
                        _estimasiBerat--;
                        _showEstimasi = false;
                      })
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_estimasiBerat.toStringAsFixed(0)} kg',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                onPressed: _estimasiBerat < 50
                    ? () => setState(() {
                        _estimasiBerat++;
                        _showEstimasi = false;
                      })
                    : null,
              ),
            ],
          ),
          Slider(
            value: _estimasiBerat,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary100,
            onChanged: (v) => setState(() {
              _estimasiBerat = v;
              _showEstimasi = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLayananCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jenis Layanan',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LayananCard(
                  icon: Icons.bolt_rounded,
                  title: 'Instan',
                  subtitle: 'Porter segera jalan',
                  selected: _jenisLayanan == 'instant',
                  onTap: () => setState(() {
                    _jenisLayanan = 'instant';
                    _showEstimasi = false;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LayananCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Terjadwal',
                  subtitle: 'Atur jam kirim',
                  selected: _jenisLayanan == 'terjadwal',
                  onTap: () => setState(() {
                    _jenisLayanan = 'terjadwal';
                    _showEstimasi = false;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatatanCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan (Opsional)',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _catatanCtrl,
            maxLines: 2,
            style: AppTextStyles.bodyMd,
            decoration: const InputDecoration(
              hintText: 'Contoh: Tolong hati-hati, barang pecah belah',
            ),
          ),
        ],
      ),
    );
  }
}

class _LokasiRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;
  final bool isLoading;
  final VoidCallback? onEdit;

  const _LokasiRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
    this.isLoading = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSm.copyWith(color: AppColors.grey500),
              ),
              Text(
                text,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.grey400,
            ),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}

class _KategoriCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _KategoriCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withOpacity(0.06)
            : AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.grey200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.grey600,
                size: 24,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.grey700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayananCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LayananCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.grey50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.grey200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.grey500,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.labelLg.copyWith(
                color: selected ? AppColors.primary : AppColors.grey800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimasiCard extends StatelessWidget {
  final double biaya;
  final double jarakMeter;
  final double berat;

  const _EstimasiCard({
    required this.biaya,
    required this.jarakMeter,
    required this.berat,
  });

  @override
  Widget build(BuildContext context) {
    final jarakKm = (jarakMeter / 1000).toStringAsFixed(2);
    final formatted = biaya.toInt().toString().split('').reversed.toList();
    final result = StringBuffer();
    for (int i = 0; i < formatted.length; i++) {
      if (i > 0 && i % 3 == 0) result.write('.');
      result.write(formatted[i]);
    }
    final rupiahStr = result.toString().split('').reversed.join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimasi Biaya Jasa',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp $rupiahStr',
                  style: AppTextStyles.priceLg.copyWith(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jarak GPS: $jarakKm km · Berat: ${berat.toStringAsFixed(0)} kg',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white.withOpacity(0.7),
                    fontSize: 10,
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
