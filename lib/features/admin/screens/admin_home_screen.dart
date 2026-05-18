import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = auth.currentAdmin;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        backgroundColor: AppColors.grey900,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Panel', style: TextStyle(fontSize: 16)),
            Text(
              admin?.nama ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.grey400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/admin/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.grey500,
          tabs: const [
            Tab(text: 'Menunggu'),
            Tab(text: 'Disetujui'),
            Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VerifikasiList(status: 'menunggu'),
          _VerifikasiList(status: 'disetujui'),
          _VerifikasiList(status: 'ditolak'),
        ],
      ),
    );
  }
}

// ── List verifikasi per status ────────────────────────────────────────────

class _VerifikasiList extends StatefulWidget {
  final String status;
  const _VerifikasiList({required this.status});

  @override
  State<_VerifikasiList> createState() => _VerifikasiListState();
}

class _VerifikasiListState extends State<_VerifikasiList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Join porter_verifikasi dengan porters
      final res = await _supabase
          .from('porter_verifikasi')
          .select('*, porters(id, nama, email, no_hp, foto_profil)')
          .eq('status', widget.status)
          .order('created_at', ascending: false);

      setState(() {
        _data = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.status == 'menunggu'
                  ? Icons.hourglass_empty_rounded
                  : widget.status == 'disetujui'
                      ? Icons.verified_rounded
                      : Icons.cancel_rounded,
              size: 56,
              color: AppColors.grey300,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada data',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _data.length,
        itemBuilder: (context, i) {
          final item = _data[i];
          final porter = item['porters'] as Map<String, dynamic>? ?? {};
          return _VerifikasiCard(
            verifikasiId: item['id'] as String,
            porterId: porter['id'] as String? ?? '',
            nama: porter['nama'] as String? ?? '-',
            email: porter['email'] as String? ?? '-',
            noHp: porter['no_hp'] as String? ?? '-',
            dokumenUrl: item['dokumen_url'] as String? ?? '',
            catatanAdmin: item['catatan_admin'] as String?,
            createdAt: item['created_at'] as String? ?? '',
            status: widget.status,
            onRefresh: _load,
          );
        },
      ),
    );
  }
}

// ── Kartu per porter ──────────────────────────────────────────────────────

class _VerifikasiCard extends StatefulWidget {
  final String verifikasiId;
  final String porterId;
  final String nama;
  final String email;
  final String noHp;
  final String dokumenUrl;
  final String? catatanAdmin;
  final String createdAt;
  final String status;
  final VoidCallback onRefresh;

  const _VerifikasiCard({
    required this.verifikasiId,
    required this.porterId,
    required this.nama,
    required this.email,
    required this.noHp,
    required this.dokumenUrl,
    required this.catatanAdmin,
    required this.createdAt,
    required this.status,
    required this.onRefresh,
  });

  @override
  State<_VerifikasiCard> createState() => _VerifikasiCardState();
}

class _VerifikasiCardState extends State<_VerifikasiCard> {
  bool _loadingSetujui = false;
  bool _loadingTolak = false;

  Future<void> _setujui() async {
    setState(() => _loadingSetujui = true);
    try {
      final now = DateTime.now().toIso8601String();
      final admin = context.read<AuthProvider>().currentAdmin;

      // Update tabel porter_verifikasi
      await _supabase.from('porter_verifikasi').update({
        'status': 'disetujui',
        'admin_id': admin?.id,
        'tanggal_verifikasi': now,
        'catatan_admin': null,
      }).eq('id', widget.verifikasiId);

      // Update tabel porters
      await _supabase.from('porters').update({
        'status_verifikasi': 'disetujui',
        'is_aktif': true,
      }).eq('id', widget.porterId);

      if (!mounted) return;
      _showSnack('✅ ${widget.nama} berhasil diverifikasi', AppColors.success);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loadingSetujui = false);
    }
  }

  Future<void> _tolak() async {
    // Minta alasan penolakan
    final catatanCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Verifikasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan alasan penolakan untuk ${widget.nama}:',
              style: AppTextStyles.bodyMd,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catatanCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Contoh: Foto dokumen tidak jelas, mohon upload ulang',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingTolak = true);
    try {
      final now = DateTime.now().toIso8601String();
      final admin = context.read<AuthProvider>().currentAdmin;

      await _supabase.from('porter_verifikasi').update({
        'status': 'ditolak',
        'admin_id': admin?.id,
        'tanggal_verifikasi': now,
        'catatan_admin': catatanCtrl.text.trim().isEmpty
            ? 'Dokumen ditolak oleh admin.'
            : catatanCtrl.text.trim(),
      }).eq('id', widget.verifikasiId);

      await _supabase.from('porters').update({
        'status_verifikasi': 'ditolak',
        'is_aktif': false,
      }).eq('id', widget.porterId);

      if (!mounted) return;
      _showSnack('❌ ${widget.nama} ditolak', AppColors.warning);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loadingTolak = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _lihatDokumen() {
    if (widget.dokumenUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Dokumen Porter'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                widget.dokumenUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_rounded,
                      size: 64, color: AppColors.grey400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format tanggal
    String tanggal = '-';
    try {
      final dt = DateTime.parse(widget.createdAt).toLocal();
      tanggal = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + nama
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary100,
                  child: Text(
                    widget.nama.isNotEmpty
                        ? widget.nama[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nama, style: AppTextStyles.h4),
                      Text(
                        widget.email,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.grey500),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: widget.status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Info
            _InfoRow(icon: Icons.phone_outlined, text: widget.noHp),
            const SizedBox(height: 4),
            _InfoRow(
                icon: Icons.calendar_today_outlined,
                text: 'Daftar: $tanggal'),

            // Catatan admin jika ada
            if (widget.catatanAdmin != null &&
                widget.catatanAdmin!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.catatanAdmin!,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Tombol lihat dokumen
            OutlinedButton.icon(
              onPressed:
                  widget.dokumenUrl.isNotEmpty ? _lihatDokumen : null,
              icon: const Icon(Icons.image_search_rounded, size: 18),
              label: const Text('Lihat Dokumen'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),

            // Tombol approve/tolak hanya untuk yang menunggu
            if (widget.status == 'menunggu') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_loadingTolak || _loadingSetujui)
                          ? null
                          : _tolak,
                      icon: _loadingTolak
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.error),
                      label: Text(
                        'Tolak',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_loadingTolak || _loadingSetujui)
                          ? null
                          : _setujui,
                      icon: _loadingSetujui
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'disetujui' => (AppColors.success, 'Disetujui'),
      'ditolak' => (AppColors.error, 'Ditolak'),
      _ => (AppColors.warning, 'Menunggu'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(color: color),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.grey500),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600),
        ),
      ],
    );
  }
}