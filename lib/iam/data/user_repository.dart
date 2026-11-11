import 'package:sqflite/sqflite.dart';

import '../../shared/database/database_helper.dart';
import '../domain/user.dart';

class UserRepository {

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
