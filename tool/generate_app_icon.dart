import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _paper = (0xEE, 0xF1, 0xF5);
const _chrome = (0x0C, 0x1B, 0x31);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  _renderBackground('assets/icon/icon_background.png', size: 1024);
  _renderFlatIcon('assets/icon/icon.png', size: 1024, refHalf: 512);
  _renderForeground('assets/icon/icon_foreground.png', size: 1024, refHalf: 512 * 0.78);

  stdout.writeln('Wrote icon_background.png, icon.png and icon_foreground.png to assets/icon/');
}

void _renderBackground(String outPath, {required int size}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixelRgba(x, y, _paper.$1, _paper.$2, _paper.$3, 255);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

void _renderFlatIcon(String outPath, {required int size, required double refHalf}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  final cornerRadius = size * 0.22;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final px = x + 0.5 - center;
      final py = y + 0.5 - center;
      final insideRounded = _roundedRectCoverage(px, py, center, cornerRadius);
      var rgba = _glyphPixel(px, py, refHalf, _paper, 255);
      if (insideRounded < 1) {
        rgba = (rgba.$1, rgba.$2, rgba.$3, (rgba.$4 * insideRounded).round().clamp(0, 255));
      }
      image.setPixelRgba(x, y, rgba.$1, rgba.$2, rgba.$3, rgba.$4);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

void _renderForeground(String outPath, {required int size, required double refHalf}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final rgba = _glyphPixel(x + 0.5 - center, y + 0.5 - center, refHalf, (0, 0, 0), 0);
      image.setPixelRgba(x, y, rgba.$1, rgba.$2, rgba.$3, rgba.$4);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

/// Matches assets/branding/app_icon.svg: two equal circles side by side — the
/// left one solid, the right one a ring — with the ring's hole punched
/// through the union of both so it stays a clean window regardless of the
/// left circle's overlap.
(int, int, int, int) _glyphPixel(double px, double py, double refHalf, (int, int, int) bg, int bgAlpha) {
  var r = bg.$1.toDouble();
  var g = bg.$2.toDouble();
  var b = bg.$3.toDouble();
  var a = bgAlpha.toDouble();

  const k = 1 / 50;
  final markR = refHalf * 27.54 * k;
  final holeR = refHalf * 17.9 * k;
  final halfDistance = refHalf * 11.82 * k;

  final distLeft = _dist(px, py, -halfDistance, 0);
  final leftCov = _coverage(distLeft - markR);
  if (leftCov > 0) {
    r = _lerp(r, _chrome.$1.toDouble(), leftCov);
    g = _lerp(g, _chrome.$2.toDouble(), leftCov);
    b = _lerp(b, _chrome.$3.toDouble(), leftCov);
    a = _lerp(a, 255.0, leftCov);
  }

  final distRight = _dist(px, py, halfDistance, 0);
  final rightCov = _coverage(distRight - markR);
  if (rightCov > 0) {
    r = _lerp(r, _chrome.$1.toDouble(), rightCov);
    g = _lerp(g, _chrome.$2.toDouble(), rightCov);
    b = _lerp(b, _chrome.$3.toDouble(), rightCov);
    a = _lerp(a, 255.0, rightCov);
  }

  final holeCov = _coverage(distRight - holeR);
  if (holeCov > 0) {
    r = _lerp(r, bg.$1.toDouble(), holeCov);
    g = _lerp(g, bg.$2.toDouble(), holeCov);
    b = _lerp(b, bg.$3.toDouble(), holeCov);
    a = _lerp(a, bgAlpha.toDouble(), holeCov);
  }

  return (r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), a.round().clamp(0, 255));
}

/// Standard rounded-box signed-distance field: negative inside, positive
/// outside, 0 at the boundary. Converted to a 0..1 coverage via the same
/// half-pixel falloff used for every circle above.
double _roundedRectCoverage(double px, double py, double half, double cornerRadius) {
  final qx = px.abs() - half + cornerRadius;
  final qy = py.abs() - half + cornerRadius;
  final outside = _dist(math.max(qx, 0.0), math.max(qy, 0.0), 0, 0);
  final inside = math.min(math.max(qx, qy), 0.0);
  final signedDistance = outside + inside - cornerRadius;
  return _coverage(signedDistance);
}

double _dist(double px, double py, double cx, double cy) {
  final dx = px - cx;
  final dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

double _coverage(double signedDistance) => (0.5 - signedDistance).clamp(0.0, 1.0);

double _lerp(double a, double b, double t) => a + (b - a) * t;
