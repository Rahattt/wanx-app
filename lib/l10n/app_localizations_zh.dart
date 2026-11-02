// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get statusConnected => '已连接';

  @override
  String get statusConnecting => '正在连接…';

  @override
  String get statusDisconnecting => '正在断开…';

  @override
  String get statusFailed => '连接失败';

  @override
  String get statusDisconnected => '未连接';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get upload => '上传';

  @override
  String get download => '下载';

  @override
  String perSecond(String value) {
    return '$value/秒';
  }

  @override
  String get checkRunning => '正在检查连接…';

  @override
  String get checkFailed => '无响应 — 服务器不可达';

  @override
  String checkOk(int ms) {
    return '服务器可用 · $ms 毫秒';
  }

  @override
  String get addServer => '添加服务器';

  @override
  String get settings => '设置';

  @override
  String failedToLoad(String error) {
    return '无法加载服务器：$error';
  }

  @override
  String get groupManual => '手动添加';

  @override
  String updatedAgo(String ago) {
    return '更新于$ago';
  }

  @override
  String get agoJustNow => '刚刚';

  @override
  String agoMinutes(int n) {
    return '$n 分钟前';
  }

  @override
  String agoHours(int n) {
    return '$n 小时前';
  }

  @override
  String agoDays(int n) {
    return '$n 天前';
  }

  @override
  String noResponseWithin(String name) {
    return '$name：5 秒内无响应';
  }

  @override
  String serverError(String name, String error) {
    return '$name：$error';
  }

  @override
  String serversResponded(int ok, int total) {
    return '$total 个服务器中有 $ok 个响应';
  }

  @override
  String deletedServer(String name) {
    return '已删除 $name';
  }

  @override
  String get undo => '撤销';

  @override
  String deleteSubscriptionTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteSubscriptionBody => '该订阅及其所有服务器将被删除。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get noSubscriptionsToRefresh => '没有可更新的订阅';

  @override
  String subscriptionsUpdated(int count, int servers) {
    return '已更新订阅：$count，服务器：$servers';
  }

  @override
  String get noServersTitle => '还没有服务器';

  @override
  String get noServersBody => '通过分享链接、二维码或订阅地址添加。';

  @override
  String get swipeTest => '测速';

  @override
  String get swipeEdit => '编辑';

  @override
  String get serverDetails => '服务器详情';

  @override
  String get latencyFailed => '失败';

  @override
  String get testServers => '测试服务器';

  @override
  String get refreshSubscription => '更新订阅';

  @override
  String get subscriptionActions => '订阅操作';

  @override
  String get deleteSubscription => '删除订阅';

  @override
  String get editSubscription => '编辑订阅';

  @override
  String get subscriptionName => '名称';

  @override
  String get subscriptionUrl => '订阅链接';

  @override
  String get importAction => '导入';

  @override
  String get subscriptionExists => '该订阅已添加';

  @override
  String groupExists(String name) {
    return '名为“$name”的分组已存在';
  }

  @override
  String importFailed(String reason) {
    return '无法导入：$reason';
  }

  @override
  String get scanQrTitle => '扫描二维码';

  @override
  String get cameraDenied => '相机权限已关闭。请在设置中允许以扫描二维码。';

  @override
  String cameraUnavailable(String reason) {
    return '相机不可用：$reason';
  }

  @override
  String get startingCamera => '正在启动相机…';

  @override
  String get pointCamera => '将相机对准包含服务器链接的二维码';

  @override
  String get sectionServer => '服务器';

  @override
  String get fieldName => '名称';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldPort => '端口';

  @override
  String get sectionTransport => '传输';

  @override
  String get fieldType => '类型';

  @override
  String get fieldServiceName => '服务名';

  @override
  String get fieldPath => '路径';

  @override
  String get fieldHostHeader => 'Host 头';

  @override
  String get fieldXhttpMode => '模式';

  @override
  String get fieldPrivateKey => '私钥';

  @override
  String get fieldAddresses => '地址';

  @override
  String get fieldPeerPublicKey => '服务器公钥';

  @override
  String get fieldPresharedKey => '预共享密钥';

  @override
  String get wgObfuscation => 'WireGuard 混淆';

  @override
  String get wgObfuscationHint =>
      '握手前发送垃圾包和 DNS 伪装包，与 Amnezia 相同。适用于任何 WireGuard 服务器';

  @override
  String get wgObfuscationAmneziaServer => '由此 AmneziaWG 服务器设定，无法关闭';

  @override
  String get xrayFragmentation => '分片（Xray）';

  @override
  String get xrayFragmentationHint =>
      '像 Xray 的 \"fragment\" 一样拆分发往服务器的前几个数据包。将替代 TLS 分片';

  @override
  String get xrayPacketsHint => 'tlshello 或写入次数范围，例如 1-3';

  @override
  String get xrayLengthHint => '每片字节数，例如 100-200';

  @override
  String get xrayIntervalHint => '间隔毫秒数，例如 10-20；留空 = 不间隔';

  @override
  String get xrayRangeInvalid => '请输入 N 或 N-M';

  @override
  String get sectionTls => 'TLS';

  @override
  String get useTls => '使用 TLS';

  @override
  String get tlsAlwaysOnQuic => 'QUIC 协议始终开启';

  @override
  String get fieldSni => 'SNI';

  @override
  String get sniHint => '默认使用服务器地址';

  @override
  String get fieldAlpn => 'ALPN';

  @override
  String get alpnHint => '用逗号分隔，例如 h2,http/1.1';

  @override
  String get allowInsecure => '允许不安全';

  @override
  String get allowInsecureHint => '跳过证书验证';

  @override
  String get save => '保存';

  @override
  String get advanced => '高级';

  @override
  String get advancedHint => 'uTLS 指纹、分片、Reality';

  @override
  String get utlsFingerprint => 'uTLS 指纹';

  @override
  String get tlsFragmentation => 'TLS 分片';

  @override
  String get tlsFragmentationHint => '将 ClientHello 拆分到多个 TCP 分段';

  @override
  String get recordFragmentation => '记录分片';

  @override
  String get recordFragmentationHint => '同时拆分为多个 TLS 记录';

  @override
  String get fallbackDelay => '回退延迟（毫秒）';

  @override
  String get fallbackDelayHint => '留空为自动';

  @override
  String get reality => 'Reality';

  @override
  String get publicKey => '公钥';

  @override
  String get shortId => 'Short ID';

  @override
  String get optional => '可选';

  @override
  String get required => '必填';

  @override
  String get portRange => '端口必须在 1–65535 之间';

  @override
  String get realityNeedsTls => 'Reality 需要启用 TLS';

  @override
  String get realityNeedsKey => 'Reality 需要公钥（高级部分）';

  @override
  String get saved => '已保存';

  @override
  String fromProvider(String group) {
    return '来自“$group” · 更新订阅会重置修改';
  }

  @override
  String get addedManually => '手动添加';

  @override
  String get sectionAppearance => '外观';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get sectionConnection => '连接';

  @override
  String get dnsServer => 'DNS 服务器';

  @override
  String get dnsAdguard => 'AdGuard — 拦截广告';

  @override
  String get ipMode => 'IP 版本';

  @override
  String get ipModeHint => '仅在服务器支持 IPv6 时开启，否则网站可能无法打开';

  @override
  String get ipModeV4 => '仅 IPv4';

  @override
  String get ipModeDual => 'IPv4 和 IPv6';

  @override
  String get ipModeV6 => '仅 IPv6';

  @override
  String get splitTunnel => '分应用 VPN';

  @override
  String get splitAll => '所有应用';

  @override
  String get splitOnly => '仅所选应用';

  @override
  String get splitBypass => '除所选应用外';

  @override
  String get splitHintOff => '所有应用都通过 VPN。';

  @override
  String get splitHintOnly => '只有所选应用通过 VPN，其他应用直接连接。';

  @override
  String get splitHintBypass => '所选应用绕过 VPN 直接连接。';

  @override
  String get splitEmptyOnly => '在选择应用之前，所有应用都通过 VPN。';

  @override
  String get splitValueAll => '全部';

  @override
  String splitValueOnly(int count) {
    return '仅 $count 个';
  }

  @override
  String splitValueBypass(int count) {
    return '排除 $count 个';
  }

  @override
  String get premiumDeviceRemoved => '提供商已限制此设备的访问';

  @override
  String get premiumRevoked => '提供商已撤销此订阅';

  @override
  String get premiumUnknown => '此订阅已不存在';

  @override
  String get premiumDeviceLimit => '此链接已添加到最大数量的设备';

  @override
  String get premiumPlanInactive => '该提供商的 WanX 套餐未激活';

  @override
  String get premiumCheckOverdue => '无法验证订阅——联网后请刷新';

  @override
  String get premiumCheckTimeout => '未能验证订阅，请稍后再试。';

  @override
  String get premiumCheckLimit => '今天的验证次数已用完，请明天或换个网络再试。';

  @override
  String get noticeTitle => '开始之前';

  @override
  String get noticeIntro =>
      'WanX 是一个 VPN 客户端：它将你的设备连接到你选择的提供商的服务器或你自己的服务器。具体说明如下。';

  @override
  String get noticeTraffic => '你的流量只发往你选择的 VPN 服务器，从不经过 WanX，我们也不记录。';

  @override
  String get noticeLocal => '无账户、无广告、无分析、无追踪。你的服务器和设置只保存在本设备上。';

  @override
  String get noticeHwid =>
      '添加订阅时，应用会向其提供商发送设备 ID（HWID）、系统版本和机型，以便其限制设备数量。你可以在设置中关闭。';

  @override
  String get noticeLinks =>
      '加密的 wanx:// 链接会由 WanX 服务验证——直接、通过 Google Cloud 或通过你的 VPN 连接——使用在本设备上生成的密钥，以及（如已开启）相同的设备信息。';

  @override
  String get noticeAgree => '同意并继续';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get sourceCode => '源代码';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get searchApps => '搜索应用';

  @override
  String get noApps => '未找到应用';

  @override
  String get bypassLan => '绕过局域网';

  @override
  String get bypassLanHint => '路由器、打印机等局域网设备保持可访问';

  @override
  String get autoConnect => '启动时连接';

  @override
  String get autoConnectHint => '打开应用时连接所选服务器';

  @override
  String get sectionSubscriptions => '订阅';

  @override
  String get updateOnLaunch => '启动时更新';

  @override
  String get updateOnLaunchHint => '打开应用时更新所有订阅';

  @override
  String get sendHwid => '发送设备 ID（HWID）';

  @override
  String get sendHwidHint => '让服务商限制每个订阅的设备数量';

  @override
  String get hwidCopied => '已复制设备 ID';

  @override
  String get newServer => '新服务器';

  @override
  String get serverAdded => '已添加服务器';

  @override
  String get fieldProtocol => '协议';

  @override
  String get sectionAuth => '认证';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldEncryption => '加密方式';

  @override
  String get fieldObfsPassword => '混淆密码（Salamander）';

  @override
  String get fieldCongestion => '拥塞控制';

  @override
  String get none => '无';

  @override
  String get addFromClipboard => '从剪贴板导入';

  @override
  String get addScanQr => '扫描二维码';

  @override
  String get addEnterLink => '输入链接';

  @override
  String get addManually => '手动添加';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get linkHint => '服务器链接或订阅地址 — 自动识别';

  @override
  String get connectionSettingsNote => '连接设置将在下次连接时生效。';

  @override
  String get sectionAbout => '关于';

  @override
  String get appVersion => '应用版本';

  @override
  String get aboutText => '快速、私密的 VPN 客户端。无需账户，没有广告和统计——你的服务器和设置只保存在本设备上。';

  @override
  String addedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已添加 $count 个服务器',
    );
    return '$_temp0';
  }
}
