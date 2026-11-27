import 'dart:io';

import 'package:buraq/data/db/app_database.dart';
import 'package:buraq/data/repositories/child_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v4 database upgrades to v5 and existing children get cloud ids', () async {
    final dir = Directory.systemTemp.createTempSync('buraq_mig').path;
    await databaseFactory.setDatabasesPath(dir);
    await AppDatabase.instance.close();
    // قاعدة بإصدار ٤ (قبل cloud_id) فيها طفل
    final old = await databaseFactory.openDatabase(p.join(dir, 'buraq.db'),
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE children(
              id INTEGER PRIMARY KEY AUTOINCREMENT, nickname TEXT NOT NULL,
              avatar TEXT NOT NULL DEFAULT 'star', birth_year INTEGER NOT NULL,
              birth_month INTEGER NOT NULL, band_override TEXT,
              stars INTEGER NOT NULL DEFAULT 0, points INTEGER NOT NULL DEFAULT 0)''');
            await db.insert('children',
                {'nickname': 'قديم', 'birth_year': 2019, 'birth_month': 1});
          },
        ));
    await old.close();

    final c = (await ChildRepository().all()).single;
    expect(c.nickname, 'قديم');
    expect(c.cloudId, hasLength(32));
  });
}
