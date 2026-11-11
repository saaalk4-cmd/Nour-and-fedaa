import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// قاعدة البيانات المحلية (تعمل بدون إنترنت).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'nourfadaa.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE children(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        stars INTEGER NOT NULL DEFAULT 0,
        points INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE progress(
        child_id INTEGER NOT NULL,
        lesson_id TEXT NOT NULL,
        status TEXT NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        PRIMARY KEY(child_id, lesson_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE badges(
        child_id INTEGER NOT NULL,
        badge_id TEXT NOT NULL,
        earned_at TEXT NOT NULL,
        PRIMARY KEY(child_id, badge_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE usage_log(
        child_id INTEGER NOT NULL,
        day TEXT NOT NULL,
        seconds INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(child_id, day)
      )
    ''');

    // ملفا الطفلتين
    await db.insert('children', {'name': 'فداء', 'age': 5});
    await db.insert('children', {'name': 'نور', 'age': 3});
  }
}
