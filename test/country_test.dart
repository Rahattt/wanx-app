import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/features/servers/domain/country.dart';

void main() {
  test('reads the first flag emoji from a name', () {
    expect(CountryFlag.codeFromName('🇩🇪 Frankfurt 01'), 'DE');
    expect(CountryFlag.codeFromName('Fast | 🇳🇱 Amsterdam'), 'NL');
    expect(CountryFlag.codeFromName('Helsinki'), isNull);
  });

  test('builds the emoji from an ISO code', () {
    expect(CountryFlag.emoji('fi'), '🇫🇮');
    expect(CountryFlag.emoji('XYZ'), isNull);
    expect(CountryFlag.emoji(null), isNull);
  });

  test('strips every flag so it is not shown twice', () {
    expect(CountryFlag.stripFlags('🇩🇪  Frankfurt'), 'Frankfurt');
    expect(CountryFlag.stripFlags('Fast | 🇳🇱 Amsterdam'), 'Fast | Amsterdam');
    expect(CountryFlag.stripFlags('Oslo 🇳🇴'), 'Oslo');
    expect(CountryFlag.stripFlags('🇩🇪'), '🇩🇪');
  });
}
