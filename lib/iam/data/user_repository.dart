import 'package:sqflite/sqflite.dart';

import '../../shared/database/database_helper.dart';
import '../domain/user.dart';

class UserRepository {
  Future<List<User>> driversForCompany(User requester) async {
    if (requester.role != 'Administrator') return [];
    final db = await DatabaseHelper.openDb();
    final useRuc = requester.ruc.trim().isNotEmpty;
    final rows = await db.query(
      'users',
      where: useRuc ? 'role = ? AND ruc = ?' : 'role = ? AND company = ?',
      whereArgs: [
        'Driver',
        useRuc ? requester.ruc.trim() : requester.company.trim(),
      ],
    );
    return rows.map(User.fromMap).toList();
  }

  Future<User?> signIn(String email, String password) async {
    final db = await DatabaseHelper.openDb();
    final rows = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
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
