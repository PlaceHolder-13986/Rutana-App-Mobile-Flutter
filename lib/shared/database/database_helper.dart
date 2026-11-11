import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = 'rutana.db';
  static const int _version = 1;

  static Database? _db;

  static Future<Database> openDb() async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), _databaseName),
      version: _version,
      onCreate: (db, version) async {

        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT,
            email TEXT UNIQUE,
            phone TEXT,
            company TEXT,
            ruc TEXT,
            password TEXT,
            role TEXT
          )
        ''');

        // Usuario de prueba
        await db.insert('users', {
          'full_name': 'Juan Pérez',
          'email': 'admin@rutana.com',
          'phone': '999999999',
          'company': 'Empresa S.A.C.',
          'ruc': '20123456789',
          'password': '123456',
          'role': 'Administrator',
        });
      },
    );
    return _db!;
  }
}