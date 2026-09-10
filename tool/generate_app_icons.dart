import 'dart:io';

import 'package:image/image.dart' as image;

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_app_icons.dart <source> <root>',
    );
    exitCode = 64;
    return;
  }
  final source = image.decodeImage(File(arguments[0]).readAsBytesSync());
  if (source == null) {
    throw StateError('The source image is not a valid image.');
  }
  final root = arguments[1];

  _write(source, '$root/android/play_store_app_icon_512.png', 512);

  const androidSizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in androidSizes.entries) {
    _write(
      source,
      '$root/android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      entry.value,
    );
  }

  const iosSizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in iosSizes.entries) {
    _write(
      source,
      '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
      entry.value,
    );
  }
}

void _write(image.Image source, String path, int size) {
  final resized = image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
  File(path).writeAsBytesSync(image.encodePng(resized));
}
