
class User {
  final int? id;
  final String fullName;
  final String email;
  final String phone;
  final String company;
  final String ruc;
  final String password;
  final String role;

  const User({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.company,
    required this.ruc,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'company': company,
      'ruc': ruc,
      'password': password,
      'role': role,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      company: map['company'] as String? ?? '',
      ruc: map['ruc'] as String? ?? '',
      password: map['password'] as String,
      role: map['role'] as String,
    );
  }
}
