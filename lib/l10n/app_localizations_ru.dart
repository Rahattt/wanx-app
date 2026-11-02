// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusConnecting => 'Подключение…';

  @override
  String get statusDisconnecting => 'Отключение…';

  @override
  String get statusFailed => 'Ошибка подключения';

  @override
  String get statusDisconnected => 'Не подключено';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get upload => 'Отдача';

  @override
  String get download => 'Загрузка';

  @override
  String perSecond(String value) {
    return '$value/с';
  }

  @override
  String get checkRunning => 'Проверка соединения…';

  @override
  String get checkFailed => 'Нет ответа — сервер недоступен';

  @override
  String checkOk(int ms) {
    return 'Сервер работает · $ms мс';
  }

  @override
  String get addServer => 'Добавить сервер';

  @override
  String get settings => 'Настройки';

  @override
  String failedToLoad(String error) {
    return 'Не удалось загрузить серверы: $error';
  }

  @override
  String get groupManual => 'Вручную';

  @override
  String updatedAgo(String ago) {
    return 'Обновлено $ago';
  }

  @override
  String get agoJustNow => 'только что';

  @override
  String agoMinutes(int n) {
    return '$n мин назад';
  }

  @override
  String agoHours(int n) {
    return '$n ч назад';
  }

  @override
  String agoDays(int n) {
    return '$n д назад';
  }

  @override
  String noResponseWithin(String name) {
    return '$name: нет ответа за 5 с';
  }

  @override
  String serverError(String name, String error) {
    return '$name: $error';
  }

  @override
  String serversResponded(int ok, int total) {
    return 'Ответили $ok из $total серверов';
  }

  @override
  String deletedServer(String name) {
    return '$name удалён';
  }

  @override
  String get undo => 'Отменить';

  @override
  String deleteSubscriptionTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteSubscriptionBody =>
      'Подписка и все её серверы будут удалены.';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get noSubscriptionsToRefresh => 'Нет подписок для обновления';

  @override
  String subscriptionsUpdated(int count, int servers) {
    return 'Обновлено подписок: $count, серверов: $servers';
  }

  @override
  String get noServersTitle => 'Серверов пока нет';

  @override
  String get noServersBody =>
      'Добавьте сервер по ссылке, QR-коду или адресу подписки.';

  @override
  String get swipeTest => 'Пинг';

  @override
  String get swipeEdit => 'Изменить';

  @override
  String get serverDetails => 'О сервере';

  @override
  String get latencyFailed => 'ошибка';

  @override
  String get testServers => 'Проверить пинг';

  @override
  String get refreshSubscription => 'Обновить подписку';

  @override
  String get subscriptionActions => 'Действия с подпиской';

  @override
  String get deleteSubscription => 'Удалить подписку';

  @override
  String get editSubscription => 'Изменить подписку';

  @override
  String get subscriptionName => 'Название';

  @override
  String get subscriptionUrl => 'Ссылка подписки';

  @override
  String get importAction => 'Импорт';

  @override
  String get subscriptionExists => 'Эта подписка уже добавлена';

  @override
  String groupExists(String name) {
    return 'Группа «$name» уже есть';
  }

  @override
  String importFailed(String reason) {
    return 'Не удалось импортировать: $reason';
  }

  @override
  String get scanQrTitle => 'Сканировать QR-код';

  @override
  String get cameraDenied =>
      'Доступ к камере выключен. Разрешите его в Настройках, чтобы сканировать QR-коды.';

  @override
  String cameraUnavailable(String reason) {
    return 'Камера недоступна: $reason';
  }

  @override
  String get startingCamera => 'Запуск камеры…';

  @override
  String get pointCamera => 'Наведите камеру на QR-код со ссылкой на сервер';

  @override
  String get sectionServer => 'Сервер';

  @override
  String get fieldName => 'Название';

  @override
  String get fieldAddress => 'Адрес';

  @override
  String get fieldPort => 'Порт';

  @override
  String get sectionTransport => 'Транспорт';

  @override
  String get fieldType => 'Тип';

  @override
  String get fieldServiceName => 'Имя сервиса';

  @override
  String get fieldPath => 'Путь';

  @override
  String get fieldHostHeader => 'Заголовок Host';

  @override
  String get fieldXhttpMode => 'Режим';

  @override
  String get fieldXhttpExtra => 'Extra (JSON)';

  @override
  String get xhttpExtraHint => 'Доп. параметры XHTTP, ключи Xray или sing-box';

  @override
  String xhttpExtraInvalid(String details) {
    return 'Неверные параметры XHTTP: $details';
  }

  @override
  String get fieldPrivateKey => 'Приватный ключ';

  @override
  String get fieldAddresses => 'Адреса';

  @override
  String get fieldPeerPublicKey => 'Публичный ключ сервера';

  @override
  String get fieldPresharedKey => 'Общий ключ (PSK)';

  @override
  String get wgObfuscation => 'Обфускация WireGuard';

  @override
  String get wgObfuscationHint =>
      'Мусорные пакеты и маскировка под DNS перед рукопожатием, как в Amnezia. Работает с любым сервером WireGuard';

  @override
  String get wgObfuscationAmneziaServer =>
      'Задана сервером AmneziaWG, выключить нельзя';

  @override
  String get xrayFragmentation => 'Фрагментация (Xray)';

  @override
  String get xrayFragmentationHint =>
      'Режет первые пакеты к серверу как «fragment» в Xray. Заменяет фрагментацию TLS';

  @override
  String get xrayPacketsHint => 'tlshello или диапазон записей, например 1-3';

  @override
  String get xrayLengthHint => 'Размер куска в байтах, например 100-200';

  @override
  String get xrayIntervalHint =>
      'Пауза в мс, например 10-20; пусто — без паузы';

  @override
  String get xrayRangeInvalid => 'Укажите N или N-M';

  @override
  String get sectionTls => 'TLS';

  @override
  String get useTls => 'Использовать TLS';

  @override
  String get tlsAlwaysOnQuic => 'Всегда включён для протоколов QUIC';

  @override
  String get fieldSni => 'SNI';

  @override
  String get sniHint => 'По умолчанию — адрес сервера';

  @override
  String get fieldAlpn => 'ALPN';

  @override
  String get alpnHint => 'Через запятую, напр. h2,http/1.1';

  @override
  String get allowInsecure => 'Разрешить небезопасное';

  @override
  String get allowInsecureHint => 'Не проверять сертификат';

  @override
  String get save => 'Сохранить';

  @override
  String get advanced => 'Дополнительно';

  @override
  String get advancedHint => 'Отпечаток uTLS, фрагментация, Reality';

  @override
  String get utlsFingerprint => 'Отпечаток uTLS';

  @override
  String get tlsFragmentation => 'Фрагментация TLS';

  @override
  String get tlsFragmentationHint => 'Разбивать ClientHello на TCP-сегменты';

  @override
  String get recordFragmentation => 'Фрагментация записей';

  @override
  String get recordFragmentationHint =>
      'Также разбивать на несколько TLS-записей';

  @override
  String get fallbackDelay => 'Задержка отката, мс';

  @override
  String get fallbackDelayHint => 'Пусто — автоматически';

  @override
  String get reality => 'Reality';

  @override
  String get publicKey => 'Публичный ключ';

  @override
  String get shortId => 'Short ID';

  @override
  String get optional => 'Необязательно';

  @override
  String get required => 'Обязательно';

  @override
  String get portRange => 'Порт должен быть от 1 до 65535';

  @override
  String get realityNeedsTls => 'Для Reality нужно включить TLS';

  @override
  String get realityNeedsKey =>
      'Для Reality нужен публичный ключ (раздел «Дополнительно»)';

  @override
  String get saved => 'Сохранено';

  @override
  String fromProvider(String group) {
    return 'Из «$group» · обновление подписки сбросит изменения';
  }

  @override
  String get addedManually => 'Добавлен вручную';

  @override
  String get sectionAppearance => 'Оформление';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get sectionConnection => 'Подключение';

  @override
  String get dnsServer => 'DNS-сервер';

  @override
  String get dnsAdguard => 'AdGuard — блокирует рекламу';

  @override
  String get ipMode => 'Версия IP';

  @override
  String get ipModeHint =>
      'Только если сервер поддерживает IPv6, иначе сайты могут не открываться';

  @override
  String get ipModeV4 => 'Только IPv4';

  @override
  String get ipModeDual => 'IPv4 и IPv6';

  @override
  String get ipModeV6 => 'Только IPv6';

  @override
  String get splitTunnel => 'VPN для приложений';

  @override
  String get splitAll => 'Все приложения';

  @override
  String get splitOnly => 'Только выбранные';

  @override
  String get splitBypass => 'Все, кроме выбранных';

  @override
  String get splitHintOff => 'Все приложения идут через VPN.';

  @override
  String get splitHintOnly =>
      'Через VPN идут только выбранные приложения, остальные — напрямую.';

  @override
  String get splitHintBypass =>
      'Выбранные приложения идут напрямую, в обход VPN.';

  @override
  String get splitEmptyOnly =>
      'Пока ничего не выбрано, через VPN идут все приложения.';

  @override
  String get splitValueAll => 'Все';

  @override
  String splitValueOnly(int count) {
    return 'Только $count';
  }

  @override
  String splitValueBypass(int count) {
    return 'Кроме $count';
  }

  @override
  String get premiumDeviceRemoved =>
      'Провайдер ограничил доступ для этого устройства';

  @override
  String get premiumRevoked => 'Провайдер отозвал эту подписку';

  @override
  String get premiumUnknown => 'Эта подписка больше не существует';

  @override
  String get premiumDeviceLimit =>
      'Ссылка уже добавлена на максимальное число устройств';

  @override
  String get premiumPlanInactive => 'Ссылки этого провайдера больше не активны';

  @override
  String get premiumCheckOverdue =>
      'Не удалось проверить подписку — обновите её, когда будет интернет';

  @override
  String get premiumCheckTimeout =>
      'Не удалось проверить подписку. Попробуйте позже.';

  @override
  String get premiumCheckLimit =>
      'Попытки проверки на сегодня исчерпаны. Попробуйте завтра или в другой сети.';

  @override
  String get noticeTitle => 'Перед началом';

  @override
  String get noticeIntro =>
      'WanX — VPN-клиент: он подключает устройство к серверам выбранного вами провайдера или к вашим собственным. Вот что это значит.';

  @override
  String get noticeTraffic =>
      'Ваш трафик идёт на выбранный VPN-сервер и никогда не проходит через WanX. Мы его не записываем.';

  @override
  String get noticeLocal =>
      'Без аккаунтов, рекламы, аналитики и слежки. Серверы и настройки хранятся только на этом устройстве.';

  @override
  String get noticeHwid =>
      'При добавлении подписки приложение отправляет её провайдеру ID устройства (HWID), версию ОС и модель, чтобы он мог ограничивать число устройств. Это можно отключить в настройках.';

  @override
  String get noticeLinks =>
      'Зашифрованные ссылки wanx:// проверяются сервисом WanX — напрямую, через Google Cloud или через ваше VPN-подключение — по ключу, созданному на этом устройстве, и, если включено, по тем же данным устройства.';

  @override
  String get noticeAgree => 'Принять и продолжить';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get termsOfService => 'Условия использования';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get openSourceLicenses => 'Лицензии открытого ПО';

  @override
  String get searchApps => 'Поиск приложений';

  @override
  String get noApps => 'Приложения не найдены';

  @override
  String get bypassLan => 'Локальная сеть напрямую';

  @override
  String get bypassLanHint =>
      'Роутер, принтер и другие устройства в сети остаются доступны';

  @override
  String get autoConnect => 'Подключаться при запуске';

  @override
  String get autoConnectHint =>
      'Подключаться к выбранному серверу при открытии приложения';

  @override
  String get sectionSubscriptions => 'Подписки';

  @override
  String get updateOnLaunch => 'Обновлять при запуске';

  @override
  String get updateOnLaunchHint =>
      'Обновлять все подписки при открытии приложения';

  @override
  String get sendHwid => 'Отправлять ID устройства (HWID)';

  @override
  String get sendHwidHint =>
      'Позволяет провайдеру ограничивать число устройств на подписку';

  @override
  String get hwidCopied => 'ID устройства скопирован';

  @override
  String get newServer => 'Новый сервер';

  @override
  String get serverAdded => 'Сервер добавлен';

  @override
  String get fieldProtocol => 'Протокол';

  @override
  String get sectionAuth => 'Аутентификация';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldEncryption => 'Шифрование';

  @override
  String get fieldObfsPassword => 'Пароль обфускации (Salamander)';

  @override
  String get fieldCongestion => 'Контроль перегрузки';

  @override
  String get none => 'Нет';

  @override
  String get addFromClipboard => 'Импорт из буфера';

  @override
  String get addScanQr => 'Сканировать QR-код';

  @override
  String get addEnterLink => 'Ввести ссылку';

  @override
  String get addManually => 'Добавить вручную';

  @override
  String get clipboardEmpty => 'Буфер обмена пуст';

  @override
  String get linkHint =>
      'Ссылка на сервер или адрес подписки — определяется автоматически';

  @override
  String get connectionSettingsNote =>
      'Настройки подключения применятся при следующем подключении.';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get aboutText =>
      'Быстрый и приватный VPN-клиент. Без аккаунтов, рекламы и аналитики — ваши серверы и настройки хранятся только на этом устройстве.';

  @override
  String addedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count сервера',
      many: 'Добавлено $count серверов',
      few: 'Добавлено $count сервера',
      one: 'Добавлен $count сервер',
    );
    return '$_temp0';
  }
}
