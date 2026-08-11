import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _chrome = (0x0C, 0x1B, 0x31);
const _chrome2 = (0x16, 0x29, 0x4A);
const _paper = (0xF8, 0xFA, 0xFC);
const _accent2 = (0x3B, 0x82, 0xF6);

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
      final t = ((x / size) + (y / size)) / 2;
      final c = _lerpColor(_chrome, _chrome2, t.clamp(0.0, 1.0));
      image.setPixelRgba(x, y, c.$1, c.$2, c.$3, 255);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

void _renderFlatIcon(String outPath, {required int size, required double refHalf}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x / size) + (y / size)) / 2;
      final bg = _lerpColor(_chrome, _chrome2, t.clamp(0.0, 1.0));
      final rgba = _glyphPixel(x + 0.5 - center, y + 0.5 - center, refHalf, bg, 255);
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

/// Matches assets/branding/app_icon.svg: a paper "lens" ring (outer circle
/// minus an inner hole showing the background through) plus a small
/// accent-blue "live" dot at the upper right, itself ringed by a sliver of
/// background so it never blends into the lens when the two overlap.
(int, int, int, int) _glyphPixel(double px, double py, double refHalf, (int, int, int) bg, int bgAlpha) {
  var r = bg.$1.toDouble();
  var g = bg.$2.toDouble();
  var b = bg.$3.toDouble();
  var a = bgAlpha.toDouble();

  const k = 1 / 50;
  final lensOuterR = refHalf * 23 * k;
  final lensInnerR = refHalf * 8 * k;
  final dotCx = refHalf * 18.5 * k;
  final dotCy = -refHalf * 18.5 * k;
  final dotBackdropR = refHalf * 7.6 * k;
  final dotR = refHalf * 5.6 * k;

  final distCenter = _dist(px, py, 0, 0);
  final lensCov = _coverage(distCenter - lensOuterR);
  if (lensCov > 0) {
    r = _lerp(r, _paper.$1.toDouble(), lensCov);
    g = _lerp(g, _paper.$2.toDouble(), lensCov);
    b = _lerp(b, _paper.$3.toDouble(), lensCov);
    a = _lerp(a, 255.0, lensCov);
  }

  final holeCov = _coverage(distCenter - lensInnerR);
  if (holeCov > 0) {
    r = _lerp(r, bg.$1.toDouble(), holeCov);
    g = _lerp(g, bg.$2.toDouble(), holeCov);
    b = _lerp(b, bg.$3.toDouble(), holeCov);
    a = _lerp(a, bgAlpha.toDouble(), holeCov);
  }

  final distDot = _dist(px, py, dotCx, dotCy);
  final backdropCov = _coverage(distDot - dotBackdropR);
  if (backdropCov > 0) {
    r = _lerp(r, bg.$1.toDouble(), backdropCov);
    g = _lerp(g, bg.$2.toDouble(), backdropCov);
    b = _lerp(b, bg.$3.toDouble(), backdropCov);
    a = _lerp(a, bgAlpha.toDouble(), backdropCov);
  }

  final dotCov = _coverage(distDot - dotR);
  if (dotCov > 0) {
    r = _lerp(r, _accent2.$1.toDouble(), dotCov);
    g = _lerp(g, _accent2.$2.toDouble(), dotCov);
    b = _lerp(b, _accent2.$3.toDouble(), dotCov);
    a = _lerp(a, 255.0, dotCov);
  }

  return (r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), a.round().clamp(0, 255));
}

(int, int, int) _lerpColor((int, int, int) a, (int, int, int) b, double t) => (
      _lerp(a.$1.toDouble(), b.$1.toDouble(), t).round(),
      _lerp(a.$2.toDouble(), b.$2.toDouble(), t).round(),
      _lerp(a.$3.toDouble(), b.$3.toDouble(), t).round(),
    );

double _dist(double px, double py, double cx, double cy) {
  final dx = px - cx;
  final dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

double _coverage(double signedDistance) => (0.5 - signedDistance).clamp(0.0, 1.0);

double _lerp(double a, double b, double t) => a + (b - a) * t;
