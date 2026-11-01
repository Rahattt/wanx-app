/// Country flags as regional-indicator emoji ("DE" ↔ 🇩🇪).
abstract final class CountryFlag {
  static const _base = 0x1F1E6; // Regional indicator A.

  static bool _isIndicator(int rune) => rune >= _base && rune <= _base + 25;

  /// ISO code of the first flag emoji in [name], e.g. "🇩🇪 Berlin" → "DE".
  static String? codeFromName(String name) {
    final runes = name.runes.toList();
    for (var i = 0; i + 1 < runes.length; i++) {
      if (_isIndicator(runes[i]) && _isIndicator(runes[i + 1])) {
        return String.fromCharCodes([
          runes[i] - _base + 0x41,
          runes[i + 1] - _base + 0x41,
        ]);
      }
    }
    return null;
  }

  /// "DE" → 🇩🇪. Null for anything that isn't two ASCII letters.
  static String? emoji(String? code) {
    final c = code?.toUpperCase();
    if (c == null || !RegExp(r'^[A-Z]{2}$').hasMatch(c)) return null;
    return String.fromCharCodes(c.codeUnits.map((u) => u - 0x41 + _base));
  }

  /// [name] without any flag emoji (the flag is shown separately), with
  /// the spacing around them collapsed. Unchanged if nothing else is left.
  static String stripFlags(String name) {
    final kept = name.runes.where((r) => !_isIndicator(r));
    final rest = String.fromCharCodes(kept)
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return rest.isEmpty ? name : rest;
  }
}
