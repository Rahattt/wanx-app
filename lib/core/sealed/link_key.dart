import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Opens encrypted `wanx://crypt1/…` links (see `encryptLink` in
/// packages/wanx_sealed). The server holds only the public half
/// (WANX_LINK_KEY). Made once with `dart run bin/linkkey.dart` in
/// `server/`; changing it breaks every link already handed out.
///
/// The private half is not in the source: release builds pass it with
/// `--dart-define-from-file=keys.json` (git-ignored, see keys.example.json).
/// Without it, `wanx://` links fail to open; everything else works.
abstract final class LinkKey {
  static const _privateKey = String.fromEnvironment('WANX_LINK_PRIVATE_KEY');

  static bool get available => _test != null || _privateKey.isNotEmpty;

  static Uint8List get privateKey => _test?.$1 ?? _built;
  static Uint8List get publicKey => _test?.$2 ?? _public;

  static final _built = Uint8List.fromList(base64.decode(_privateKey));
  static final _public = Uint8List.fromList(
    base64.decode(
      'BMUEFqMtRGvZfn+P5gy+oEfZG5QahNn4S+C8H9ReNvXVvJEzCiTmcwY80OiJo2P7NNtMIRo9jS/YFKJ5Ljzgnc8=',
    ),
  );

  static (Uint8List, Uint8List)? _test;

  /// A throwaway key pair, so tests run without the release key.
  @visibleForTesting
  static set testKeys((Uint8List, Uint8List)? keys) => _test = keys;
}
