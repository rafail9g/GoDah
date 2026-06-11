class AdminModel {
  final String id;
  final String nama;
  final String email;
  final String role;
  final DateTime? createdAt;

  const AdminModel({
    required this.id,
    required this.nama,
    required this.email,
    this.role = 'admin',
    this.createdAt,
  });

  bool get isSuperAdmin => role == 'superadmin';

  factory AdminModel.fromJson(Map<String, dynamic> json) => AdminModel(
    id: json['id'] as String,
    nama: json['nama'] as String,
    email: json['email'] as String,
    role: json['role'] as String? ?? 'admin',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );
}
