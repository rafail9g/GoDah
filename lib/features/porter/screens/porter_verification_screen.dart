import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

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
  File? _dokumenFile;
  final _catatanCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _dokumenFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final porter = auth.currentPorter;
    if (porter == null || _dokumenFile == null) return;

    setState(() => _loading = true);

    try {
      // Upload dokumen ke Supabase Storage
      final fileName =
          'verifikasi/${porter.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('dokumen-porter')
          .upload(fileName, _dokumenFile!);

      final dokumenUrl = _supabase.storage
          .from('dokumen-porter')
          .getPublicUrl(fileName);

      // Insert ke tabel porter_verifikasi
      await _supabase.from('porter_verifikasi').insert({
        'porter_id': porter.id,
        'status': 'menunggu',
        'dokumen_url': dokumenUrl,
        'catatan_admin': null,
      });

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
    final auth = context.watch<AuthProvider>();
    final porter = auth.currentPorter;

    if (porter == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Verifikasi Akun Porter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status verifikasi
            _StatusBanner(status: porter.statusVerifikasi),
            const SizedBox(height: 24),

            if (porter.isPending && !_submitted) ...[
              Text('Upload Dokumen Identitas', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                'Upload KTM (Kartu Tanda Mahasiswa) atau KTP yang masih berlaku. '
                'Admin akan memverifikasi dokumen kamu dalam 1x24 jam.',
                style:
                    AppTextStyles.bodyMd.copyWith(color: AppColors.grey600),
              ),
              const SizedBox(height: 24),

              // Area upload
              GestureDetector(
                onTap: _pickDocument,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    border: Border.all(
                      color: _dokumenFile != null
                          ? AppColors.success
                          : AppColors.grey300,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _dokumenFile != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusLg),
                              child: Image.file(
                                _dokumenFile!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _dokumenFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_upload_outlined,
                              size: 48,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap untuk pilih foto dokumen',
                              style: AppTextStyles.labelLg
                                  .copyWith(color: AppColors.grey500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Format JPG/PNG, maks. 5MB',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed:
                    (_dokumenFile == null || _loading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeightMd),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Kirim untuk Verifikasi'),
              ),
            ],

            if (_submitted || porter.statusVerifikasi == 'menunggu') ...[
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
          'Dokumen kamu ditolak. Upload ulang dokumen yang valid.',
        ),
      _ => (
          AppColors.warning,
          Icons.hourglass_top_rounded,
          'Menunggu Verifikasi',
          'Dokumen kamu sedang ditinjau oleh admin.',
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
                Text(
                  title,
                  style: AppTextStyles.h4.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      AppTextStyles.bodyMd.copyWith(color: AppColors.grey700),
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
        const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.success, size: 64),
        const SizedBox(height: 12),
        Text('Dokumen Berhasil Dikirim', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          'Admin akan memverifikasi dokumen kamu dalam 1x24 jam. '
          'Kamu akan mendapat notifikasi setelah diverifikasi.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
