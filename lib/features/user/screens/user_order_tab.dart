import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
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

  void _hitungEstimasi() {
    // Hitung estimasi biaya berdasarkan tarif
    final tarif = _tarifList.firstWhere(
      (t) {
        final jenis = t['jenis_layanan'] as String? ?? 'semua';
        return jenis == _jenisLayanan || jenis == 'semua';
      },
      orElse: () => {'harga_dasar': 5000, 'harga_per_km': 2000, 'harga_per_kg': 500},
    );

    final hargaDasar = (tarif['harga_dasar'] as num? ?? 5000).toDouble();
    final hargaPerKg = (tarif['harga_per_kg'] as num? ?? 500).toDouble();
    // Estimasi jarak 2km sebagai default (user belum input koordinat)
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

      // Cari tarif yang sesuai
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
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary700, AppColors.primary, AppColors.secondary500],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_rounded,
                                color: AppColors.white, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Go-Dah',
                              style: AppTextStyles.h2.copyWith(color: AppColors.white),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: AppColors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Halo, ${user?.nama ?? 'Mahasiswa'}! 👋',
                          style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.white.withOpacity(0.9)),
                        ),
                        Text(
                          'Mau angkut barang ke mana hari ini?',
                          style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.white.withOpacity(0.75)),
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
                      // Lokasi Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📍 Lokasi', style: AppTextStyles.h4),
                              const SizedBox(height: 12),

                              // Jemput
                              _LokasiField(
                                controller: _jemputCtrl,
                                label: 'Lokasi Jemput',
                                hint: 'Contoh: Kos Melati, Jl. Kalimantan No. 5',
                                icon: Icons.radio_button_on_rounded,
                                iconColor: AppColors.success,
                                validator: Validators.required,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 11),
                                child: Column(
                                  children: List.generate(
                                    3,
                                    (i) => Container(
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      width: 2,
                                      height: 4,
                                      color: AppColors.grey300,
                                    ),
                                  ),
                                ),
                              ),

                              // Tujuan
                              _LokasiField(
                                controller: _tujuanCtrl,
                                label: 'Lokasi Tujuan',
                                hint: 'Contoh: Gedung Kuliah C, Universitas Jember',
                                icon: Icons.location_on_rounded,
                                iconColor: AppColors.error,
                                validator: Validators.required,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Detail Barang Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📦 Detail Barang', style: AppTextStyles.h4),
                              const SizedBox(height: 14),

                              // Kategori
                              Text('Kategori Barang', style: AppTextStyles.labelLg),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_kategoriList.isNotEmpty ? _kategoriList : _defaultKategori)
                                    .map((k) => _KategoriChip(
                                          label: k,
                                          selected: _jenisBrg == k,
                                          onTap: () => setState(() => _jenisBrg = k),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),

                              // Estimasi Berat
                              Row(
                                children: [
                                  Text('Estimasi Berat', style: AppTextStyles.labelLg),
                                  const Spacer(),
                                  Text(
                                    '${_estimasiBerat.toStringAsFixed(0)} kg',
                                    style: AppTextStyles.h4.copyWith(color: AppColors.primary),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('1 kg', style: AppTextStyles.caption),
                                  Text('50 kg', style: AppTextStyles.caption),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Layanan Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⚡ Jenis Layanan', style: AppTextStyles.h4),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _LayananCard(
                                      icon: Icons.bolt_rounded,
                                      title: 'Instan',
                                      subtitle: 'Porter datang sekarang',
                                      selected: _jenisLayanan == 'instant',
                                      onTap: () => setState(() {
                                        _jenisLayanan = 'instant';
                                        _showEstimasi = false;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _LayananCard(
                                      icon: Icons.calendar_today_rounded,
                                      title: 'Terjadwal',
                                      subtitle: 'Atur waktu penjemputan',
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
                      ),
                      const SizedBox(height: 14),

                      // Catatan
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📝 Catatan (opsional)', style: AppTextStyles.h4),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _catatanCtrl,
                                maxLines: 3,
                                style: AppTextStyles.bodyMd,
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: Tolong hati-hati, ada barang pecah belah',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Estimasi Biaya
                      if (_showEstimasi)
                        _EstimasiBiayaCard(biaya: _estimasiBiaya),
                      if (_showEstimasi) const SizedBox(height: 12),

                      // Tombol
                      if (!_showEstimasi)
                        OutlinedButton.icon(
                          onPressed: _hitungEstimasi,
                          icon: const Icon(Icons.calculate_rounded),
                          label: const Text('Hitung Estimasi Biaya'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(AppDimens.buttonHeightMd),
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
                              : const Icon(Icons.local_shipping_rounded),
                          label: Text(_loading ? 'Memproses...' : 'Pesan Sekarang'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(AppDimens.buttonHeightMd),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _LokasiField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final String? Function(String?)? validator;

  const _LokasiField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            validator: validator,
            style: AppTextStyles.bodyMd,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: iconColor, width: 1.5),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KategoriChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KategoriChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.grey100,
          borderRadius: BorderRadius.circular(AppDimens.radiusRound),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.grey200,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMd.copyWith(
            color: selected ? AppColors.white : AppColors.grey700,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.grey50,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.grey200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.grey400,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTextStyles.labelLg.copyWith(
                color: selected ? AppColors.primary : AppColors.grey700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary500],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimasi Biaya',
                  style: AppTextStyles.labelLg.copyWith(color: AppColors.white.withOpacity(0.85)),
                ),
                Text(
                  'Rp $rupiahStr',
                  style: AppTextStyles.priceLg.copyWith(color: AppColors.white),
                ),
                Text(
                  '* Estimasi jarak 2km, harga bisa berubah',
                  style: AppTextStyles.caption.copyWith(color: AppColors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
