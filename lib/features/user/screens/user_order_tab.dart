import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class UserOrderTab extends StatefulWidget {
  const UserOrderTab({super.key});

  @override
  State<UserOrderTab> createState() => _UserOrderTabState();
}

class _UserOrderTabState extends State<UserOrderTab> {
  final _formKey = GlobalKey<FormState>();
  final _jemputCtrl = TextEditingController();
  final _tujuanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  String _jenisBrg = 'Koper / Tas Besar';
  String _jenisLayanan = 'instant';
  double _estimasiBerat = 5;
  bool _loading = false;
  bool _showEstimasi = false;
  double _estimasiBiaya = 0;

  List<String> _kategoriList = [];
  List<Map<String, dynamic>> _tarifList = [];

  final List<String> _defaultKategori = [
    'Koper / Tas Besar',
    'Kardus / Dus',
    'Elektronik',
    'Furnitur Kecil',
    'Barang Campuran',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _jemputCtrl.dispose();
    _tujuanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final kategori = await _supabase.from('kategori_barang').select('nama');
      final tarif = await _supabase
          .from('tarif')
          .select()
          .eq('is_aktif', true);

      setState(() {
        _kategoriList = (kategori as List).map((e) => e['nama'] as String).toList();
        _tarifList = List<Map<String, dynamic>>.from(tarif);
      });
    } catch (_) {
      setState(() => _kategoriList = _defaultKategori);
    }
  }

  IconData _getKategoriIcon(String name) {
    switch (name) {
      case 'Koper / Tas Besar':
        return Icons.backpack_rounded;
      case 'Kardus / Dus':
        return Icons.inventory_2_rounded;
      case 'Elektronik':
        return Icons.devices_rounded;
      case 'Furnitur Kecil':
        return Icons.chair_rounded;
      case 'Barang Campuran':
        return Icons.layers_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  void _hitungEstimasi() {
    final tarif = _tarifList.firstWhere(
      (t) {
        final jenis = t['jenis_layanan'] as String? ?? 'semua';
        return jenis == _jenisLayanan || jenis == 'semua';
      },
      orElse: () => {'harga_dasar': 5000, 'harga_per_km': 2000, 'harga_per_kg': 500},
    );

    final hargaDasar = (tarif['harga_dasar'] as num? ?? 5000).toDouble();
    final hargaPerKg = (tarif['harga_per_kg'] as num? ?? 500).toDouble();
    final hargaPerKm = (tarif['harga_per_km'] as num? ?? 2000).toDouble();
    const estimasiKm = 2.0;

    setState(() {
      _estimasiBiaya = hargaDasar + (estimasiKm * hargaPerKm) + (_estimasiBerat * hargaPerKg);
      _showEstimasi = true;
    });
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;

      final tarif = _tarifList.isNotEmpty
          ? _tarifList.firstWhere(
              (t) {
                final jenis = t['jenis_layanan'] as String? ?? 'semua';
                return jenis == _jenisLayanan || jenis == 'semua';
              },
              orElse: () => _tarifList.first,
            )
          : null;

      final hargaDasar = tarif != null
          ? (tarif['harga_dasar'] as num? ?? 5000).toDouble()
          : 5000.0;
      final hargaPerKg = tarif != null
          ? (tarif['harga_per_kg'] as num? ?? 500).toDouble()
          : 500.0;
      final hargaPerKm = tarif != null
          ? (tarif['harga_per_km'] as num? ?? 2000).toDouble()
          : 2000.0;
      const estimasiKm = 2.0;
      final totalBiaya = hargaDasar + (estimasiKm * hargaPerKm) + (_estimasiBerat * hargaPerKg);

      await _supabase.from('orders').insert({
        'user_id': user.id,
        'lokasi_jemput': _jemputCtrl.text.trim(),
        'lokasi_tujuan': _tujuanCtrl.text.trim(),
        'lat_jemput': 0.0,
        'lng_jemput': 0.0,
        'lat_tujuan': 0.0,
        'lng_tujuan': 0.0,
        'jenis_barang': _jenisBrg,
        'estimasi_berat': _estimasiBerat,
        'jenis_layanan': _jenisLayanan,
        'total_biaya': totalBiaya,
        if (_catatanCtrl.text.trim().isNotEmpty) 'catatan': _catatanCtrl.text.trim(),
        if (tarif != null) 'tarif_id': tarif['id'],
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
        _showEstimasi = false;
      });
      _jemputCtrl.clear();
      _tujuanCtrl.clear();
      _catatanCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order berhasil dibuat! Menunggu porter...'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat order: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 140,
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
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_shipping_rounded,
                                  color: AppColors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Go-Dah',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Halo, ${user?.nama ?? 'Mahasiswa'}! 👋',
                          style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Mau angkut barang ke mana hari ini?',
                          style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Form Pesan
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Lokasi Card (Visual Map Route style)
                      Container(
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
                              '📍 Alur Pengiriman',
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Stack(
                              children: [
                                // Vertical connecting line
                                Positioned(
                                  left: 17,
                                  top: 30,
                                  bottom: 30,
                                  child: Container(
                                    width: 2,
                                    color: AppColors.grey200,
                                  ),
                                ),
                                Column(
                                  children: [
                                    // Jemput
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 14.0),
                                          child: Icon(
                                            Icons.radio_button_checked_rounded,
                                            color: AppColors.success,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _jemputCtrl,
                                            validator: Validators.required,
                                            style: AppTextStyles.bodyMd,
                                            decoration: const InputDecoration(
                                              labelText: 'Lokasi Penjemputan',
                                              hintText: 'Kos, Jl. Kalimantan No. 5',
                                              floatingLabelBehavior: FloatingLabelBehavior.always,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Tujuan
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 14.0),
                                          child: Icon(
                                            Icons.location_on_rounded,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _tujuanCtrl,
                                            validator: Validators.required,
                                            style: AppTextStyles.bodyMd,
                                            decoration: const InputDecoration(
                                              labelText: 'Lokasi Tujuan',
                                              hintText: 'Gedung C, Universitas Jember',
                                              floatingLabelBehavior: FloatingLabelBehavior.always,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Detail Barang Card
                      Container(
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
                              '📦 Detail Barang',
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Kategori (3-column Grid)
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
                              children: (_kategoriList.isNotEmpty ? _kategoriList : _defaultKategori)
                                  .map((k) => _KategoriCard(
                                        label: k,
                                        icon: _getKategoriIcon(k),
                                        selected: _jenisBrg == k,
                                        onTap: () => setState(() => _jenisBrg = k),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),

                            // Estimasi Berat
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
                                // Minus Button
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                                // Plus Button
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
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.primary100,
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withOpacity(0.1),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _estimasiBerat,
                                min: 1,
                                max: 50,
                                divisions: 49,
                                onChanged: (v) => setState(() {
                                  _estimasiBerat = v;
                                  _showEstimasi = false;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Layanan Card
                      Container(
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
                              '⚡ Jenis Layanan',
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
                      ),
                      const SizedBox(height: 16),

                      // Catatan Card
                      Container(
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
                              '📝 Catatan (Opsional)',
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
                      ),
                      const SizedBox(height: 24),

                      // Estimasi Biaya Card
                      if (_showEstimasi) ...[
                        _EstimasiBiayaCard(biaya: _estimasiBiaya),
                        const SizedBox(height: 18),
                      ],

                      // Tombol Action
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
                            side: const BorderSide(color: Color(0xFF1E3C72), width: 1.5),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _buatOrder,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.local_shipping_rounded, size: 20),
                          label: Text(
                            _loading ? 'Memproses...' : 'Pesan Sekarang',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3C72),
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
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Baru: Card Kategori Modern dengan Icon ────────────────────────────────
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
        color: selected ? const Color(0xFF1E3C72).withOpacity(0.06) : AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF1E3C72) : AppColors.grey200,
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
                color: selected ? const Color(0xFF1E3C72) : AppColors.grey600,
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
                    color: selected ? const Color(0xFF1E3C72) : AppColors.grey700,
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
          color: selected ? const Color(0xFF1E3C72).withOpacity(0.06) : AppColors.grey50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1E3C72) : AppColors.grey200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E3C72).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF1E3C72) : AppColors.grey500,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.labelLg.copyWith(
                color: selected ? const Color(0xFF1E3C72) : AppColors.grey800,
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

class _EstimasiBiayaCard extends StatelessWidget {
  final double biaya;

  const _EstimasiBiayaCard({required this.biaya});

  @override
  Widget build(BuildContext context) {
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
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.2),
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
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimasi Biaya Jasa',
                  style: AppTextStyles.labelMd.copyWith(color: AppColors.white.withOpacity(0.8)),
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
                  '* Jarak estimasi 2 km, berat ${_getKeteranganBerat()}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.white.withOpacity(0.7), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getKeteranganBerat() {
    return 'disesuaikan';
  }
}
