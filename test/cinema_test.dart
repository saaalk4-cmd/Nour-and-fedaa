import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/features/intro/cinema_painter.dart';

void main() {
  test('seven shots cover the 45 seconds exactly', () {
    expect(kCinemaShots.first, 0);
    expect(kCinemaShots.last, kCinemaSeconds);
    expect(kCinemaShots.length, 8);
    for (var i = 1; i < kCinemaShots.length; i++) {
      expect(kCinemaShots[i], greaterThan(kCinemaShots[i - 1]));
    }
    expect(cinemaShotAt(0), 1);
    expect(cinemaShotAt(7), 2);
    expect(cinemaShotAt(12), 3);
    expect(cinemaShotAt(20), 4);
    expect(cinemaShotAt(25), 5);
    expect(cinemaShotAt(33), 6);
    expect(cinemaShotAt(44.9), 7);
  });

  test('ramp is clamped to 0..1', () {
    expect(cinemaRamp(-3, 0, 5), 0);
    expect(cinemaRamp(9, 0, 5), 1);
    expect(cinemaRamp(2.5, 0, 5), 0.5);
  });

  test('every frame paints without throwing, on phone and tablet sizes', () {
    for (final size in const [Size(360, 640), Size(320, 480), Size(800, 1280)]) {
      for (var t = 0.0; t <= kCinemaSeconds; t += 1.5) {
        final rec = PictureRecorder();
        CinemaPainter(t).paint(Canvas(rec), size);
        rec.endRecording();
      }
    }
  });
}
