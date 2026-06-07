import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../utils/string_utils.dart';

abstract final class CallService {
  static Future<void> callPhone(
    BuildContext context,
    String? phone, {
    String targetLabel = 'nomor tujuan',
  }) async {
    final rawPhone = phone?.trim() ?? '';
    if (!StringUtils.isPhoneNumber(rawPhone)) {
      _showSnack(
        context,
        'Nomor $targetLabel tidak tersedia.',
        AppColors.warning,
      );
      return;
    }

    final normalized = StringUtils.normalizePhone(rawPhone);
    final uri = Uri(scheme: 'tel', path: normalized);

    if (!await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      _showSnack(
        context,
        'Tidak bisa membuka aplikasi telepon.',
        AppColors.error,
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _showSnack(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
