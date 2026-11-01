// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusConnecting => 'Connexion…';

  @override
  String get statusDisconnecting => 'Déconnexion…';

  @override
  String get statusFailed => 'Échec de la connexion';

  @override
  String get statusDisconnected => 'Non connecté';

  @override
  String get connect => 'Se connecter';

  @override
  String get disconnect => 'Se déconnecter';

  @override
  String get upload => 'Envoi';

  @override
  String get download => 'Réception';

  @override
  String perSecond(String value) {
    return '$value/s';
  }

  @override
  String get checkRunning => 'Vérification de la connexion…';

  @override
  String get checkFailed => 'Aucune réponse — serveur injoignable';

  @override
  String checkOk(int ms) {
    return 'Serveur actif · $ms ms';
  }

  @override
  String get addServer => 'Ajouter un serveur';

  @override
  String get settings => 'Réglages';

  @override
  String failedToLoad(String error) {
    return 'Impossible de charger les serveurs : $error';
  }

  @override
  String get groupManual => 'Manuels';

  @override
  String updatedAgo(String ago) {
    return 'Mis à jour $ago';
  }

  @override
  String get agoJustNow => 'à l’instant';

  @override
  String agoMinutes(int n) {
    return 'il y a $n min';
  }

  @override
  String agoHours(int n) {
    return 'il y a $n h';
  }

  @override
  String agoDays(int n) {
    return 'il y a $n j';
  }

  @override
  String noResponseWithin(String name) {
    return '$name : aucune réponse en 5 s';
  }

  @override
  String serverError(String name, String error) {
    return '$name : $error';
  }

  @override
  String serversResponded(int ok, int total) {
    return '$ok serveur(s) sur $total ont répondu';
  }

  @override
  String deletedServer(String name) {
    return '$name supprimé';
  }

  @override
  String get undo => 'Annuler';

  @override
  String deleteSubscriptionTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteSubscriptionBody =>
      'L’abonnement et tous ses serveurs seront supprimés.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get noSubscriptionsToRefresh => 'Aucun abonnement à actualiser';

  @override
  String subscriptionsUpdated(int count, int servers) {
    return 'Abonnements mis à jour : $count, serveurs : $servers';
  }

  @override
  String get noServersTitle => 'Aucun serveur';

  @override
  String get noServersBody =>
      'Ajoutez-en un via un lien, un QR code ou une URL d’abonnement.';

  @override
  String get swipeTest => 'Tester';

  @override
  String get swipeEdit => 'Modifier';

  @override
  String get serverDetails => 'Détails du serveur';

  @override
  String get latencyFailed => 'échec';

  @override
  String get testServers => 'Tester les serveurs';

  @override
  String get refreshSubscription => 'Actualiser l’abonnement';

  @override
  String get subscriptionActions => 'Actions de l’abonnement';

  @override
  String get deleteSubscription => 'Supprimer l’abonnement';

  @override
  String get importAction => 'Importer';

  @override
  String get subscriptionExists => 'Cet abonnement est déjà ajouté';

  @override
  String groupExists(String name) {
    return 'Un groupe « $name » existe déjà';
  }

  @override
  String importFailed(String reason) {
    return 'Import impossible : $reason';
  }

  @override
  String get scanQrTitle => 'Scanner un QR code';

  @override
  String get cameraDenied =>
      'L’accès à l’appareil photo est désactivé. Autorisez-le dans Réglages pour scanner.';

  @override
  String cameraUnavailable(String reason) {
    return 'Appareil photo indisponible : $reason';
  }

  @override
  String get startingCamera => 'Démarrage de l’appareil photo…';

  @override
  String get pointCamera => 'Visez un QR code contenant un lien de serveur';

  @override
  String get sectionServer => 'Serveur';

  @override
  String get fieldName => 'Nom';

  @override
  String get fieldAddress => 'Adresse';

  @override
  String get fieldPort => 'Port';

  @override
  String get sectionTransport => 'Transport';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldServiceName => 'Nom du service';

  @override
  String get fieldPath => 'Chemin';

  @override
  String get fieldHostHeader => 'En-tête Host';

  @override
  String get fieldXhttpMode => 'Mode';

  @override
  String get sectionTls => 'TLS';

  @override
  String get useTls => 'Utiliser TLS';

  @override
  String get tlsAlwaysOnQuic => 'Toujours actif pour les protocoles QUIC';

  @override
  String get fieldSni => 'SNI';

  @override
  String get sniHint => 'Par défaut : l’adresse du serveur';

  @override
  String get fieldAlpn => 'ALPN';

  @override
  String get alpnHint => 'Séparés par des virgules, ex. h2,http/1.1';

  @override
  String get allowInsecure => 'Autoriser non sécurisé';

  @override
  String get allowInsecureHint => 'Ignorer la vérification du certificat';

  @override
  String get save => 'Enregistrer';

  @override
  String get advanced => 'Avancé';

  @override
  String get advancedHint => 'Empreinte uTLS, fragmentation, Reality';

  @override
  String get utlsFingerprint => 'Empreinte uTLS';

  @override
  String get tlsFragmentation => 'Fragmentation TLS';

  @override
  String get tlsFragmentationHint =>
      'Répartir le ClientHello sur plusieurs segments TCP';

  @override
  String get recordFragmentation => 'Fragmentation des enregistrements';

  @override
  String get recordFragmentationHint =>
      'Le répartir aussi sur plusieurs enregistrements TLS';

  @override
  String get fallbackDelay => 'Délai de repli, ms';

  @override
  String get fallbackDelayHint => 'Vide = automatique';

  @override
  String get reality => 'Reality';

  @override
  String get publicKey => 'Clé publique';

  @override
  String get shortId => 'Short ID';

  @override
  String get optional => 'Facultatif';

  @override
  String get required => 'Obligatoire';

  @override
  String get portRange => 'Le port doit être entre 1 et 65535';

  @override
  String get realityNeedsTls => 'Reality nécessite TLS';

  @override
  String get realityNeedsKey =>
      'Reality nécessite une clé publique (section Avancé)';

  @override
  String get saved => 'Enregistré';

  @override
  String fromProvider(String group) {
    return 'De « $group » · actualiser l’abonnement annule les modifications';
  }

  @override
  String get addedManually => 'Ajouté manuellement';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get sectionConnection => 'Connexion';

  @override
  String get dnsServer => 'Serveur DNS';

  @override
  String get dnsAdguard => 'AdGuard — bloque les pubs';

  @override
  String get ipMode => 'Version IP';

  @override
  String get ipModeHint =>
      'Seulement si votre serveur prend en charge IPv6, sinon des sites peuvent ne pas s’ouvrir';

  @override
  String get ipModeV4 => 'IPv4 uniquement';

  @override
  String get ipModeDual => 'IPv4 et IPv6';

  @override
  String get ipModeV6 => 'IPv6 uniquement';

  @override
  String get splitTunnel => 'VPN par application';

  @override
  String get splitAll => 'Toutes les apps';

  @override
  String get splitOnly => 'Seulement la sélection';

  @override
  String get splitBypass => 'Toutes sauf la sélection';

  @override
  String get splitHintOff => 'Toutes les apps passent par le VPN.';

  @override
  String get splitHintOnly =>
      'Seules les apps sélectionnées passent par le VPN ; les autres se connectent directement.';

  @override
  String get splitHintBypass =>
      'Les apps sélectionnées se connectent directement, sans le VPN.';

  @override
  String get splitEmptyOnly =>
      'Tant qu’aucune app n’est sélectionnée, toutes passent par le VPN.';

  @override
  String get splitValueAll => 'Toutes';

  @override
  String splitValueOnly(int count) {
    return 'Seulement $count';
  }

  @override
  String splitValueBypass(int count) {
    return 'Sauf $count';
  }

  @override
  String get premiumDeviceRemoved =>
      'Le fournisseur a restreint l’accès pour cet appareil';

  @override
  String get premiumRevoked => 'Le fournisseur a révoqué cet abonnement';

  @override
  String get premiumLinkExpired => 'Cet abonnement a expiré';

  @override
  String get premiumUnknown => 'Cet abonnement n’existe plus';

  @override
  String get premiumDeviceLimit =>
      'Ce lien est déjà ajouté sur le nombre maximal d’appareils';

  @override
  String get premiumPlanInactive =>
      'Le forfait WanX de ce fournisseur n’est pas actif';

  @override
  String get premiumCheckOverdue =>
      'Impossible de vérifier l’abonnement — actualisez-le une fois en ligne';

  @override
  String get premiumCheckTimeout =>
      'Impossible de vérifier l’abonnement. Réessayez plus tard.';

  @override
  String get premiumCheckLimit =>
      'Plus de tentatives de vérification aujourd’hui. Réessayez demain ou sur un autre réseau.';

  @override
  String get noticeTitle => 'Avant de commencer';

  @override
  String get noticeIntro =>
      'WanX est un client VPN : il connecte votre appareil aux serveurs d’un fournisseur que vous choisissez, ou aux vôtres. Voici ce que cela implique.';

  @override
  String get noticeTraffic =>
      'Votre trafic va au serveur VPN que vous choisissez, jamais par WanX, et nous ne l’enregistrons pas.';

  @override
  String get noticeLocal =>
      'Pas de compte, de publicité, d’analytique ni de pistage. Vos serveurs et réglages restent sur cet appareil.';

  @override
  String get noticeHwid =>
      'Quand vous ajoutez un abonnement, l’app envoie à son fournisseur un identifiant d’appareil (HWID), le système et le modèle pour qu’il limite les appareils. Vous pouvez le désactiver dans les Réglages.';

  @override
  String get noticeLinks =>
      'Les liens chiffrés wanx:// sont vérifiés par le service WanX — directement, via Google Cloud ou via votre connexion VPN — avec une clé créée sur cet appareil et, si activé, les mêmes informations d’appareil.';

  @override
  String get noticeAgree => 'Accepter et continuer';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get sourceCode => 'Code source';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get searchApps => 'Rechercher des apps';

  @override
  String get noApps => 'Aucune app trouvée';

  @override
  String get bypassLan => 'Contourner le réseau local';

  @override
  String get bypassLanHint =>
      'Box, imprimantes et autres appareils locaux restent accessibles';

  @override
  String get autoConnect => 'Se connecter au lancement';

  @override
  String get autoConnectHint => 'Se connecter au serveur choisi à l’ouverture';

  @override
  String get sectionSubscriptions => 'Abonnements';

  @override
  String get updateOnLaunch => 'Actualiser au lancement';

  @override
  String get updateOnLaunchHint =>
      'Actualiser tous les abonnements à l’ouverture';

  @override
  String get sendHwid => 'Envoyer l’ID de l’appareil (HWID)';

  @override
  String get sendHwidHint =>
      'Permet au fournisseur de limiter le nombre d’appareils par abonnement';

  @override
  String get hwidCopied => 'ID de l’appareil copié';

  @override
  String get newServer => 'Nouveau serveur';

  @override
  String get serverAdded => 'Serveur ajouté';

  @override
  String get fieldProtocol => 'Protocole';

  @override
  String get sectionAuth => 'Authentification';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get fieldEncryption => 'Chiffrement';

  @override
  String get fieldObfsPassword => 'Mot de passe d’obfuscation (Salamander)';

  @override
  String get fieldCongestion => 'Contrôle de congestion';

  @override
  String get none => 'Aucun';

  @override
  String get addFromClipboard => 'Importer depuis le presse-papiers';

  @override
  String get addScanQr => 'Scanner un QR code';

  @override
  String get addEnterLink => 'Saisir un lien';

  @override
  String get addManually => 'Ajouter manuellement';

  @override
  String get clipboardEmpty => 'Le presse-papiers est vide';

  @override
  String get linkHint =>
      'Lien de serveur ou URL d’abonnement — détecté automatiquement';

  @override
  String get connectionSettingsNote =>
      'Les réglages de connexion s’appliqueront à la prochaine connexion.';

  @override
  String get sectionAbout => 'À propos';

  @override
  String get appVersion => 'Version de l’app';

  @override
  String get aboutText =>
      'Un client VPN rapide et privé. Sans compte, sans pub, sans statistiques — vos serveurs et réglages restent sur cet appareil.';

  @override
  String addedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs ajoutés',
      one: '$count serveur ajouté',
    );
    return '$_temp0';
  }
}
