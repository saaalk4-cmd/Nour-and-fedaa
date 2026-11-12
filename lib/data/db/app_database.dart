import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  /// للاختبارات فقط: يغلق القاعدة ويحذفها لبدء حالة نظيفة.
  Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
    final dir = await getDatabasesPath();
    await deleteDatabase(p.join(dir, 'nourfadaa.db'));
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(p.join(dir, 'nourfadaa.db'), version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE children(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,age INTEGER NOT NULL,stars INTEGER NOT NULL DEFAULT 0,points INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE progress(child_id INTEGER NOT NULL,lesson_id TEXT NOT NULL,status TEXT NOT NULL,score INTEGER NOT NULL DEFAULT 0,completed_at TEXT,PRIMARY KEY(child_id, lesson_id))');
    await db.execute('CREATE TABLE badges(child_id INTEGER NOT NULL,badge_id TEXT NOT NULL,earned_at TEXT NOT NULL,PRIMARY KEY(child_id, badge_id))');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    await db.execute('CREATE TABLE usage_log(child_id INTEGER NOT NULL,day TEXT NOT NULL,seconds INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(child_id, day))');
    await db.execute('CREATE TABLE gamification(child_id INTEGER PRIMARY KEY,xp INTEGER NOT NULL DEFAULT 0,stars INTEGER NOT NULL DEFAULT 0,streak_days INTEGER NOT NULL DEFAULT 0,daily_quests_completed INTEGER NOT NULL DEFAULT 0,total_lessons INTEGER NOT NULL DEFAULT 0,last_active_day TEXT,best_streak INTEGER NOT NULL DEFAULT 0)');
    await db.execute(_dailyQuestsSql);
    await db.insert('children', {'name':'فداء','age':5});
    await db.insert('children', {'name':'نور','age':3});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS gamification(child_id INTEGER PRIMARY KEY,xp INTEGER NOT NULL DEFAULT 0,stars INTEGER NOT NULL DEFAULT 0,streak_days INTEGER NOT NULL DEFAULT 0,daily_quests_completed INTEGER NOT NULL DEFAULT 0,total_lessons INTEGER NOT NULL DEFAULT 0)');
    }
    if (oldVersion < 3) {
      // آخر يوم نشاط + أفضل سلسلة أيام (للـ Streak).
      await db.execute('ALTER TABLE gamification ADD COLUMN last_active_day TEXT');
      await db.execute('ALTER TABLE gamification ADD COLUMN best_streak INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute(_dailyQuestsSql);
    }
  }

  // مهام اليوم (صف لكل مهمة + صف _bonus للمكافأة اليومية).
  static const String _dailyQuestsSql =
      'CREATE TABLE IF NOT EXISTS daily_quests(child_id INTEGER NOT NULL,day TEXT NOT NULL,quest_id TEXT NOT NULL,progress INTEGER NOT NULL DEFAULT 0,target INTEGER NOT NULL,PRIMARY KEY(child_id, day, quest_id))';
}