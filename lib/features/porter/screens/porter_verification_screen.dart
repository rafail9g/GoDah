import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../core/services/fcm_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class PorterVerificationScreen extends StatefulWidget {
  const PorterVerificationScreen({super.key});

  @override
  State<PorterVerificationScreen> createState() =>
      _PorterVerificationScreenState();
}

class _PorterVerificationScreenState extends State<PorterVerificationScreen> {
  File? _fotoKtp;
  bool _loading = false;
  bool _submitted = false;
  

  Future<void> _ambilFotoKtp() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked != null) {
      setState(() => _fotoKtp = File(picked.path));
    }
  }


Future<void> _kirimVerifikasi() async {
  final auth = context.read<AuthProvider>();
  final porter = auth.currentPorter;
  if (porter == null || _fotoKtp == null) return;

  setState(() => _loading = true);

  try {
    final fileName =
        'verifikasi/${porter.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage
        .from('dokumen-porter')
        .upload(fileName, _fotoKtp!);

    final dokumenUrl = _supabase.storage
        .from('dokumen-porter')
        .getPublicUrl(fileName);

    await _supabase.from('porter_verifikasi').insert({
      'porter_id': porter.id,
      'status': 'menunggu',
      'dokumen_url': dokumenUrl,
    });

    await _supabase
        .from('porters')
        .update({'status_verifikasi': 'menunggu', 'is_aktif': false})
        .eq('id', porter.id);

    final adminRes = await _supabase
        .from('admins')
        .select('id')
        .not('fcm_token', 'is', null);

    for (final admin in List<Map<String, dynamic>>.from(adminRes)) {
      await FcmService.instance.sendVerifikasiNotifToAdmin(
        porterNama: porter.nama,
        porterId: porter.id,
        targetAdminId: admin['id'] as String,
      );
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
    });
    await auth.reloadPorterProfile();

  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal upload: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final porter = context.watch<AuthProvider>().currentPorter;
    if (porter == null) return const SizedBox();

    final isApproved = porter.statusVerifikasi == 'disetujui';
    final isRejected = porter.statusVerifikasi == 'ditolak';
    final tampilForm = !isApproved && !_submitted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Verifikasi Akun Porter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBanner(status: porter.statusVerifikasi),
            const SizedBox(height: 24),

            if (tampilForm) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isRejected
                            ? 'Dokumen kamu ditolak. Foto ulang KTP/KTM yang jelas '
                                  'dan kirim kembali untuk diverifikasi.'
                            : 'Foto KTP atau KTM kamu menggunakan kamera. '
                                  'Pastikan foto jelas dan tidak buram.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Foto Dokumen Identitas', style: AppTextStyles.h4),
              const SizedBox(height: 10),

              GestureDetector(
                onTap: _ambilFotoKtp,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    border: Border.all(
                      color: _fotoKtp != null
                          ? AppColors.success
                          : AppColors.grey300,
                      width: 2,
                    ),
                  ),
                  child: _fotoKtp != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusLg,
                              ),
                              child: Image.file(
                                _fotoKtp!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: _ambilFotoKtp,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey900.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.camera_alt,
                                        color: AppColors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Foto Ulang',
                                        style: AppTextStyles.labelSm.copyWith(
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              size: 48,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap untuk buka kamera',
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.grey500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'KTP atau KTM yang masih berlaku',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: (_fotoKtp == null || _loading)
                    ? null
                    : _kirimVerifikasi,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _loading ? 'Mengirim...' : 'Kirim untuk Verifikasi',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeightMd),
                ),
              ),
            ],

            if (_submitted) ...[
              const SizedBox(height: 16),
              const _SubmittedInfo(),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = switch (status) {
      'disetujui' => (
        AppColors.success,
        Icons.verified_rounded,
        'Akun Terverifikasi',
        'Kamu sudah bisa menerima pesanan dari mahasiswa.',
      ),
      'ditolak' => (
        AppColors.error,
        Icons.cancel_rounded,
        'Verifikasi Ditolak',
        'Dokumen ditolak. Silakan foto ulang dan kirim kembali.',
      ),
      _ => (
        AppColors.warning,
        Icons.hourglass_top_rounded,
        'Menunggu Verifikasi',
        'Dokumen sedang ditinjau admin. Tunggu 1x24 jam.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h4.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.grey700,
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

class _SubmittedInfo extends StatelessWidget {
  const _SubmittedInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.success,
          size: 64,
        ),
        const SizedBox(height: 12),
        Text('Dokumen Berhasil Dikirim', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          'Admin akan memverifikasi dalam 1x24 jam.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
