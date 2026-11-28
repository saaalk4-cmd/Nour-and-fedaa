import 'package:buraq/data/repositories/lesson_repository.dart';
import 'package:buraq/data/repositories/session_repository.dart';
import 'package:buraq/domain/age_band.dart';
import 'package:buraq/domain/course_session.dart';
import 'package:buraq/domain/lesson.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buraem year: 70 sessions of two lessons over 7 units of 10', () async {
    final all = await SessionRepository().forBand(AgeBand.buraem);
    expect(all.length, 70);
    expect(all.every((s) => s.lessons.length == 2), isTrue);
    for (var u = 1; u <= 7; u++) {
      expect(all.where((s) => s.unit == u).length, 10, reason: 'unit $u');
    }
    // الدرس الأول قرآن دائمًا، والسور السبع كلها مغطاة.
    final repo = LessonRepository();
    final surahs = <int>{};
    for (final s in all) {
      final q = await repo.byId(s.lessons[0]);
      expect(q.sourceType, 'quran', reason: q.id);
      surahs.addAll(q.steps.where((x) => x.type == StepType.surah).map((x) => x.surah));
    }
    expect(surahs, {1, 112, 113, 114, 108, 103, 110});
  });

  test('buraem year lessons: text-free, valid, audio files exist when linked',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    final all = await SessionRepository().forBand(AgeBand.buraem);
    final repo = LessonRepository();
    final letters = <String>{};
    for (final s in all) {
      for (final id in s.lessons) {
        final l = await repo.byId(id);
        expect(l.band, AgeBand.buraem);
        expect(l.textFreeForChild, isTrue);
        expect(l.steps.last.type, StepType.reward);
        for (final st in l.steps) {
          if (st.audio != null) {
            expect(assets.contains(st.audio), isTrue, reason: '$id ${st.audio}');
            expect(l.audioLicense, isNotNull, reason: id);
          }
          if (st.type == StepType.choose) {
            expect(st.options.toSet().length, st.options.length, reason: id);
          }
        }
        if (l.title.startsWith('صوت ')) letters.add(l.title.substring(4));
      }
    }
    expect(letters.length, 28);
  });

  test('today session: first unfinished, then the last when all done', () {
    const a = CourseSession(n: 1, unit: 1, unitTitle: 'u', lessons: ['x', 'y']);
    const b = CourseSession(n: 2, unit: 1, unitTitle: 'u', lessons: ['z', 'w']);
    expect(pickTodaySession([a, b], {})!.n, 1);
    expect(pickTodaySession([a, b], {'x'})!.n, 1);
    expect(pickTodaySession([a, b], {'x', 'y'})!.n, 2);
    expect(pickTodaySession([a, b], {'x', 'y', 'z', 'w'})!.n, 2);
    expect(pickTodaySession([], {}), isNull);
  });

  test('session numbering must be continuous', () {
    expect(
        () => CourseSession.listFromJsonString(
            '{"sessions":[{"n":2,"unit":1,"unit_title":"u","lessons":["a"]}]}'),
        throwsFormatException);
  });
}
