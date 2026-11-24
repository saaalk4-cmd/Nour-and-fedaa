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

  /// يغلق الاتصال (للاختبارات).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'buraq.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createChildren(db);
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
  }

  Future<void> _createChildren(Database db) async {
    await db.execute('''
      CREATE TABLE children(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        avatar TEXT NOT NULL DEFAULT 'star',
        birth_year INTEGER NOT NULL,
        birth_month INTEGER NOT NULL,
        band_override TEXT,
        stars INTEGER NOT NULL DEFAULT 0,
        points INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// v2: ملفات الأطفال بلقب وشهر/سنة ميلاد (بدل الاسم والعمر).
  /// التطبيق لم يُنشر بعد، فنعيد إنشاء الجدول بلا ترحيل.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS children');
      await _createChildren(db);
    }
  }
}
