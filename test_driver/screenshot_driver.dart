import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of `integration_test/screenshots_test.dart`: writes each
/// screenshot to `build/screenshots/<name>.png`. See scripts/screenshots.sh.
Future<void> main() => integrationDriver(
  // Keep the screenshots taken before a failure.
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final shots = Map<String, dynamic>.from(data?['screenshots'] as Map? ?? {});
    for (final MapEntry(:key, :value) in shots.entries) {
      final file = File('build/screenshots/$key.png');
      await file.create(recursive: true);
      await file.writeAsBytes(base64Decode(value as String));
    }
  },
);
