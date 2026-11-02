// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get statusConnected => 'Bağlı';

  @override
  String get statusConnecting => 'Bağlanıyor…';

  @override
  String get statusDisconnecting => 'Bağlantı kesiliyor…';

  @override
  String get statusFailed => 'Bağlantı başarısız';

  @override
  String get statusDisconnected => 'Bağlı değil';

  @override
  String get connect => 'Bağlan';

  @override
  String get disconnect => 'Bağlantıyı kes';

  @override
  String get upload => 'Yükleme';

  @override
  String get download => 'İndirme';

  @override
  String perSecond(String value) {
    return '$value/sn';
  }

  @override
  String get checkRunning => 'Bağlantı kontrol ediliyor…';

  @override
  String get checkFailed => 'Yanıt yok — sunucuya ulaşılamıyor';

  @override
  String checkOk(int ms) {
    return 'Sunucu çalışıyor · $ms ms';
  }

  @override
  String get addServer => 'Sunucu ekle';

  @override
  String get settings => 'Ayarlar';

  @override
  String failedToLoad(String error) {
    return 'Sunucular yüklenemedi: $error';
  }

  @override
  String get groupManual => 'Manuel';

  @override
  String updatedAgo(String ago) {
    return 'Güncellendi: $ago';
  }

  @override
  String get agoJustNow => 'az önce';

  @override
  String agoMinutes(int n) {
    return '$n dk önce';
  }

  @override
  String agoHours(int n) {
    return '$n sa önce';
  }

  @override
  String agoDays(int n) {
    return '$n gün önce';
  }

  @override
  String noResponseWithin(String name) {
    return '$name: 5 sn içinde yanıt yok';
  }

  @override
  String serverError(String name, String error) {
    return '$name: $error';
  }

  @override
  String serversResponded(int ok, int total) {
    return '$total sunucudan $ok tanesi yanıt verdi';
  }

  @override
  String deletedServer(String name) {
    return '$name silindi';
  }

  @override
  String get undo => 'Geri al';

  @override
  String deleteSubscriptionTitle(String name) {
    return '“$name” silinsin mi?';
  }

  @override
  String get deleteSubscriptionBody => 'Abonelik ve tüm sunucuları silinecek.';

  @override
  String get cancel => 'İptal';

  @override
  String get delete => 'Sil';

  @override
  String get noSubscriptionsToRefresh => 'Güncellenecek abonelik yok';

  @override
  String subscriptionsUpdated(int count, int servers) {
    return 'Güncellenen abonelik: $count, sunucu: $servers';
  }

  @override
  String get noServersTitle => 'Henüz sunucu yok';

  @override
  String get noServersBody =>
      'Paylaşım bağlantısı, QR kodu veya abonelik adresiyle ekleyin.';

  @override
  String get swipeTest => 'Test';

  @override
  String get swipeEdit => 'Düzenle';

  @override
  String get serverDetails => 'Sunucu ayrıntıları';

  @override
  String get latencyFailed => 'hata';

  @override
  String get testServers => 'Sunucuları test et';

  @override
  String get refreshSubscription => 'Aboneliği güncelle';

  @override
  String get subscriptionActions => 'Abonelik işlemleri';

  @override
  String get deleteSubscription => 'Aboneliği sil';

  @override
  String get editSubscription => 'Aboneliği düzenle';

  @override
  String get subscriptionName => 'Ad';

  @override
  String get subscriptionUrl => 'Abonelik bağlantısı';

  @override
  String get importAction => 'İçe aktar';

  @override
  String get subscriptionExists => 'Bu abonelik zaten ekli';

  @override
  String groupExists(String name) {
    return '“$name” adlı bir grup zaten var';
  }

  @override
  String importFailed(String reason) {
    return 'İçe aktarılamadı: $reason';
  }

  @override
  String get scanQrTitle => 'QR kodu tara';

  @override
  String get cameraDenied =>
      'Kamera erişimi kapalı. QR kod taramak için Ayarlar’dan izin verin.';

  @override
  String cameraUnavailable(String reason) {
    return 'Kamera kullanılamıyor: $reason';
  }

  @override
  String get startingCamera => 'Kamera açılıyor…';

  @override
  String get pointCamera => 'Kamerayı sunucu bağlantısı içeren QR koda tutun';

  @override
  String get sectionServer => 'Sunucu';

  @override
  String get fieldName => 'Ad';

  @override
  String get fieldAddress => 'Adres';

  @override
  String get fieldPort => 'Port';

  @override
  String get sectionTransport => 'Aktarım';

  @override
  String get fieldType => 'Tür';

  @override
  String get fieldServiceName => 'Servis adı';

  @override
  String get fieldPath => 'Yol';

  @override
  String get fieldHostHeader => 'Host başlığı';

  @override
  String get fieldXhttpMode => 'Mod';

  @override
  String get fieldXhttpExtra => 'Extra (JSON)';

  @override
  String get xhttpExtraHint =>
      'Gelişmiş XHTTP seçenekleri, Xray veya sing-box anahtarları';

  @override
  String xhttpExtraInvalid(String details) {
    return 'Geçersiz XHTTP seçenekleri: $details';
  }

  @override
  String get fieldPrivateKey => 'Özel anahtar';

  @override
  String get fieldAddresses => 'Adresler';

  @override
  String get fieldPeerPublicKey => 'Sunucu açık anahtarı';

  @override
  String get fieldPresharedKey => 'Ön paylaşımlı anahtar';

  @override
  String get wgObfuscation => 'WireGuard gizleme';

  @override
  String get wgObfuscationHint =>
      'El sıkışmadan önce gereksiz paketler ve DNS yemi, Amnezia\'daki gibi. Her WireGuard sunucusuyla çalışır';

  @override
  String get wgObfuscationAmneziaServer =>
      'Bu AmneziaWG sunucusu tarafından ayarlandı, kapatılamaz';

  @override
  String get xrayFragmentation => 'Parçalama (Xray)';

  @override
  String get xrayFragmentationHint =>
      'Sunucuya giden ilk paketleri Xray\'in \"fragment\" özelliği gibi böler. TLS parçalamanın yerini alır';

  @override
  String get xrayPacketsHint => 'tlshello veya yazma aralığı, örn. 1-3';

  @override
  String get xrayLengthHint => 'Parça boyutu (bayt), örn. 100-200';

  @override
  String get xrayIntervalHint => 'Bekleme (ms), örn. 10-20; boş = beklemesiz';

  @override
  String get xrayRangeInvalid => 'N veya N-M girin';

  @override
  String get sectionTls => 'TLS';

  @override
  String get useTls => 'TLS kullan';

  @override
  String get tlsAlwaysOnQuic => 'QUIC protokollerinde her zaman açık';

  @override
  String get fieldSni => 'SNI';

  @override
  String get sniHint => 'Varsayılan: sunucu adresi';

  @override
  String get fieldAlpn => 'ALPN';

  @override
  String get alpnHint => 'Virgülle ayrılmış, ör. h2,http/1.1';

  @override
  String get allowInsecure => 'Güvensize izin ver';

  @override
  String get allowInsecureHint => 'Sertifika doğrulamasını atla';

  @override
  String get save => 'Kaydet';

  @override
  String get advanced => 'Gelişmiş';

  @override
  String get advancedHint => 'uTLS parmak izi, parçalama, Reality';

  @override
  String get utlsFingerprint => 'uTLS parmak izi';

  @override
  String get tlsFragmentation => 'TLS parçalama';

  @override
  String get tlsFragmentationHint => 'ClientHello’yu TCP segmentlerine böl';

  @override
  String get recordFragmentation => 'Kayıt parçalama';

  @override
  String get recordFragmentationHint => 'Ayrıca birden çok TLS kaydına böl';

  @override
  String get fallbackDelay => 'Geri dönüş gecikmesi, ms';

  @override
  String get fallbackDelayHint => 'Boş = otomatik';

  @override
  String get reality => 'Reality';

  @override
  String get publicKey => 'Genel anahtar';

  @override
  String get shortId => 'Short ID';

  @override
  String get optional => 'İsteğe bağlı';

  @override
  String get required => 'Zorunlu';

  @override
  String get portRange => 'Port 1–65535 arasında olmalı';

  @override
  String get realityNeedsTls => 'Reality için TLS açık olmalı';

  @override
  String get realityNeedsKey =>
      'Reality için genel anahtar gerekli (Gelişmiş bölümü)';

  @override
  String get saved => 'Kaydedildi';

  @override
  String fromProvider(String group) {
    return '“$group” aboneliğinden · abonelik güncellenince değişiklikler sıfırlanır';
  }

  @override
  String get addedManually => 'Elle eklendi';

  @override
  String get sectionAppearance => 'Görünüm';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get sectionConnection => 'Bağlantı';

  @override
  String get dnsServer => 'DNS sunucusu';

  @override
  String get dnsAdguard => 'AdGuard — reklamları engeller';

  @override
  String get ipMode => 'IP sürümü';

  @override
  String get ipModeHint =>
      'Yalnızca sunucunuz IPv6 destekliyorsa; aksi hâlde siteler açılmayabilir';

  @override
  String get ipModeV4 => 'Yalnızca IPv4';

  @override
  String get ipModeDual => 'IPv4 ve IPv6';

  @override
  String get ipModeV6 => 'Yalnızca IPv6';

  @override
  String get splitTunnel => 'Uygulama bazlı VPN';

  @override
  String get splitAll => 'Tüm uygulamalar';

  @override
  String get splitOnly => 'Yalnızca seçilenler';

  @override
  String get splitBypass => 'Seçilenler hariç';

  @override
  String get splitHintOff => 'Tüm uygulamalar VPN kullanır.';

  @override
  String get splitHintOnly =>
      'Yalnızca seçilen uygulamalar VPN kullanır; diğerleri doğrudan bağlanır.';

  @override
  String get splitHintBypass =>
      'Seçilen uygulamalar VPN\'i atlayarak doğrudan bağlanır.';

  @override
  String get splitEmptyOnly =>
      'Uygulama seçilene kadar tüm uygulamalar VPN kullanır.';

  @override
  String get splitValueAll => 'Tümü';

  @override
  String splitValueOnly(int count) {
    return 'Yalnızca $count';
  }

  @override
  String splitValueBypass(int count) {
    return '$count hariç';
  }

  @override
  String get premiumDeviceRemoved => 'Sağlayıcı bu cihazın erişimini kısıtladı';

  @override
  String get premiumRevoked => 'Sağlayıcı bu aboneliği iptal etti';

  @override
  String get premiumUnknown => 'Bu abonelik artık mevcut değil';

  @override
  String get premiumDeviceLimit => 'Bu bağlantı zaten en fazla cihaza eklendi';

  @override
  String get premiumPlanInactive =>
      'Bu sağlayıcının bağlantıları artık etkin değil';

  @override
  String get premiumCheckOverdue =>
      'Abonelik doğrulanamadı — çevrimiçi olduğunuzda yenileyin';

  @override
  String get premiumCheckTimeout =>
      'Abonelik doğrulanamadı. Daha sonra tekrar deneyin.';

  @override
  String get premiumCheckLimit =>
      'Bugün için doğrulama denemeleri bitti. Yarın ya da başka bir ağda deneyin.';

  @override
  String get noticeTitle => 'Başlamadan önce';

  @override
  String get noticeIntro =>
      'WanX bir VPN istemcisidir: cihazınızı seçtiğiniz bir sağlayıcının ya da kendi sunucularınıza bağlar. Bunun anlamı şudur.';

  @override
  String get noticeTraffic =>
      'Trafiğiniz seçtiğiniz VPN sunucusuna gider, asla WanX üzerinden geçmez ve kaydedilmez.';

  @override
  String get noticeLocal =>
      'Hesap, reklam, analiz ya da izleme yok. Sunucularınız ve ayarlarınız bu cihazda kalır.';

  @override
  String get noticeHwid =>
      'Abonelik eklediğinizde uygulama, cihaz sınırı uygulayabilmesi için sağlayıcıya cihaz kimliği (HWID), işletim sistemi ve model bilgisini gönderir. Bunu Ayarlar’dan kapatabilirsiniz.';

  @override
  String get noticeLinks =>
      'Şifreli wanx:// bağlantıları WanX hizmetiyle — doğrudan, Google Cloud üzerinden ya da VPN bağlantınız üzerinden — bu cihazda oluşturulan bir anahtar ve açıksa aynı cihaz bilgileriyle doğrulanır.';

  @override
  String get noticeAgree => 'Kabul et ve devam et';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get termsOfService => 'Kullanım Koşulları';

  @override
  String get sourceCode => 'Kaynak kodu';

  @override
  String get openSourceLicenses => 'Açık kaynak lisansları';

  @override
  String get searchApps => 'Uygulama ara';

  @override
  String get noApps => 'Uygulama bulunamadı';

  @override
  String get bypassLan => 'Yerel ağı atla';

  @override
  String get bypassLanHint =>
      'Modem, yazıcı ve diğer yerel cihazlara erişilebilir';

  @override
  String get autoConnect => 'Açılışta bağlan';

  @override
  String get autoConnectHint => 'Uygulama açıldığında seçili sunucuya bağlan';

  @override
  String get sectionSubscriptions => 'Abonelikler';

  @override
  String get updateOnLaunch => 'Açılışta güncelle';

  @override
  String get updateOnLaunchHint =>
      'Uygulama açıldığında tüm abonelikleri güncelle';

  @override
  String get sendHwid => 'Cihaz kimliğini gönder (HWID)';

  @override
  String get sendHwidHint =>
      'Sağlayıcının abonelik başına cihaz sayısını sınırlamasını sağlar';

  @override
  String get hwidCopied => 'Cihaz kimliği kopyalandı';

  @override
  String get newServer => 'Yeni sunucu';

  @override
  String get serverAdded => 'Sunucu eklendi';

  @override
  String get fieldProtocol => 'Protokol';

  @override
  String get sectionAuth => 'Kimlik doğrulama';

  @override
  String get fieldPassword => 'Parola';

  @override
  String get fieldEncryption => 'Şifreleme';

  @override
  String get fieldObfsPassword => 'Gizleme parolası (Salamander)';

  @override
  String get fieldCongestion => 'Tıkanıklık kontrolü';

  @override
  String get none => 'Yok';

  @override
  String get addFromClipboard => 'Panodan içe aktar';

  @override
  String get addScanQr => 'QR kodu tara';

  @override
  String get addEnterLink => 'Bağlantı gir';

  @override
  String get addManually => 'Elle ekle';

  @override
  String get clipboardEmpty => 'Pano boş';

  @override
  String get linkHint =>
      'Sunucu bağlantısı veya abonelik adresi — otomatik algılanır';

  @override
  String get connectionSettingsNote =>
      'Bağlantı ayarları sonraki bağlantıda geçerli olur.';

  @override
  String get sectionAbout => 'Hakkında';

  @override
  String get appVersion => 'Uygulama sürümü';

  @override
  String get aboutText =>
      'Hızlı ve gizli bir VPN istemcisi. Hesap, reklam ve analiz yok — sunucularınız ve ayarlarınız yalnızca bu cihazda kalır.';

  @override
  String addedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sunucu eklendi',
    );
    return '$_temp0';
  }
}
