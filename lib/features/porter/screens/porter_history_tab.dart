import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class PorterHistoryTab extends StatefulWidget {
  const PorterHistoryTab({super.key});

  @override
  State<PorterHistoryTab> createState() => _PorterHistoryTabState();
}

class _PorterHistoryTabState extends State<PorterHistoryTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final porter = context.read<AuthProvider>().currentPorter;
      if (porter == null) return;

      final res = await _supabase
          .from('orders')
          .select('''
            *,
            users(nama, no_hp),
            bukti_pengiriman(foto_url, keterangan, created_at),
            ratings(nilai, ulasan)
          ''')
          .eq('porter_id', porter.id)
          .inFilter('status', ['selesai', 'batal'])
          .order('waktu_pesan', ascending: false);

      setState(() => _orders = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Order'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _orders.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      _EmptyHistory(),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, i) {
                      return _HistoryOrderCard(order: _orders[i]);
                    },
                  ),
                ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _HistoryOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final isSelesai = status == 'selesai';
    final statusColor = isSelesai ? AppColors.statusSelesai : AppColors.statusBatal;
    final statusLabel = isSelesai ? 'Selesai' : 'Dibatalkan';

    final user = order['users'] as Map<String, dynamic>? ?? {};
    final bukti = order['bukti_pengiriman'];
    final Map<String, dynamic>? buktiData = bukti is List && bukti.isNotEmpty
        ? bukti[0] as Map<String, dynamic>
        : null;
    final ratings = order['ratings'];
    final Map<String, dynamic>? ratingData = ratings is List && ratings.isNotEmpty
        ? ratings[0] as Map<String, dynamic>
        : null;

    final biaya = (order['total_biaya'] as num? ?? 0).toInt();
    final jenisBrg = order['jenis_barang'] as String? ?? 'Tidak disebutkan';
    final layanan = order['jenis_layanan'] as String? ?? 'instant';
    final berat = order['estimasi_berat'];

    String tanggal = '-';
    try {
      final dt = DateTime.parse(order['waktu_pesan'] as String).toLocal();
      tanggal = '${dt.day}/${dt.month}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusRound),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelesai ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: AppTextStyles.labelSm.copyWith(color: statusColor)),
                    ],
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
                // User info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary50,
                      child: Text(
                        (user['nama'] as String? ?? 'U').isNotEmpty
                            ? (user['nama'] as String)[0].toUpperCase()
                            : 'U',
                        style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['nama'] as String? ?? '-', style: AppTextStyles.labelLg),
                          Text(user['no_hp'] as String? ?? '-', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${_rupiahFormat(biaya)}',
                      style: AppTextStyles.priceMd,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lokasi
                _LokasiItem(
                  icon: Icons.radio_button_on_rounded,
                  color: AppColors.success,
                  label: 'Jemput',
                  text: order['lokasi_jemput'] as String? ?? '-',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(width: 2, height: 14, color: AppColors.grey200),
                ),
                _LokasiItem(
                  icon: Icons.location_on_rounded,
                  color: AppColors.error,
                  label: 'Tujuan',
                  text: order['lokasi_tujuan'] as String? ?? '-',
                ),
                const SizedBox(height: 12),

                // Detail barang
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _DetailChip(
                      icon: Icons.category_outlined,
                      label: jenisBrg,
                      color: AppColors.primary,
                    ),
                    _DetailChip(
                      icon: layanan == 'instant' ? Icons.bolt_rounded : Icons.calendar_today_rounded,
                      label: layanan == 'instant' ? 'Instan' : 'Terjadwal',
                      color: layanan == 'instant' ? AppColors.warning : AppColors.info,
                    ),
                    if (berat != null)
                      _DetailChip(
                        icon: Icons.scale_rounded,
                        label: '${berat}kg',
                        color: AppColors.secondary,
                      ),
                  ],
                ),

                // Rating
                if (ratingData != null) ...[
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
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Bukti Pengiriman
                if (buktiData != null) ...[
                  const Divider(height: 20),
                  Text('Bukti Pengiriman', style: AppTextStyles.labelLg),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showBukti(context, buktiData['foto_url'] as String),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      child: Image.network(
                        buktiData['foto_url'] as String,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                height: 140,
                                color: AppColors.grey100,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.grey100,
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded,
                                size: 36, color: AppColors.grey400),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (buktiData['keterangan'] != null &&
                      (buktiData['keterangan'] as String).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      buktiData['keterangan'] as String,
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBukti(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
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

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ── Shared Widgets ────────────────────────────────────────────────────────

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
                style: AppTextStyles.bodySm.copyWith(color: AppColors.grey800),
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

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: AppColors.grey200),
          const SizedBox(height: 16),
          Text('Belum Ada Riwayat', style: AppTextStyles.h3.copyWith(color: AppColors.grey400)),
          const SizedBox(height: 8),
          Text(
            'Order yang sudah selesai akan muncul di sini.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
