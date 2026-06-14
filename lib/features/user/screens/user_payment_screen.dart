
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/payment_service.dart';

class UserPaymentScreen extends StatefulWidget {
  final String orderId;
  final double totalBiaya;
  final String lokasiJemput;
  final String lokasiTujuan;
  final String jenisBrg;
  final String customerName;
  final String customerEmail;

  const UserPaymentScreen({
    super.key,
    required this.orderId,
    required this.totalBiaya,
    required this.lokasiJemput,
    required this.lokasiTujuan,
    required this.jenisBrg,
    required this.customerName,
    required this.customerEmail,
  });

  @override
  State<UserPaymentScreen> createState() => _UserPaymentScreenState();
}

class _UserPaymentScreenState extends State<UserPaymentScreen> {
  _PaymentState _state = _PaymentState.idle;

  String? _midtransOrderId;
  String? _redirectUrl;

  Future<void> _bayarSekarang() async {
    setState(() => _state = _PaymentState.creatingPayment);

    final result = await PaymentService.instance.createPayment(
      orderId: widget.orderId,
      amount: widget.totalBiaya,
      customerName: widget.customerName,
      customerEmail: widget.customerEmail,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _state = _PaymentState.idle);
      _showSnack('Gagal membuat transaksi. Coba lagi.', AppColors.error);
      return;
    }

    _midtransOrderId = result.midtransOrderId;
    _redirectUrl = result.redirectUrl;

    final uri = Uri.parse(result.redirectUrl);
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (!mounted) return;
      setState(() => _state = _PaymentState.idle);
      _showSnack('Tidak bisa membuka halaman pembayaran.', AppColors.error);
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;
    setState(() => _state = _PaymentState.waitingConfirmation);
  }

  Future<void> _sudahBayar() async {
    if (_midtransOrderId == null) return;

    setState(() => _state = _PaymentState.verifying);

    final success = await PaymentService.instance.markPaidManual(
      midtransOrderId: _midtransOrderId!,
      paymentType: 'bank_transfer',
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _state = _PaymentState.waitingConfirmation);
      
      _showSnack('Gagal konfirmasi pembayaran. Coba lagi.', AppColors.error);
      return;
    }

    final status = await PaymentService.instance.checkPaymentStatus(
      widget.orderId,
    );

    if (!mounted) return;

    if (status == 'paid') {
      setState(() => _state = _PaymentState.success);
    } else {
      setState(() => _state = _PaymentState.waitingConfirmation);
      _showSnack(
        'Status masih pending. Tunggu sebentar lalu coba lagi.',
        AppColors.warning,
      );
    }
  }

  Future<void> _bukaMidtransLagi() async {
    if (_redirectUrl == null) return;
    final uri = Uri.parse(_redirectUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: AppColors.primary,
        leading: _state == _PaymentState.success
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _state == _PaymentState.success
          ? _SuccessView(onSelesai: () => Navigator.pop(context, true))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingScreen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OrderSummaryCard(
                    orderId: widget.orderId,
                    lokasiJemput: widget.lokasiJemput,
                    lokasiTujuan: widget.lokasiTujuan,
                    jenisBrg: widget.jenisBrg,
                    totalBiaya: widget.totalBiaya,
                  ),
                  const SizedBox(height: 24),

                  if (_state == _PaymentState.waitingConfirmation) ...[
                    _WaitingPanel(
                      onSudahBayar: _sudahBayar,
                      onBukaMidtrans: _bukaMidtransLagi,
                    ),
                  ] else if (_state == _PaymentState.verifying) ...[
                    _VerifyingPanel(),
                  ] else ...[
                    _BayarPanel(
                      loading: _state == _PaymentState.creatingPayment,
                      onBayar: _bayarSekarang,
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 14, color: AppColors.grey500),
                      const SizedBox(width: 6),
                      Text(
                        'Pembayaran aman diproses oleh Midtrans',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}


enum _PaymentState {
  idle,
  creatingPayment,
  waitingConfirmation,
  verifying,
  success,
}


class _OrderSummaryCard extends StatelessWidget {
  final String orderId;
  final String lokasiJemput;
  final String lokasiTujuan;
  final String jenisBrg;
  final double totalBiaya;

  const _OrderSummaryCard({
    required this.orderId,
    required this.lokasiJemput,
    required this.lokasiTujuan,
    required this.jenisBrg,
    required this.totalBiaya,
  });

  String _rupiahFormat(double n) {
    final str = n.toInt().toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColors.white, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Pesanan',
                      style: AppTextStyles.labelLg
                          .copyWith(color: AppColors.white),
                    ),
                    Text(
                      'ID: ${orderId.substring(0, 8).toUpperCase()}...',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.radio_button_on_rounded,
                  color: AppColors.success,
                  label: 'Lokasi Jemput',
                  value: lokasiJemput,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.location_on_rounded,
                  color: AppColors.error,
                  label: 'Tujuan',
                  value: lokasiTujuan,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  label: 'Jenis Barang',
                  value: jenisBrg,
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Biaya',
                      style: AppTextStyles.labelLg.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${_rupiahFormat(totalBiaya)}',
                      style: AppTextStyles.priceMd.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                value,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey800),
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

class _BayarPanel extends StatelessWidget {
  final bool loading;
  final VoidCallback onBayar;

  const _BayarPanel({required this.loading, required this.onBayar});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kamu akan diarahkan ke halaman pembayaran Midtrans. '
                  'Setelah selesai, kembali ke app dan konfirmasi pembayaran.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: loading ? null : onBayar,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.payment_rounded, size: 22),
          label: Text(
            loading ? 'Menyiapkan Pembayaran...' : 'Bayar Sekarang',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  final VoidCallback onSudahBayar;
  final VoidCallback onBukaMidtrans;

  const _WaitingPanel({
    required this.onSudahBayar,
    required this.onBukaMidtrans,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.warning.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_rounded,
                  color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menunggu Konfirmasi',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sudah selesai bayar di Midtrans? Tap tombol di bawah.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: onSudahBayar,
          icon: const Icon(Icons.check_circle_rounded, size: 22),
          label: const Text(
            'Saya Sudah Bayar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: onBukaMidtrans,
          icon: const Icon(Icons.open_in_browser_rounded, size: 18),
          label: const Text('Buka Halaman Pembayaran Lagi'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Memverifikasi Pembayaran...',
            style: AppTextStyles.labelLg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sedang mengkonfirmasi status pembayaran ke server.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onSelesai;

  const _SuccessView({required this.onSelesai});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Pembayaran Berhasil! ',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pesananmu sudah dikonfirmasi.\n'
              'Porter akan segera mencari ordermu.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: onSelesai,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Lihat Status Pesanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
