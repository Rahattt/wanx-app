// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusDisconnecting => 'Disconnecting…';

  @override
  String get statusFailed => 'Connection failed';

  @override
  String get statusDisconnected => 'Not connected';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String perSecond(String value) {
    return '$value/s';
  }

  @override
  String get checkRunning => 'Checking connection…';

  @override
  String get checkFailed => 'No response — server is not reachable';

  @override
  String checkOk(int ms) {
    return 'Server is alive · $ms ms';
  }

  @override
  String get addServer => 'Add server';

  @override
  String get settings => 'Settings';

  @override
  String failedToLoad(String error) {
    return 'Failed to load servers: $error';
  }

  @override
  String get groupManual => 'Manual';

  @override
  String updatedAgo(String ago) {
    return 'Updated $ago';
  }

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n d ago';
  }

  @override
  String noResponseWithin(String name) {
    return '$name: no response within 5 s';
  }

  @override
  String serverError(String name, String error) {
    return '$name: $error';
  }

  @override
  String serversResponded(int ok, int total) {
    return '$ok of $total servers responded';
  }

  @override
  String deletedServer(String name) {
    return 'Deleted $name';
  }

  @override
  String get undo => 'Undo';

  @override
  String deleteSubscriptionTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteSubscriptionBody =>
      'The subscription and all its servers will be removed.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get noSubscriptionsToRefresh => 'No subscriptions to refresh';

  @override
  String subscriptionsUpdated(int count, int servers) {
    return 'Subscriptions updated: $count, servers: $servers';
  }

  @override
  String get noServersTitle => 'No servers yet';

  @override
  String get noServersBody =>
      'Add one from a share link, a QR code or a subscription URL.';

  @override
  String get swipeTest => 'Test';

  @override
  String get swipeEdit => 'Edit';

  @override
  String get serverDetails => 'Server details';

  @override
  String get latencyFailed => 'failed';

  @override
  String get testServers => 'Test servers';

  @override
  String get refreshSubscription => 'Refresh subscription';

  @override
  String get subscriptionActions => 'Subscription actions';

  @override
  String get deleteSubscription => 'Delete subscription';

  @override
  String get importAction => 'Import';

  @override
  String get subscriptionExists => 'This subscription is already added';

  @override
  String groupExists(String name) {
    return 'A group named “$name” already exists';
  }

  @override
  String importFailed(String reason) {
    return 'Couldn’t import: $reason';
  }

  @override
  String get scanQrTitle => 'Scan QR code';

  @override
  String get cameraDenied =>
      'Camera access is off. Allow it in Settings to scan QR codes.';

  @override
  String cameraUnavailable(String reason) {
    return 'Camera unavailable: $reason';
  }

  @override
  String get startingCamera => 'Starting camera…';

  @override
  String get pointCamera => 'Point the camera at a QR code with a server link';

  @override
  String get sectionServer => 'Server';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldPort => 'Port';

  @override
  String get sectionTransport => 'Transport';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldServiceName => 'Service name';

  @override
  String get fieldPath => 'Path';

  @override
  String get fieldHostHeader => 'Host header';

  @override
  String get fieldXhttpMode => 'Mode';

  @override
  String get fieldPrivateKey => 'Private key';

  @override
  String get fieldAddresses => 'Addresses';

  @override
  String get fieldPeerPublicKey => 'Server public key';

  @override
  String get fieldPresharedKey => 'Preshared key';

  @override
  String get wgObfuscation => 'WireGuard obfuscation';

  @override
  String get wgObfuscationHint =>
      'Junk packets and a DNS decoy before the handshake, as in Amnezia. Works with any WireGuard server';

  @override
  String get wgObfuscationAmneziaServer =>
      'Set by this AmneziaWG server, can\'t be turned off';

  @override
  String get xrayFragmentation => 'Fragmentation (Xray)';

  @override
  String get xrayFragmentationHint =>
      'Splits the first packets to the server like Xray\'s \"fragment\". Replaces TLS fragmentation';

  @override
  String get xrayPacketsHint => 'tlshello or a range of writes, e.g. 1-3';

  @override
  String get xrayLengthHint => 'Piece size in bytes, e.g. 100-200';

  @override
  String get xrayIntervalHint => 'Pause in ms, e.g. 10-20; empty = no pause';

  @override
  String get xrayRangeInvalid => 'Use N or N-M';

  @override
  String get sectionTls => 'TLS';

  @override
  String get useTls => 'Use TLS';

  @override
  String get tlsAlwaysOnQuic => 'Always on for QUIC protocols';

  @override
  String get fieldSni => 'SNI';

  @override
  String get sniHint => 'Defaults to the server address';

  @override
  String get fieldAlpn => 'ALPN';

  @override
  String get alpnHint => 'Comma-separated, e.g. h2,http/1.1';

  @override
  String get allowInsecure => 'Allow insecure';

  @override
  String get allowInsecureHint => 'Skip certificate verification';

  @override
  String get save => 'Save';

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedHint => 'uTLS fingerprint, fragmentation, Reality';

  @override
  String get utlsFingerprint => 'uTLS fingerprint';

  @override
  String get tlsFragmentation => 'TLS fragmentation';

  @override
  String get tlsFragmentationHint =>
      'Split the ClientHello across TCP segments';

  @override
  String get recordFragmentation => 'Record fragmentation';

  @override
  String get recordFragmentationHint =>
      'Also split it into multiple TLS records';

  @override
  String get fallbackDelay => 'Fallback delay, ms';

  @override
  String get fallbackDelayHint => 'Empty = automatic';

  @override
  String get reality => 'Reality';

  @override
  String get publicKey => 'Public key';

  @override
  String get shortId => 'Short ID';

  @override
  String get optional => 'Optional';

  @override
  String get required => 'Required';

  @override
  String get portRange => 'Port must be 1–65535';

  @override
  String get realityNeedsTls => 'Reality requires TLS to be enabled';

  @override
  String get realityNeedsKey => 'Reality needs a public key (Advanced section)';

  @override
  String get saved => 'Saved';

  @override
  String fromProvider(String group) {
    return 'From “$group” · refreshing the subscription resets changes';
  }

  @override
  String get addedManually => 'Added manually';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionConnection => 'Connection';

  @override
  String get dnsServer => 'DNS server';

  @override
  String get dnsAdguard => 'AdGuard — blocks ads';

  @override
  String get ipMode => 'IP version';

  @override
  String get ipModeHint =>
      'Only if your server supports IPv6, otherwise sites may not open';

  @override
  String get ipModeV4 => 'IPv4 only';

  @override
  String get ipModeDual => 'IPv4 and IPv6';

  @override
  String get ipModeV6 => 'IPv6 only';

  @override
  String get splitTunnel => 'Per-app VPN';

  @override
  String get splitAll => 'All apps';

  @override
  String get splitOnly => 'Only selected';

  @override
  String get splitBypass => 'All except selected';

  @override
  String get splitHintOff => 'Every app uses the VPN.';

  @override
  String get splitHintOnly =>
      'Only the selected apps use the VPN; the rest connect directly.';

  @override
  String get splitHintBypass =>
      'The selected apps connect directly, bypassing the VPN.';

  @override
  String get splitEmptyOnly => 'Until you select apps, every app uses the VPN.';

  @override
  String get splitValueAll => 'All';

  @override
  String splitValueOnly(int count) {
    return 'Only $count';
  }

  @override
  String splitValueBypass(int count) {
    return 'Except $count';
  }

  @override
  String get premiumDeviceRemoved =>
      'The provider has restricted access for this device';

  @override
  String get premiumRevoked => 'The provider has revoked this subscription';

  @override
  String get premiumUnknown => 'This subscription no longer exists';

  @override
  String get premiumDeviceLimit =>
      'This link is already added on the maximum number of devices';

  @override
  String get premiumPlanInactive => 'This provider’s WanX plan is not active';

  @override
  String get premiumCheckOverdue =>
      'Couldn’t verify the subscription — refresh it when you’re online';

  @override
  String get premiumCheckTimeout =>
      'Couldn’t verify the subscription. Try again later.';

  @override
  String get premiumCheckLimit =>
      'No more verification attempts today. Try tomorrow or on another network.';

  @override
  String get noticeTitle => 'Before you start';

  @override
  String get noticeIntro =>
      'WanX is a VPN client: it connects your device to servers from a provider you choose, or your own. Here is what that involves.';

  @override
  String get noticeTraffic =>
      'Your traffic goes to the VPN server you choose, never through WanX, and we don’t log it.';

  @override
  String get noticeLocal =>
      'No accounts, ads, analytics or tracking. Your servers and settings stay on this device.';

  @override
  String get noticeHwid =>
      'When you add a subscription, the app sends its provider a device ID (HWID), the OS and the model so it can limit devices. You can turn this off in Settings.';

  @override
  String get noticeLinks =>
      'Encrypted wanx:// links are checked with the WanX service, directly, through Google Cloud or through your VPN connection, using a key made on this device and, if enabled, the same device details.';

  @override
  String get noticeAgree => 'Agree and continue';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get sourceCode => 'Source code';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get searchApps => 'Search apps';

  @override
  String get noApps => 'No apps found';

  @override
  String get bypassLan => 'Bypass local network';

  @override
  String get bypassLanHint =>
      'Routers, printers and other local devices stay reachable';

  @override
  String get autoConnect => 'Connect on launch';

  @override
  String get autoConnectHint =>
      'Connect to the selected server when the app opens';

  @override
  String get sectionSubscriptions => 'Subscriptions';

  @override
  String get updateOnLaunch => 'Update on launch';

  @override
  String get updateOnLaunchHint =>
      'Refresh all subscriptions when the app opens';

  @override
  String get sendHwid => 'Send device ID (HWID)';

  @override
  String get sendHwidHint =>
      'Lets your provider limit the number of devices per subscription';

  @override
  String get hwidCopied => 'Device ID copied';

  @override
  String get newServer => 'New server';

  @override
  String get serverAdded => 'Server added';

  @override
  String get fieldProtocol => 'Protocol';

  @override
  String get sectionAuth => 'Authentication';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldEncryption => 'Encryption';

  @override
  String get fieldObfsPassword => 'Obfuscation password (Salamander)';

  @override
  String get fieldCongestion => 'Congestion control';

  @override
  String get none => 'None';

  @override
  String get addFromClipboard => 'Import from clipboard';

  @override
  String get addScanQr => 'Scan QR code';

  @override
  String get addEnterLink => 'Enter link';

  @override
  String get addManually => 'Add manually';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get linkHint =>
      'Server link or subscription URL — detected automatically';

  @override
  String get connectionSettingsNote =>
      'Connection settings apply on the next connect.';

  @override
  String get sectionAbout => 'About';

  @override
  String get appVersion => 'App version';

  @override
  String get aboutText =>
      'A fast, private VPN client. No accounts, no ads, no analytics — your servers and settings stay on this device.';

  @override
  String addedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count servers',
      one: 'Added 1 server',
    );
    return '$_temp0';
  }
}
