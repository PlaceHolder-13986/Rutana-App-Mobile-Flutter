import 'package:sqflite/sqflite.dart';

import '../../shared/database/database_helper.dart';
import '../domain/user.dart';
import '../domain/company_access.dart';

class UserRepository {
  Future<List<User>> usersForCompany(User requester) async {
    if (!CompanyAccess.canPlan(requester)) return [];
    final db = await DatabaseHelper.openDb();
    final useRuc = requester.ruc.trim().isNotEmpty;
    final rows = await db.query(
      'users',
      columns: ['id', 'full_name', 'email', 'phone', 'company', 'ruc', 'role'],
      where: useRuc
          ? 'TRIM(ruc) = ?'
          : "TRIM(COALESCE(ruc, '')) = '' AND TRIM(company) = ?",
      whereArgs: [CompanyAccess.company(requester)],
    );
    return rows.map((row) => User.fromMap({...row, 'password': ''})).toList();
  }

  Future<User?> signIn(String email, String password) async {
    final db = await DatabaseHelper.openDb();
    final rows = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [CompanyAccess.email(email), password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = User.fromMap(rows.first);
    if (CompanyAccess.accessRemoved(user)) {
      throw const CompanyAccessRevoked();
    }
    return user;
  }

  Future<bool> register(User user) async {
    final db = await DatabaseHelper.openDb();
    try {
      await db.insert(
        'users',
        user.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return true;
    } on DatabaseException {
      return false;
    }
  }
}
