import 'user.dart';

enum CompanyRole {
  administrator('Administrator', 'Administrador'),
  coordinator('Coordinator', 'Coordinador'),
  driver('Driver', 'Conductor'),
  helper('Helper', 'Ayudante');

  const CompanyRole(this.code, this.label);
  final String code, label;

  static CompanyRole? fromCode(String code) {
    for (final role in values) {
      if (role.code == code) return role;
    }
    return null;
  }
}

class CompanyAccessRevoked implements Exception {
  const CompanyAccessRevoked();
}

class CompanyAccess {
  static final _changes = <(String, String), (CompanyRole, bool)>{};

  static String company(User user) =>
      user.ruc.trim().isNotEmpty ? user.ruc.trim() : user.company.trim();

  static String email(String value) => value.trim().toLowerCase();

  static CompanyRole? role(User user) {
    if (company(user).isEmpty) return null;
    final change = _changes[(company(user), email(user.email))];
    if (change != null) return change.$2 ? change.$1 : null;
    return CompanyRole.fromCode(user.role);
  }

  static bool canManage(User? user) =>
      user != null && role(user) == CompanyRole.administrator;
  static bool canPlan(User user) =>
      role(user) == CompanyRole.administrator ||
      role(user) == CompanyRole.coordinator;
  static bool canRead(User user) => role(user) != null;
  static bool accessRemoved(User user) =>
      _changes[(company(user), email(user.email))]?.$2 == false;

  static void update(
    User user,
    String memberEmail,
    CompanyRole role,
    bool active,
  ) {
    _changes[(company(user), email(memberEmail))] = (role, active);
  }
}
