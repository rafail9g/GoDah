import '../../core/utils/string_utils.dart';

class UserModel {
  final String id;
  final String nama;
  final String email;
  final String noHp;
  final String? alamat;
  final String status;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.noHp,
    this.alamat,
    this.status = 'aktif',
    this.createdAt,
  });

  String get initials => StringUtils.initials(nama);

  String get formattedPhone => StringUtils.formatPhoneDisplay(noHp);

  bool get isActive => status == 'aktif';


  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:          json['id'] as String,
    nama:        json['nama'] as String,
    email:       json['email'] as String,
    noHp:        json['no_hp'] as String,
    alamat:      json['alamat'] as String?,
    status:      json['status'] as String? ?? 'aktif',
    createdAt:   json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'nama':        nama,
    'email':       email,
    'no_hp':       noHp,
    'alamat':      alamat,
    'status':      status,
    'created_at':  createdAt?.toIso8601String(),
  };

  UserModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? noHp,
    String? alamat,
    String? status,
    DateTime? createdAt,
  }) =>
      UserModel(
        id:         id         ?? this.id,
        nama:       nama       ?? this.nama,
        email:      email      ?? this.email,
        noHp:       noHp       ?? this.noHp,
        alamat:     alamat     ?? this.alamat,
        status:     status     ?? this.status,
        createdAt:  createdAt  ?? this.createdAt,
      );

  @override
  String toString() => 'UserModel(id: $id, nama: $nama, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
