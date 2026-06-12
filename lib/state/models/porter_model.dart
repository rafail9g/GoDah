class PorterModel {
  final String id;
  final String nama;
  final String email;
  final String noHp;
  final String statusVerifikasi;
  final bool isAktif;
  final double? latitude;
  final double? longitude;
  final int totalSelesai;
  final DateTime? createdAt;
 
  const PorterModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.noHp,
    this.statusVerifikasi = 'menunggu',
    this.isAktif = false,
    this.latitude,
    this.longitude,
    this.totalSelesai = 0,
    this.createdAt,
  });
 
  bool get isVerified => statusVerifikasi == 'disetujui';
  bool get isPending => statusVerifikasi == 'menunggu';
  bool get isRejected => statusVerifikasi == 'ditolak';
 
  factory PorterModel.fromJson(Map<String, dynamic> json) => PorterModel(
        id: json['id'] as String,
        nama: json['nama'] as String,
        email: json['email'] as String,
        noHp: json['no_hp'] as String,
        statusVerifikasi:
            json['status_verifikasi'] as String? ?? 'menunggu',
        isAktif: json['is_aktif'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        totalSelesai: json['total_selesai'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'email': email,
        'no_hp': noHp,
        'status_verifikasi': statusVerifikasi,
        'is_aktif': isAktif,
        'latitude': latitude,
        'longitude': longitude,
        'total_selesai': totalSelesai,
        'created_at': createdAt?.toIso8601String(),
      };
}
