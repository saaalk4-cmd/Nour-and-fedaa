import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/voice_service.dart';
import 'package:nourfadaa/data/content/content_repository.dart';
import 'package:nourfadaa/data/content/emoji_words.dart';

/// الصورة وحدها لا تُسمع: كل اختيار هو صورة واحدة لازم يكون له اسم يُقال،
/// والصور المكررة (🍎🍎🍎) تُقال «الاختيار الأول…» حتى لا نكشف إجابة العدّ.
void main() {
  final lessons = [
    for (final a in ContentRepository.lessonAssets) ...ContentRepository.parseLessons(File(a).readAsStringSync()),
  ];

  bool repeated(String o) {
    final u = o.replaceAll('\u{FE0F}', '').replaceAll(' ', '').runes.toList();
    return u.length > 1 && u.toSet().length == 1;
  }

  test('every picture-only answer has a spoken name', () {
    var pictures = 0;
    for (final l in lessons) {
      for (final q in l.questions) {
        for (final o in [...q.options, ...q.matchLeft, ...q.matchRight]) {
          if (VoiceService.clean(o).isNotEmpty || repeated(o)) continue;
          pictures++;
          expect(emojiWord(o), isNotNull, reason: '${l.id}: "$o" has no spoken name');
        }
      }
    }
    expect(pictures, greaterThan(1000));
  });

  test('names are plain Arabic words, and counting pictures are not named', () {
    for (final w in kEmojiWords.values) {
      expect(RegExp('^[؀-ۿ ]+\$').hasMatch(w), isTrue, reason: w);
    }
    expect(emojiWord('🐘'), 'فيل');
    expect(emojiWord('❤️'), 'قلب');
    expect(emojiWord('🍎🍎🍎'), isNull);
  });
}
