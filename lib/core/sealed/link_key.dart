import 'dart:convert';
import 'dart:typed_data';

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

  static bool get available => _privateKey.isNotEmpty;

  static final privateKey = Uint8List.fromList(base64.decode(_privateKey));
  static final publicKey = Uint8List.fromList(
    base64.decode(
      'BMUEFqMtRGvZfn+P5gy+oEfZG5QahNn4S+C8H9ReNvXVvJEzCiTmcwY80OiJo2P7NNtMIRo9jS/YFKJ5Ljzgnc8=',
    ),
  );
}
