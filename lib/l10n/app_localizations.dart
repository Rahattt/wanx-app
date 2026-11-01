import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get statusDisconnecting;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get statusFailed;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusDisconnected;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @perSecond.
  ///
  /// In en, this message translates to:
  /// **'{value}/s'**
  String perSecond(String value);

  /// No description provided for @checkRunning.
  ///
  /// In en, this message translates to:
  /// **'Checking connection…'**
  String get checkRunning;

  /// No description provided for @checkFailed.
  ///
  /// In en, this message translates to:
  /// **'No response — server is not reachable'**
  String get checkFailed;

  /// No description provided for @checkOk.
  ///
  /// In en, this message translates to:
  /// **'Server is alive · {ms} ms'**
  String checkOk(int ms);

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load servers: {error}'**
  String failedToLoad(String error);

  /// No description provided for @groupManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get groupManual;

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago}'**
  String updatedAgo(String ago);

  /// No description provided for @agoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String agoDays(int n);

  /// No description provided for @noResponseWithin.
  ///
  /// In en, this message translates to:
  /// **'{name}: no response within 5 s'**
  String noResponseWithin(String name);

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'{name}: {error}'**
  String serverError(String name, String error);

  /// No description provided for @serversResponded.
  ///
  /// In en, this message translates to:
  /// **'{ok} of {total} servers responded'**
  String serversResponded(int ok, int total);

  /// No description provided for @deletedServer.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String deletedServer(String name);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @deleteSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteSubscriptionTitle(String name);

  /// No description provided for @deleteSubscriptionBody.
  ///
  /// In en, this message translates to:
  /// **'The subscription and all its servers will be removed.'**
  String get deleteSubscriptionBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noSubscriptionsToRefresh.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions to refresh'**
  String get noSubscriptionsToRefresh;

  /// No description provided for @subscriptionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions updated: {count}, servers: {servers}'**
  String subscriptionsUpdated(int count, int servers);

  /// No description provided for @noServersTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get noServersTitle;

  /// No description provided for @noServersBody.
  ///
  /// In en, this message translates to:
  /// **'Add one from a share link, a QR code or a subscription URL.'**
  String get noServersBody;

  /// No description provided for @swipeTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get swipeTest;

  /// No description provided for @swipeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get swipeEdit;

  /// No description provided for @serverDetails.
  ///
  /// In en, this message translates to:
  /// **'Server details'**
  String get serverDetails;

  /// No description provided for @latencyFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get latencyFailed;

  /// No description provided for @testServers.
  ///
  /// In en, this message translates to:
  /// **'Test servers'**
  String get testServers;

  /// No description provided for @refreshSubscription.
  ///
  /// In en, this message translates to:
  /// **'Refresh subscription'**
  String get refreshSubscription;

  /// No description provided for @subscriptionActions.
  ///
  /// In en, this message translates to:
  /// **'Subscription actions'**
  String get subscriptionActions;

  /// No description provided for @deleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription'**
  String get deleteSubscription;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @subscriptionExists.
  ///
  /// In en, this message translates to:
  /// **'This subscription is already added'**
  String get subscriptionExists;

  /// No description provided for @groupExists.
  ///
  /// In en, this message translates to:
  /// **'A group named “{name}” already exists'**
  String groupExists(String name);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t import: {reason}'**
  String importFailed(String reason);

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQrTitle;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Allow it in Settings to scan QR codes.'**
  String get cameraDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable: {reason}'**
  String cameraUnavailable(String reason);

  /// No description provided for @startingCamera.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get startingCamera;

  /// No description provided for @pointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a QR code with a server link'**
  String get pointCamera;

  /// No description provided for @sectionServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get sectionServer;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get fieldPort;

  /// No description provided for @sectionTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get sectionTransport;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldServiceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get fieldServiceName;

  /// No description provided for @fieldPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get fieldPath;

  /// No description provided for @fieldHostHeader.
  ///
  /// In en, this message translates to:
  /// **'Host header'**
  String get fieldHostHeader;

  /// No description provided for @fieldXhttpMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get fieldXhttpMode;

  /// No description provided for @fieldPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get fieldPrivateKey;

  /// No description provided for @fieldAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get fieldAddresses;

  /// No description provided for @fieldPeerPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Server public key'**
  String get fieldPeerPublicKey;

  /// No description provided for @fieldPresharedKey.
  ///
  /// In en, this message translates to:
  /// **'Preshared key'**
  String get fieldPresharedKey;

  /// No description provided for @wgObfuscation.
  ///
  /// In en, this message translates to:
  /// **'WireGuard obfuscation'**
  String get wgObfuscation;

  /// No description provided for @wgObfuscationHint.
  ///
  /// In en, this message translates to:
  /// **'Junk packets and a DNS decoy before the handshake, as in Amnezia. Works with any WireGuard server'**
  String get wgObfuscationHint;

  /// No description provided for @wgObfuscationAmneziaServer.
  ///
  /// In en, this message translates to:
  /// **'Set by this AmneziaWG server, can\'t be turned off'**
  String get wgObfuscationAmneziaServer;

  /// No description provided for @xrayFragmentation.
  ///
  /// In en, this message translates to:
  /// **'Fragmentation (Xray)'**
  String get xrayFragmentation;

  /// No description provided for @xrayFragmentationHint.
  ///
  /// In en, this message translates to:
  /// **'Splits the first packets to the server like Xray\'s \"fragment\". Replaces TLS fragmentation'**
  String get xrayFragmentationHint;

  /// No description provided for @xrayPacketsHint.
  ///
  /// In en, this message translates to:
  /// **'tlshello or a range of writes, e.g. 1-3'**
  String get xrayPacketsHint;

  /// No description provided for @xrayLengthHint.
  ///
  /// In en, this message translates to:
  /// **'Piece size in bytes, e.g. 100-200'**
  String get xrayLengthHint;

  /// No description provided for @xrayIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Pause in ms, e.g. 10-20; empty = no pause'**
  String get xrayIntervalHint;

  /// No description provided for @xrayRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use N or N-M'**
  String get xrayRangeInvalid;

  /// No description provided for @sectionTls.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get sectionTls;

  /// No description provided for @useTls.
  ///
  /// In en, this message translates to:
  /// **'Use TLS'**
  String get useTls;

  /// No description provided for @tlsAlwaysOnQuic.
  ///
  /// In en, this message translates to:
  /// **'Always on for QUIC protocols'**
  String get tlsAlwaysOnQuic;

  /// No description provided for @fieldSni.
  ///
  /// In en, this message translates to:
  /// **'SNI'**
  String get fieldSni;

  /// No description provided for @sniHint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the server address'**
  String get sniHint;

  /// No description provided for @fieldAlpn.
  ///
  /// In en, this message translates to:
  /// **'ALPN'**
  String get fieldAlpn;

  /// No description provided for @alpnHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. h2,http/1.1'**
  String get alpnHint;

  /// No description provided for @allowInsecure.
  ///
  /// In en, this message translates to:
  /// **'Allow insecure'**
  String get allowInsecure;

  /// No description provided for @allowInsecureHint.
  ///
  /// In en, this message translates to:
  /// **'Skip certificate verification'**
  String get allowInsecureHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedHint.
  ///
  /// In en, this message translates to:
  /// **'uTLS fingerprint, fragmentation, Reality'**
  String get advancedHint;

  /// No description provided for @utlsFingerprint.
  ///
  /// In en, this message translates to:
  /// **'uTLS fingerprint'**
  String get utlsFingerprint;

  /// No description provided for @tlsFragmentation.
  ///
  /// In en, this message translates to:
  /// **'TLS fragmentation'**
  String get tlsFragmentation;

  /// No description provided for @tlsFragmentationHint.
  ///
  /// In en, this message translates to:
  /// **'Split the ClientHello across TCP segments'**
  String get tlsFragmentationHint;

  /// No description provided for @recordFragmentation.
  ///
  /// In en, this message translates to:
  /// **'Record fragmentation'**
  String get recordFragmentation;

  /// No description provided for @recordFragmentationHint.
  ///
  /// In en, this message translates to:
  /// **'Also split it into multiple TLS records'**
  String get recordFragmentationHint;

  /// No description provided for @fallbackDelay.
  ///
  /// In en, this message translates to:
  /// **'Fallback delay, ms'**
  String get fallbackDelay;

  /// No description provided for @fallbackDelayHint.
  ///
  /// In en, this message translates to:
  /// **'Empty = automatic'**
  String get fallbackDelayHint;

  /// No description provided for @reality.
  ///
  /// In en, this message translates to:
  /// **'Reality'**
  String get reality;

  /// No description provided for @publicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// No description provided for @shortId.
  ///
  /// In en, this message translates to:
  /// **'Short ID'**
  String get shortId;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @portRange.
  ///
  /// In en, this message translates to:
  /// **'Port must be 1–65535'**
  String get portRange;

  /// No description provided for @realityNeedsTls.
  ///
  /// In en, this message translates to:
  /// **'Reality requires TLS to be enabled'**
  String get realityNeedsTls;

  /// No description provided for @realityNeedsKey.
  ///
  /// In en, this message translates to:
  /// **'Reality needs a public key (Advanced section)'**
  String get realityNeedsKey;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @fromProvider.
  ///
  /// In en, this message translates to:
  /// **'From “{group}” · refreshing the subscription resets changes'**
  String fromProvider(String group);

  /// No description provided for @addedManually.
  ///
  /// In en, this message translates to:
  /// **'Added manually'**
  String get addedManually;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @sectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get sectionConnection;

  /// No description provided for @dnsServer.
  ///
  /// In en, this message translates to:
  /// **'DNS server'**
  String get dnsServer;

  /// No description provided for @dnsAdguard.
  ///
  /// In en, this message translates to:
  /// **'AdGuard — blocks ads'**
  String get dnsAdguard;

  /// No description provided for @ipMode.
  ///
  /// In en, this message translates to:
  /// **'IP version'**
  String get ipMode;

  /// No description provided for @ipModeHint.
  ///
  /// In en, this message translates to:
  /// **'Only if your server supports IPv6, otherwise sites may not open'**
  String get ipModeHint;

  /// No description provided for @ipModeV4.
  ///
  /// In en, this message translates to:
  /// **'IPv4 only'**
  String get ipModeV4;

  /// No description provided for @ipModeDual.
  ///
  /// In en, this message translates to:
  /// **'IPv4 and IPv6'**
  String get ipModeDual;

  /// No description provided for @ipModeV6.
  ///
  /// In en, this message translates to:
  /// **'IPv6 only'**
  String get ipModeV6;

  /// No description provided for @splitTunnel.
  ///
  /// In en, this message translates to:
  /// **'Per-app VPN'**
  String get splitTunnel;

  /// No description provided for @splitAll.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get splitAll;

  /// No description provided for @splitOnly.
  ///
  /// In en, this message translates to:
  /// **'Only selected'**
  String get splitOnly;

  /// No description provided for @splitBypass.
  ///
  /// In en, this message translates to:
  /// **'All except selected'**
  String get splitBypass;

  /// No description provided for @splitHintOff.
  ///
  /// In en, this message translates to:
  /// **'Every app uses the VPN.'**
  String get splitHintOff;

  /// No description provided for @splitHintOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the selected apps use the VPN; the rest connect directly.'**
  String get splitHintOnly;

  /// No description provided for @splitHintBypass.
  ///
  /// In en, this message translates to:
  /// **'The selected apps connect directly, bypassing the VPN.'**
  String get splitHintBypass;

  /// No description provided for @splitEmptyOnly.
  ///
  /// In en, this message translates to:
  /// **'Until you select apps, every app uses the VPN.'**
  String get splitEmptyOnly;

  /// No description provided for @splitValueAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get splitValueAll;

  /// No description provided for @splitValueOnly.
  ///
  /// In en, this message translates to:
  /// **'Only {count}'**
  String splitValueOnly(int count);

  /// No description provided for @splitValueBypass.
  ///
  /// In en, this message translates to:
  /// **'Except {count}'**
  String splitValueBypass(int count);

  /// No description provided for @premiumDeviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'The provider has restricted access for this device'**
  String get premiumDeviceRemoved;

  /// No description provided for @premiumRevoked.
  ///
  /// In en, this message translates to:
  /// **'The provider has revoked this subscription'**
  String get premiumRevoked;

  /// No description provided for @premiumLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This subscription has expired'**
  String get premiumLinkExpired;

  /// No description provided for @premiumUnknown.
  ///
  /// In en, this message translates to:
  /// **'This subscription no longer exists'**
  String get premiumUnknown;

  /// No description provided for @premiumDeviceLimit.
  ///
  /// In en, this message translates to:
  /// **'This link is already added on the maximum number of devices'**
  String get premiumDeviceLimit;

  /// No description provided for @premiumPlanInactive.
  ///
  /// In en, this message translates to:
  /// **'This provider’s WanX plan is not active'**
  String get premiumPlanInactive;

  /// No description provided for @premiumCheckOverdue.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify the subscription — refresh it when you’re online'**
  String get premiumCheckOverdue;

  /// No description provided for @premiumCheckTimeout.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify the subscription. Try again later.'**
  String get premiumCheckTimeout;

  /// No description provided for @premiumCheckLimit.
  ///
  /// In en, this message translates to:
  /// **'No more verification attempts today. Try tomorrow or on another network.'**
  String get premiumCheckLimit;

  /// No description provided for @noticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get noticeTitle;

  /// No description provided for @noticeIntro.
  ///
  /// In en, this message translates to:
  /// **'WanX is a VPN client: it connects your device to servers from a provider you choose, or your own. Here is what that involves.'**
  String get noticeIntro;

  /// No description provided for @noticeTraffic.
  ///
  /// In en, this message translates to:
  /// **'Your traffic goes to the VPN server you choose, never through WanX, and we don’t log it.'**
  String get noticeTraffic;

  /// No description provided for @noticeLocal.
  ///
  /// In en, this message translates to:
  /// **'No accounts, ads, analytics or tracking. Your servers and settings stay on this device.'**
  String get noticeLocal;

  /// No description provided for @noticeHwid.
  ///
  /// In en, this message translates to:
  /// **'When you add a subscription, the app sends its provider a device ID (HWID), the OS and the model so it can limit devices. You can turn this off in Settings.'**
  String get noticeHwid;

  /// No description provided for @noticeLinks.
  ///
  /// In en, this message translates to:
  /// **'Encrypted wanx:// links are checked with the WanX service, directly, through Google Cloud or through your VPN connection, using a key made on this device and, if enabled, the same device details.'**
  String get noticeLinks;

  /// No description provided for @noticeAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get noticeAgree;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @noApps.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noApps;

  /// No description provided for @bypassLan.
  ///
  /// In en, this message translates to:
  /// **'Bypass local network'**
  String get bypassLan;

  /// No description provided for @bypassLanHint.
  ///
  /// In en, this message translates to:
  /// **'Routers, printers and other local devices stay reachable'**
  String get bypassLanHint;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect on launch'**
  String get autoConnect;

  /// No description provided for @autoConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Connect to the selected server when the app opens'**
  String get autoConnectHint;

  /// No description provided for @sectionSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get sectionSubscriptions;

  /// No description provided for @updateOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Update on launch'**
  String get updateOnLaunch;

  /// No description provided for @updateOnLaunchHint.
  ///
  /// In en, this message translates to:
  /// **'Refresh all subscriptions when the app opens'**
  String get updateOnLaunchHint;

  /// No description provided for @sendHwid.
  ///
  /// In en, this message translates to:
  /// **'Send device ID (HWID)'**
  String get sendHwid;

  /// No description provided for @sendHwidHint.
  ///
  /// In en, this message translates to:
  /// **'Lets your provider limit the number of devices per subscription'**
  String get sendHwidHint;

  /// No description provided for @hwidCopied.
  ///
  /// In en, this message translates to:
  /// **'Device ID copied'**
  String get hwidCopied;

  /// No description provided for @newServer.
  ///
  /// In en, this message translates to:
  /// **'New server'**
  String get newServer;

  /// No description provided for @serverAdded.
  ///
  /// In en, this message translates to:
  /// **'Server added'**
  String get serverAdded;

  /// No description provided for @fieldProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get fieldProtocol;

  /// No description provided for @sectionAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get sectionAuth;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get fieldEncryption;

  /// No description provided for @fieldObfsPassword.
  ///
  /// In en, this message translates to:
  /// **'Obfuscation password (Salamander)'**
  String get fieldObfsPassword;

  /// No description provided for @fieldCongestion.
  ///
  /// In en, this message translates to:
  /// **'Congestion control'**
  String get fieldCongestion;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @addFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get addFromClipboard;

  /// No description provided for @addScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get addScanQr;

  /// No description provided for @addEnterLink.
  ///
  /// In en, this message translates to:
  /// **'Enter link'**
  String get addEnterLink;

  /// No description provided for @addManually.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get addManually;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @linkHint.
  ///
  /// In en, this message translates to:
  /// **'Server link or subscription URL — detected automatically'**
  String get linkHint;

  /// No description provided for @connectionSettingsNote.
  ///
  /// In en, this message translates to:
  /// **'Connection settings apply on the next connect.'**
  String get connectionSettingsNote;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'A fast, private VPN client. No accounts, no ads, no analytics — your servers and settings stay on this device.'**
  String get aboutText;

  /// No description provided for @addedServers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 server} other{Added {count} servers}}'**
  String addedServers(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'ru', 'tr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
