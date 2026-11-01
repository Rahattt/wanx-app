import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/licenses.dart';

void main() {
  registerNativeLicenses();
  runApp(const ProviderScope(child: WanXApp()));
}
