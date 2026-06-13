import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/fcm_service.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
        backgroundColor: AppColors.primary900,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin GoDah', style: TextStyle(fontSize: 16)),
            Text(
              admin?.nama.isNotEmpty == true ? admin!.nama : 'Dashboard',
              style: const TextStyle(fontSize: 12, color: AppColors.primary100),
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
          isScrollable: true,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.primary100,
          labelStyle: AppTextStyles.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
          tabs: const [
            Tab(text: 'Verifikasi'),
            Tab(text: 'User'),
            Tab(text: 'Porter'),
            Tab(text: 'Order'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VerifikasiAdminTab(),
          _UsersCrudTab(),
          _PortersCrudTab(),
          _OrdersCrudTab(),
        ],
      ),
    );
  }
}

class _VerifikasiAdminTab extends StatelessWidget {
  const _VerifikasiAdminTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: AppColors.white,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.grey500,
              indicatorColor: AppColors.primary,
              labelStyle: AppTextStyles.labelMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'Menunggu'),
                Tab(text: 'Disetujui'),
                Tab(text: 'Ditolak'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _VerifikasiList(status: 'menunggu'),
                _VerifikasiList(status: 'disetujui'),
                _VerifikasiList(status: 'ditolak'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersCrudTab extends StatelessWidget {
  const _UsersCrudTab();

  @override
  Widget build(BuildContext context) => const _SimpleAdminTable(
    title: 'Data User',
    table: 'users',
    select: '*',
    editableFields: ['status'],
    requiredFields: ['status'],
    titleField: 'nama',
    subtitleField: 'email',
    lineFields: ['no_hp', 'alamat', 'status'],
    allowAdd: false,
    allowDelete: false,
  );
}

class _PortersCrudTab extends StatelessWidget {
  const _PortersCrudTab();

  @override
  Widget build(BuildContext context) => const _SimpleAdminTable(
    title: 'Data Porter',
    table: 'porters',
    select: '*',
    editableFields: ['status'],
    requiredFields: ['status'],
    titleField: 'nama',
    subtitleField: 'email',
    lineFields: [
      'no_hp',
      'status',
      'status_verifikasi',
      'is_aktif',
      'total_selesai',
    ],
    allowAdd: false,
    allowDelete: false,
  );
}

class _OrdersCrudTab extends StatelessWidget {
  const _OrdersCrudTab();

  @override
  Widget build(BuildContext context) => const _SimpleAdminTable(
    title: 'Data Order',
    table: 'orders',
    select: '*, users(nama), porters(nama)',
    editableFields: ['lokasi_tujuan', 'status', 'catatan'],
    requiredFields: ['lokasi_tujuan', 'status'],
    titleField: 'jenis_barang',
    subtitleField: 'status',
    lineFields: [
      'users.nama',
      'porters.nama',
      'lokasi_jemput',
      'lokasi_tujuan',
      'total_biaya',
    ],
    allowAdd: false,
  );
}

class _SimpleAdminTable extends StatefulWidget {
  final String title;
  final String table;
  final String select;
  final List<String> editableFields;
  final List<String> requiredFields;
  final Map<String, dynamic> insertDefaults;
  final String titleField;
  final String subtitleField;
  final List<String> lineFields;
  final bool allowAdd;
  final bool allowDelete;

  const _SimpleAdminTable({
    required this.title,
    required this.table,
    required this.select,
    required this.editableFields,
    this.requiredFields = const [],
    this.insertDefaults = const {},
    required this.titleField,
    required this.subtitleField,
    required this.lineFields,
    this.allowAdd = true,
    this.allowDelete = true,
  });

  @override
  State<_SimpleAdminTable> createState() => _SimpleAdminTableState();
}

class _SimpleAdminTableState extends State<_SimpleAdminTable> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  Timer? _autoRefreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await _supabase
          .from(widget.table)
          .select(widget.select)
          .order(
            widget.table == 'orders' ? 'waktu_pesan' : 'created_at',
            ascending: false,
          );
      if (mounted) setState(() => _data = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      _showSnack('Gagal memuat ${widget.title}: $e', AppColors.error);
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upsert([Map<String, dynamic>? item]) async {
    final controllers = {
      for (final field in widget.editableFields)
        field: TextEditingController(text: '${item?[field] ?? ''}'),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item == null ? 'Tambah ${widget.title}' : 'Edit ${widget.title}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.editableFields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _fieldOptions(field) == null
                        ? TextField(
                            controller: controllers[field],
                            decoration: InputDecoration(
                              labelText: _fieldLabel(field),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value:
                                controllers[field]?.text.trim().isNotEmpty ==
                                    true
                                ? controllers[field]!.text.trim()
                                : null,
                            decoration: InputDecoration(
                              labelText: _fieldLabel(field),
                            ),
                            items: _fieldOptions(field)!
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(_statusLabel(option)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controllers[field]?.text = value;
                              }
                            },
                          ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              for (final field in widget.requiredFields) {
                if ((controllers[field]?.text.trim() ?? '').isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${_fieldLabel(field)} wajib diisi.'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) {
      for (final ctrl in controllers.values) {
        ctrl.dispose();
      }
      return;
    }

    try {
      final payload = <String, dynamic>{...widget.insertDefaults};
      for (final entry in controllers.entries) {
        payload[entry.key] = _parseFieldValue(entry.key, entry.value.text);
      }
      if (widget.table == 'porters' &&
          (payload['status'] == 'nonaktif' || payload['status'] == 'diblokir')) {
        payload['is_aktif'] = false;
      }

      if (item == null) {
        await _supabase.from(widget.table).insert(payload);
      } else {
        await _supabase.from(widget.table).update(payload).eq('id', item['id']);
      }

      _showSnack('${widget.title} tersimpan.', AppColors.success);
      _load();
    } catch (e) {
      _showSnack('Gagal menyimpan ${widget.title}: $e', AppColors.error);
    } finally {
      for (final ctrl in controllers.values) {
        ctrl.dispose();
      }
    }
  }

  Future<void> _editOrderDestinationOnMap(Map<String, dynamic> item) async {
    final tujuanCtrl = TextEditingController(
      text: _value(item, 'lokasi_tujuan') == '-'
          ? ''
          : _value(item, 'lokasi_tujuan'),
    );
    final latTujuan = _numValue(item['lat_tujuan']);
    final lngTujuan = _numValue(item['lng_tujuan']);
    final latJemput = _numValue(item['lat_jemput']);
    final lngJemput = _numValue(item['lng_jemput']);

    LatLng selected = LatLng(
      latTujuan ?? latJemput ?? -7.9797,
      lngTujuan ?? lngJemput ?? 113.6175,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Ubah Tujuan Pesanan'),
              content: SizedBox(
                width: MediaQuery.sizeOf(ctx).width * 0.9,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      controller: tujuanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama / Alamat Tujuan',
                        hintText: 'Contoh: Gedung Fakultas Teknik',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: selected,
                            initialZoom: 16,
                            onTap: (_, latlng) {
                              setDialogState(() {
                                selected = latlng;
                                tujuanCtrl.text =
                                    'Lat: ${latlng.latitude.toStringAsFixed(5)}, Lng: ${latlng.longitude.toStringAsFixed(5)}';
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.go_dah',
                            ),
                            MarkerLayer(
                              markers: [
                                if (latJemput != null && lngJemput != null)
                                  Marker(
                                    point: LatLng(latJemput, lngJemput),
                                    width: 42,
                                    height: 42,
                                    child: const Icon(
                                      Icons.radio_button_checked_rounded,
                                      color: AppColors.success,
                                      size: 34,
                                    ),
                                  ),
                                Marker(
                                  point: selected,
                                  width: 42,
                                  height: 42,
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.error,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap peta untuk memilih titik tujuan baru.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final tujuan = tujuanCtrl.text.trim();
                          if (tujuan.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Tujuan pesanan wajib diisi.'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);
                          try {
                            await _supabase
                                .from('orders')
                                .update({
                                  'lokasi_tujuan': tujuan,
                                  'lat_tujuan': selected.latitude,
                                  'lng_tujuan': selected.longitude,
                                })
                                .eq('id', item['id']);

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menyimpan tujuan: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(saving ? 'Menyimpan...' : 'Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    tujuanCtrl.dispose();

    if (saved == true) {
      _showSnack('Tujuan pesanan berhasil diperbarui.', AppColors.success);
      _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data?'),
        content: Text(
          'Yakin ingin menghapus ${_value(item, widget.titleField)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _supabase.from(widget.table).delete().eq('id', item['id']);
      _showSnack('${widget.title} dihapus.', AppColors.success);
      _load();
    } catch (e) {
      _showSnack('Gagal menghapus ${widget.title}: $e', AppColors.error);
    }
  }

  dynamic _parseFieldValue(String field, String value) {
    final trimmed = value.trim();
    if (field == 'is_aktif') {
      return trimmed.toLowerCase() == 'true' || trimmed == '1';
    }
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  List<String>? _fieldOptions(String field) {
    if (field == 'status' &&
        (widget.table == 'users' || widget.table == 'porters')) {
      return const ['aktif', 'nonaktif', 'diblokir'];
    }

    if (field == 'status' && widget.table == 'orders') {
      return const [
        'menunggu',
        'diterima',
        'menuju_lokasi',
        'dalam_perjalanan',
        'sampai_tujuan',
        'selesai',
        'batal',
      ];
    }

    if (field == 'status_verifikasi') {
      return const ['menunggu', 'disetujui', 'ditolak'];
    }

    return null;
  }

  double? _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _value(Map<String, dynamic> item, String field) {
    final parts = field.split('.');
    dynamic value = item;
    for (final part in parts) {
      if (value is Map<String, dynamic>) {
        value = value[part];
      } else {
        return '-';
      }
    }
    if (value == null) return '-';
    if (value is bool) return value ? 'Ya' : 'Tidak';
    return '$value';
  }

  String _fieldLabel(String field) => switch (field) {
    'nama' => 'Nama',
    'email' => 'Email',
    'no_hp' => 'No. HP',
    'alamat' => 'Alamat',
    'status' => 'Status',
    'status_verifikasi' => 'Status Verifikasi',
    'is_aktif' => 'Aktif (true/false)',
    'catatan' => 'Catatan',
    'lokasi_tujuan' => 'Tujuan Pesanan',
    'users.nama' => 'User',
    'porters.nama' => 'Porter',
    'lokasi_jemput' => 'Jemput',
    'total_biaya' => 'Biaya',
    _ => field,
  };

  String _statusLabel(String status) => switch (status) {
    'aktif' => 'Aktif',
    'nonaktif' => 'Dinonaktifkan',
    'diblokir' => 'Diblokir',
    'menunggu' => 'Menunggu',
    'diterima' => 'Diterima',
    'menuju_lokasi' => 'Menuju Lokasi',
    'dalam_perjalanan' => 'Dalam Perjalanan',
    'sampai_tujuan' => 'Sampai Tujuan',
    'selesai' => 'Selesai',
    'batal' => 'Batal',
    'disetujui' => 'Disetujui',
    'ditolak' => 'Ditolak',
    _ => status,
  };

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.grey100,
      floatingActionButton: widget.allowAdd
          ? FloatingActionButton.extended(
              onPressed: () => _upsert(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _data.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  const Icon(
                    Icons.table_rows_rounded,
                    size: 56,
                    color: AppColors.grey300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.title} masih kosong',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _data.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _AdminListHeader(
                      title: widget.title,
                      count: _data.length,
                    );
                  }
                  final item = _data[i - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.grey200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _value(item, widget.titleField),
                                      style: AppTextStyles.h4.copyWith(
                                        color: AppColors.grey900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _value(item, widget.subtitleField),
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.grey500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.table == 'orders')
                                IconButton(
                                  onPressed: () =>
                                      _editOrderDestinationOnMap(item),
                                  icon: const Icon(Icons.map_outlined),
                                  color: AppColors.info,
                                  tooltip: 'Ubah tujuan lewat peta',
                                ),
                              IconButton(
                                onPressed: () => _upsert(item),
                                icon: const Icon(Icons.edit_outlined),
                                color: AppColors.primary,
                                tooltip: 'Edit',
                              ),
                              if (widget.allowDelete)
                                IconButton(
                                  onPressed: () => _delete(item),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: AppColors.error,
                                  tooltip: 'Hapus',
                                ),
                            ],
                          ),
                          const Divider(height: 18),
                          ...widget.lineFields.map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${_fieldLabel(field)}: ${_value(item, field)}',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.grey700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AdminListHeader extends StatelessWidget {
  final String title;
  final int count;

  const _AdminListHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h3.copyWith(color: AppColors.grey900),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(AppDimens.radiusRound),
            ),
            child: Text(
              '$count data',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  Timer? _autoRefreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await _supabase
          .from('porter_verifikasi')
          .select('*, porters(id, nama, email, no_hp)')
          .eq('status', widget.status)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() => _data = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
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

      await _supabase
          .from('porter_verifikasi')
          .update({
            'status': 'disetujui',
            'admin_id': admin?.id,
            'tanggal_verifikasi': now,
            'catatan_admin': null,
          })
          .eq('id', widget.verifikasiId);

      await _supabase
          .from('porters')
          .update({'status_verifikasi': 'disetujui', 'is_aktif': true})
          .eq('id', widget.porterId);

      await FcmService.instance.sendVerifikasiStatusNotifToPorter(
        targetPorterId: widget.porterId,
        status: 'disetujui',
      );

      if (!mounted) return;
      _showSnack('${widget.nama} berhasil diverifikasi', AppColors.success);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loadingSetujui = false);
    }
  }

  Future<void> _tolak() async {
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
                hintText:
                    'Contoh: Foto dokumen tidak jelas, mohon upload ulang',
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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

      await _supabase
          .from('porter_verifikasi')
          .update({
            'status': 'ditolak',
            'admin_id': admin?.id,
            'tanggal_verifikasi': now,
            'catatan_admin': catatanCtrl.text.trim().isEmpty
                ? 'Dokumen ditolak oleh admin.'
                : catatanCtrl.text.trim(),
          })
          .eq('id', widget.verifikasiId);

      await _supabase
          .from('porters')
          .update({'status_verifikasi': 'ditolak', 'is_aktif': false})
          .eq('id', widget.porterId);

      final catatan = catatanCtrl.text.trim().isEmpty
          ? 'Dokumen ditolak oleh admin.'
          : catatanCtrl.text.trim();
      await FcmService.instance.sendVerifikasiStatusNotifToPorter(
        targetPorterId: widget.porterId,
        status: 'ditolak',
        catatan: catatan,
      );

      if (!mounted) return;
      _showSnack('${widget.nama} ditolak', AppColors.warning);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loadingTolak = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 64,
                    color: AppColors.grey400,
                  ),
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
    String tanggal = '-';
    try {
      final dt = DateTime.parse(widget.createdAt).toLocal();
      tanggal =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary100,
                  child: Text(
                    widget.nama.isNotEmpty ? widget.nama[0].toUpperCase() : '?',
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
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.grey500,
                        ),
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

            _InfoRow(icon: Icons.phone_outlined, text: widget.noHp),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: 'Daftar: $tanggal',
            ),

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
                    const Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.catatanAdmin!,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: widget.dokumenUrl.isNotEmpty ? _lihatDokumen : null,
              icon: const Icon(Icons.image_search_rounded, size: 18),
              label: const Text('Lihat Dokumen'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),

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
                          : const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
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
      child: Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
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
