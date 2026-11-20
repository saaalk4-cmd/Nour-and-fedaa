import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/design/art.dart';
import 'package:nourfadaa/core/design/emoji_art.dart';

void main() {
  test('every emoji picture points to an art file in the kit', () {
    for (final e in kEmojiArt.entries) {
      expect(Art.all, contains(e.value), reason: e.key);
    }
    // كل صورة في المكتبة مستخدمة لإيموجي واحد على الأقل.
    expect(Art.pics.toSet().difference(kEmojiArt.values.toSet()), isEmpty);
  });

  test('single, repeated and variation-selector emoji resolve to pictures', () {
    expect(artForEmoji('🍎'), 'let_03');
    expect(artForEmoji('❤️'), 'sec_akhlaq');
    expect(repeatedArt('🍊🍊🍊'), ('pic_orange', 3));
    expect(repeatedArt('🍎🍊'), isNull);
    expect(repeatedArt('سلام'), isNull);
  });

  testWidgets('EmojiPic shows a picture when it can and text otherwise', (t) async {
    await t.pumpWidget(const MaterialApp(home: Column(children: [EmojiPic('🦁', size: 40), EmojiPic('🧩', size: 40)])));
    expect(find.byType(ArtImage), findsOneWidget);
    expect(find.text('🧩'), findsOneWidget);
  });
}
