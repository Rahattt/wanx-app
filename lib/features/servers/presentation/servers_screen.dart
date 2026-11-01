import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/platform/link_channel.dart';
import '../../vpn/application/vpn_controller.dart';
import '../../vpn/domain/vpn_status.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vpn/application/connection_check.dart';
import '../application/premium_guard.dart';
import '../application/servers_controller.dart';
import '../data/latency_tester.dart';
import '../domain/server.dart';
import '../domain/subscription.dart';
import 'add_menu.dart';
import 'server_details_screen.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components.dart';
import '../../../theme/motion.dart';
import 'widgets/connection_card.dart';
import 'widgets/group_header.dart';
import 'widgets/server_tile.dart';

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServerGroup {
  const _ServerGroup(this.key, this.title, this.subscription, this.servers);

  final String key;
  final String title;
  final Subscription? subscription;
  final List<Server> servers;
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  static const _manualKey = '__manual__';

  final _testing = <String>{};
  final _refreshing = <String>{};

  StreamSubscription<String>? _links;

  ServersController get _servers => ref.read(serversProvider.notifier);

  @override
  void initState() {
    super.initState();
    _runStartupTasks();
    // Tapped wanx:// links add the subscription, as if pasted.
    _links = LinkChannel().links().listen((link) {
      if (mounted) importWithFeedback(context, ref, link);
    });
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  /// Settings › "Update on launch" and "Connect on launch", once per start.
  Future<void> _runStartupTasks() async {
    // Where to check premium links: a signed list, refreshed daily.
    unawaited(
      ref
          .read(checkEndpointsProvider)
          .refresh(ref.read(subscriptionFetcherProvider).download),
    );
    final settings = await ref.read(settingsProvider.future);
    final state = await ref.read(serversProvider.future);
    if (settings.updateSubscriptionsOnLaunch &&
        state.subscriptions.isNotEmpty) {
      // Quietly: failures keep the previous servers.
      await _servers.refreshSubscriptions();
    } else {
      // Sealed copies expire; renew them whatever the setting says.
      await _servers.refreshExpiringSealed();
    }
    if (!settings.autoConnect || !mounted) return;
    // Ask the platform directly: the provider may not have the real status
    // yet, and a running tunnel must not be restarted.
    final status = await ref.read(vpnChannelProvider).status();
    final selected = ref.read(serversProvider).value?.selected;
    if (status.status == VpnStatus.disconnected && selected != null) {
      await ref.read(vpnProvider.notifier).connect(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once the tunnel is up, a due premium-link check goes through it, so
    // it passes even where the WanX service is blocked.
    ref.listen(vpnProvider.select((s) => s.status), (prev, next) {
      if (next == VpnStatus.connected && prev != VpnStatus.connected) {
        final state = ref.read(serversProvider).value;
        final sub = state?.subscriptions
            .where((s) => s.id == state.selected?.subscriptionId)
            .firstOrNull;
        // A link never checked gets its first check now, or disconnects.
        if (sub != null && sub.pending) {
          unawaited(ref.read(premiumGuardProvider).run(sub.id));
        }
        unawaited(_servers.refreshExpiringSealed());
      }
    });
    final servers = ref.watch(serversProvider);
    final vpn = ref.watch(vpnProvider);

    // Fixed header (status, connect button, traffic); only the server
    // list below it scrolls.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SlidableAutoCloseBehavior(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  0,
                ),
                // Status is centred on the screen, independent of the
                // widths of the title and the actions.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ConnectionStatusTitle(status: vpn.status),
                    ),
                    Row(
                      children: [
                        Text(
                          'WanX',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontSize: 28),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (button) => IconButton(
                            tooltip: context.l10n.addServer,
                            onPressed: () => showAddMenu(button, ref),
                            // Outlined, like the power button.
                            icon: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.of(context).accent,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: AppColors.of(context).accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...servers.when(
                loading: () => const [
                  Expanded(child: Center(child: CircularProgressIndicator())),
                ],
                error: (e, _) => [
                  Expanded(
                    child: Center(child: Text(context.l10n.failedToLoad('$e'))),
                  ),
                ],
                data: (state) => [
                  Stack(
                    children: [
                      ConnectionCard(
                        vpn: vpn,
                        traffic: ref.watch(trafficProvider).value,
                        onCheck: () => ref.read(connectionCheckProvider).run(),
                        server: state.selected,
                        onToggle: () => ref
                            .read(vpnProvider.notifier)
                            .toggle(state.selected),
                      ),
                      // Under the title, left of the connect button.
                      Positioned(
                        left: AppSpacing.xs,
                        top: 0,
                        child: IconButton(
                          tooltip: context.l10n.settings,
                          iconSize: 26,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(child: _serverList(state)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverList(ServersState state) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _refresh(state),
          builder: _refreshIndicator,
        ),
        if (state.servers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(onAdd: (button) => showAddMenu(button, ref)),
          )
        else
          for (final group in _groups(state)) ..._groupSlivers(group, state),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  /// Accent ring that fills as you pull, then spins while refreshing.
  static Widget _refreshIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double triggerDistance,
    double indicatorExtent,
  ) {
    final refreshing =
        mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.armed;
    final progress = (pulledExtent / triggerDistance).clamp(0.0, 1.0);
    return Center(
      child: AnimatedOpacity(
        opacity: mode == RefreshIndicatorMode.inactive ? 0 : 1,
        duration: AppMotion.fast,
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            value: refreshing ? null : progress,
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
          ),
        ),
      ),
    );
  }

  List<_ServerGroup> _groups(ServersState state) {
    final subIds = {for (final s in state.subscriptions) s.id};
    final manual = state.servers
        .where(
          (s) => s.subscriptionId == null || !subIds.contains(s.subscriptionId),
        )
        .toList();
    return [
      if (manual.isNotEmpty)
        _ServerGroup(_manualKey, context.l10n.groupManual, null, manual),
      for (final sub in state.subscriptions)
        _ServerGroup(
          sub.id,
          sub.name,
          sub,
          state.servers.where((s) => s.subscriptionId == sub.id).toList(),
        ),
    ];
  }

  List<Widget> _groupSlivers(_ServerGroup group, ServersState state) {
    final sub = group.subscription;
    // The header stays pinned while its servers scroll under it, then is
    // pushed away by the next group's.
    return [
      SliverMainAxisGroup(
        slivers: [
          PinnedHeaderSliver(
            child: ColoredBox(
              color: AppColors.of(context).background,
              child: GroupHeader(
                title: group.title,
                subtitle: sub?.updatedAt == null
                    ? null
                    : context.l10n.updatedAgo(_ago(sub!.updatedAt!)),
                count: group.servers.length,
                onDelete: sub == null ? null : () => _deleteSubscription(sub),
                testing: group.servers.any((s) => _testing.contains(s.id)),
                onTest: group.servers.isEmpty
                    ? null
                    : () => _testServers(group.servers),
                refreshing: sub != null && _refreshing.contains(sub.id),
                onRefresh: sub == null ? null : () => _refreshOne(sub),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: GroupedCard(
                separatorIndent: ServerTile.separatorIndent,
                children: [
                  for (final server in group.servers)
                    ServerTile(
                      server: server,
                      selected: server.id == state.selectedId,
                      testing: _testing.contains(server.id),
                      onTap: () => _select(server.id),
                      onTest: () => _test(server),
                      onEdit: server.isManaged
                          ? null
                          : () => _openDetails(server),
                      onDelete: () => _delete(server, state),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDetails(Server server) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ServerDetailsScreen(serverId: server.id),
      ),
    );
  }

  Future<void> _select(String id) async {
    if (ref.read(serversProvider).value?.selectedId == id) return;
    await _servers.select(id);
    final server = ref.read(serversProvider).value?.byId(id);
    if (server != null) await ref.read(vpnProvider.notifier).reconnect(server);
  }

  Future<void> _test(Server server) async {
    setState(() => _testing.add(server.id));
    try {
      final ms = await _servers.testLatency(server.id);
      if (ms == null && mounted) {
        _snack(context.l10n.noResponseWithin(server.name));
      }
    } on LatencyTestException catch (e) {
      if (mounted) _snack(context.l10n.serverError(server.name, e.message));
    } finally {
      if (mounted) setState(() => _testing.remove(server.id));
    }
  }

  /// Tests a group in parallel; one summary instead of a snack each.
  Future<void> _testServers(List<Server> all) async {
    final pending = all.where((s) => !_testing.contains(s.id)).toList();
    if (pending.isEmpty) return;
    setState(() => _testing.addAll(pending.map((s) => s.id)));
    final results = await Future.wait(
      pending.map((server) async {
        try {
          return await _servers.testLatency(server.id) != null;
        } on LatencyTestException {
          return false;
        } finally {
          if (mounted) setState(() => _testing.remove(server.id));
        }
      }),
    );
    if (!mounted) return;
    final ok = results.where((r) => r).length;
    _snack(context.l10n.serversResponded(ok, results.length));
  }

  Future<void> _refreshOne(Subscription sub) async {
    if (_refreshing.contains(sub.id)) return;
    setState(() => _refreshing.add(sub.id));
    try {
      _snackRefresh(await _servers.refreshSubscriptions(onlyId: sub.id));
    } finally {
      if (mounted) setState(() => _refreshing.remove(sub.id));
    }
  }

  Future<void> _delete(Server server, ServersState state) async {
    final index = state.servers.indexWhere((s) => s.id == server.id);
    await _servers.remove(server.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Snackbars with an action persist by default; this one should
          // go away on its own.
          persist: false,
          duration: const Duration(seconds: 4),
          content: Text(context.l10n.deletedServer(server.name)),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () => _servers.restore(server, index),
          ),
        ),
      );
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) {
        final ios = Theme.of(context).platform == TargetPlatform.iOS;
        Widget action(String label, bool value, {bool destructive = false}) =>
            ios
            ? CupertinoDialogAction(
                isDestructiveAction: destructive,
                isDefaultAction: !destructive,
                onPressed: () => Navigator.pop(context, value),
                child: Text(label),
              )
            : TextButton(
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, value),
                child: Text(label),
              );
        return AlertDialog.adaptive(
          title: Text(context.l10n.deleteSubscriptionTitle(sub.name)),
          content: Text(context.l10n.deleteSubscriptionBody),
          actions: [
            action(context.l10n.cancel, false),
            action(context.l10n.delete, true, destructive: true),
          ],
        );
      },
    );
    if (confirmed == true) await _servers.removeSubscription(sub.id);
  }

  Future<void> _refresh(ServersState state) async {
    if (state.subscriptions.isEmpty) {
      _snack(context.l10n.noSubscriptionsToRefresh);
      return;
    }
    _snackRefresh(await _servers.refreshSubscriptions());
  }

  void _snackRefresh(RefreshResult result) {
    if (!mounted) return;
    final total = result.updated.values.fold(0, (a, b) => a + b);
    final parts = [
      if (result.updated.isNotEmpty)
        context.l10n.subscriptionsUpdated(result.updated.length, total),
      for (final MapEntry(:key, :value) in result.failures.entries)
        '$key: $value',
    ];
    _snack(parts.join('\n'));
  }

  String _ago(DateTime time) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.agoJustNow;
    if (diff.inHours < 1) return l10n.agoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.agoHours(diff.inHours);
    return l10n.agoDays(diff.inDays);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  /// Gets the button's context to anchor the menu.
  final void Function(BuildContext button) onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    // Settles in gently on first show.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.xxl * 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.dns_rounded, size: 32, color: colors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.noServersTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.noServersBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Builder(
              builder: (button) => FilledButton.icon(
                onPressed: () => onAdd(button),
                icon: const Icon(Icons.add_rounded),
                label: Text(context.l10n.addServer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
