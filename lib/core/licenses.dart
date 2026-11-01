import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licenses of native components (not Dart packages) to the
/// Flutter license page.
void registerNativeLicenses() {
  LicenseRegistry.addLicense(() async* {
    // The core is built from sing-box-lx, a sing-box fork under the same license.
    yield const LicenseEntryWithLineBreaks([
      'sing-box',
      'sing-box-lx',
    ], _singBox);
    // Dependencies the core links from sing-box-lx's forks, under their own
    // licenses (texts copied from the forks' LICENSE files).
    for (final (packages, file) in _coreDependencies) {
      yield LicenseEntryWithLineBreaks(
        packages,
        await rootBundle.loadString('assets/licenses/$file'),
      );
    }
  });
}

const _coreDependencies = [
  (['utls'], 'utls.txt'),
  (['gVisor'], 'gvisor.txt'),
  (['wireguard-go', 'AmneziaWG'], 'wireguard-go.txt'),
];

// From https://github.com/SagerNet/sing-box/blob/main/LICENSE
const _singBox = '''
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

In addition, no derivative work may use the name or imply association
with this application without prior consent.''';
