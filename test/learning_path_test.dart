import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/curriculum.dart';
import 'package:nourfadaa/data/content/lesson.dart';
import 'package:nourfadaa/features/path/learning_path_screen.dart';

void main() {
  final all = <Lesson>[
    for (final a in ContentRepository.lessonAssets)
      ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];
  final curriculum = Curriculum.parse(File(curriculumAsset).readAsStringSync());

  PathWeek path(int age, Set<String> done) =>
      curriculum.pathFor(childAge: age, allLessons: all, completed: done);

  List<PathNode> nodes(PathWeek p) => [for (final d in p.days) ...d.nodes];

  test('a new child starts at week 1 with exactly one current node, the rest locked', () {
    for (final age in [3, 5]) {
      final p = path(age, {});
      expect(p.finishedAll, isFalse);
      expect(p.week!.week, 1);
      final ns = nodes(p);
      expect(ns, isNotEmpty);
      expect(ns.where((n) => n.state == PathState.done), isEmpty);
      expect(ns.where((n) => n.state == PathState.current).length, 1);
      expect(ns.first.state, PathState.current);
      expect(ns.skip(1).every((n) => n.state == PathState.locked), isTrue);
    }
  });

  test('finishing a node moves the current marker to the next one', () {
    final p0 = path(5, {});
    final ns = nodes(p0);
    final p1 = path(5, {ns[0].lesson.id});
    final n1 = nodes(p1);
    expect(n1[0].state, PathState.done);
    expect(n1[1].state, PathState.current);
    expect(p1.current!.id, ns[1].lesson.id);
  });

  test('the whole week is shown grouped by days, and each day has its gift', () {
    final p = path(5, {});
    expect(p.days.length, greaterThanOrEqualTo(3));
    final first = p.days.first;
    expect(first.complete, isFalse);
    final done = {for (final n in first.nodes) n.lesson.id};
    final after = path(5, done);
    expect(after.days.first.complete, isTrue);
    expect(after.days.first.nodes.every((n) => n.state == PathState.done), isTrue);
    expect(after.days[1].nodes.first.state, PathState.current);
    expect(after.days[1].complete, isFalse);
  });

  test('strict order: every week reads done* current locked* all the way through', () {
    for (final age in [3, 5]) {
      final done = <String>{};
      var steps = 0;
      while (true) {
        final p = path(age, done);
        if (p.finishedAll) break;
        final seq = nodes(p).map((n) => n.state).toList();
        final cur = seq.indexOf(PathState.current);
        expect(cur, isNonNegative);
        expect(seq.take(cur).every((s) => s == PathState.done), isTrue);
        expect(seq.skip(cur + 1).every((s) => s == PathState.locked), isTrue);
        done.add(p.current!.id);
        expect(++steps, lessThan(1000), reason: 'walk must terminate');
      }
      expect(steps, greaterThan(50));
    }
  });

  test('nodes always fit the child\'s age; little ones get the picture track', () {
    final p = path(3, {});
    for (final n in nodes(p)) {
      expect(n.lesson.fitsAge(3), isTrue, reason: n.lesson.id);
    }
  });

  test('finishing everything shows the last week, all done, no current', () {
    final done = <String>{};
    while (true) {
      final p = path(5, done);
      if (p.finishedAll) {
        expect(p.current, isNull);
        expect(p.week, isNotNull);
        expect(nodes(p).every((n) => n.state == PathState.done), isTrue);
        expect(p.days.every((d) => d.complete), isTrue);
        break;
      }
      done.add(p.current!.id);
    }
  });

  test('the path agrees with today\'s plan (same current day)', () {
    final done = <String>{};
    for (var i = 0; i < 40; i++) {
      final plan = curriculum.planFor(childAge: 5, allLessons: all, completed: done);
      final p = path(5, done);
      if (plan.finishedAll) break;
      expect(p.week!.week, plan.week!.week);
      expect(p.current!.id, plan.adventures.firstWhere((l) => !done.contains(l.id)).id);
      done.add(p.current!.id);
    }
  });

  test('spoken phrases are short, gentle and free of banned words', () {
    for (final s in [kPathLockedSay, kPathGiftLockedSay]) {
      expect(s.split(' ').length, lessThanOrEqualTo(6));
      for (final bad in ['فشل', 'خطأ', 'خسر', 'سيئة']) {
        expect(s.contains(bad), isFalse, reason: s);
      }
    }
  });
}
