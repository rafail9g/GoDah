import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/call_service.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class PorterProfileTab extends StatelessWidget {
  const PorterProfileTab({super.key});

  static const _callCenterPhone = AppStrings.adminPhone;

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final porter = auth.currentPorter;
    if (porter == null) return;

    final namaCtrl = TextEditingController(text: porter.nama);
    final hpCtrl = TextEditingController(text: porter.noHp);

    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil Porter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (namaCtrl.text.trim().isEmpty || hpCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Nama dan nomor HP wajib diisi.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(ctx, {'nama': namaCtrl.text, 'noHp': hpCtrl.text});
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      namaCtrl.dispose();
      hpCtrl.dispose();
    });

    if (payload == null || !context.mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!context.mounted) return;

    final result = await auth.updatePorterProfile(
      nama: payload['nama'] ?? '',
      noHp: payload['noHp'] ?? '',
    );
    if (!context.mounted) return;

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil porter berhasil diperbarui.'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final porter = auth.currentPorter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.primary100,
                      child: Text(
                        porter?.nama.isNotEmpty == true
                            ? porter!.nama[0].toUpperCase()
                            : 'P',
                        style: AppTextStyles.displayMd.copyWith(
                          color: AppColors.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    porter?.nama ?? '-',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    porter?.email ?? '-',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VerifBadge(status: porter?.statusVerifikasi ?? 'menunggu'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'INFORMASI PORTER',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.grey500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.phone_android_rounded,
                        label: 'No. HP',
                        value: porter?.noHp ?? '-',
                      ),
                      const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Total Selesai',
                        value: '${porter?.totalSelesai ?? 0} order',
                      ),
                      const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Status Akun',
                        value: _verifLabel(porter?.statusVerifikasi ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'RATING DARI USER',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.grey500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _PorterRatingsSection(porterId: porter?.id),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'PENGATURAN',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.grey500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _InfoCard(
                    children: [
                      _MenuRow(
                        icon: Icons.edit_rounded,
                        label: 'Edit Profil',
                        onTap: () => _showEditProfileDialog(context),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.upload_file_rounded,
                        label: 'Verifikasi Dokumen',
                        onTap: () => context.push('/porter/verification'),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.support_agent_rounded,
                        label: 'Call Center',
                        onTap: () => CallService.callPhone(
                          context,
                          _callCenterPhone,
                          targetLabel: 'call center',
                        ),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        label: 'Keluar dari Akun',
                        color: AppColors.error,
                        onTap: () async {
                          await auth.logout();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Center(
                    child: Text(
                      'GoDah Porter v1.0.0\nJasa Angkut Barang Mahasiswa',
                      style: AppTextStyles.caption.copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _verifLabel(String s) => switch (s) {
    'disetujui' => 'Terverifikasi',
    'ditolak' => 'Ditolak',
    _ => 'Menunggu Review',
  };
}

class _PorterRatingsSection extends StatefulWidget {
  final String? porterId;

  const _PorterRatingsSection({required this.porterId});

  @override
  State<_PorterRatingsSection> createState() => _PorterRatingsSectionState();
}

class _PorterRatingsSectionState extends State<_PorterRatingsSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRatings();
  }

  @override
  void didUpdateWidget(covariant _PorterRatingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.porterId != widget.porterId) {
      _future = _loadRatings();
    }
  }

  Future<List<Map<String, dynamic>>> _loadRatings() async {
    final porterId = widget.porterId;
    if (porterId == null || porterId.isEmpty) return [];

    try {
      final res = await _supabase
          .from('ratings')
          .select('''
            id,
            nilai,
            ulasan,
            created_at,
            users(nama),
            orders(jenis_barang, status)
          ''')
          .eq('porter_id', porterId)
          .order('created_at', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      final res = await _supabase
          .from('ratings')
          .select('*')
          .eq('porter_id', porterId)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InfoCard(
            children: [
              Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ],
          );
        }

        final ratings = snapshot.data ?? [];
        if (ratings.isEmpty) {
          return _InfoCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_border_rounded,
                      color: AppColors.grey400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada rating dari user',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.grey500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final total = ratings.fold<num>(
          0,
          (sum, item) => sum + (item['nilai'] as num? ?? 0),
        );
        final average = total / ratings.length;

        return _InfoCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          average.toStringAsFixed(1),
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.grey900,
                          ),
                        ),
                        Text(
                          '${ratings.length} rating terbaru',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < average.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...ratings.map((rating) => _RatingReviewRow(rating: rating)),
          ],
        );
      },
    );
  }
}

class _RatingReviewRow extends StatelessWidget {
  final Map<String, dynamic> rating;

  const _RatingReviewRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final user = rating['users'] as Map<String, dynamic>? ?? {};
    final order = rating['orders'] as Map<String, dynamic>? ?? {};
    final nilai = (rating['nilai'] as num? ?? 0).toInt();
    final ulasan = rating['ulasan'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user['nama'] as String? ?? 'User',
                  style: AppTextStyles.labelLg,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < nilai ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if ((order['jenis_barang'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              order['jenis_barang'] as String,
              style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            ulasan?.trim().isNotEmpty == true ? ulasan!.trim() : 'Tidak ada ulasan',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

class _VerifBadge extends StatelessWidget {
  final String status;
  const _VerifBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      'disetujui' => (
        AppColors.success,
        'Terverifikasi',
        Icons.verified_rounded,
      ),
      'ditolak' => (AppColors.error, 'Ditolak', Icons.cancel_rounded),
      _ => (
        AppColors.warning,
        'Menunggu Verifikasi',
        Icons.hourglass_top_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.labelLg),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.grey800,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.labelLg.copyWith(color: color)),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }
}
