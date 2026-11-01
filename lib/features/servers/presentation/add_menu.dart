import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../application/servers_controller.dart';
import '../domain/server.dart';
import 'qr_scanner_page.dart';
import 'server_details_screen.dart';

enum _AddAction { clipboard, qr, link, manual }

/// "Add" drop-down anchored to the button at [anchor]: clipboard, QR,
/// a typed link, or a hand-filled form. Links are recognised automatically
/// as one or more servers or a subscription URL.
Future<void> showAddMenu(BuildContext anchor, WidgetRef ref) async {
  final l10n = anchor.l10n;
  final action = await _menu<_AddAction>(anchor, [
    (_AddAction.clipboard, Icons.content_paste_rounded, l10n.addFromClipboard),
    (_AddAction.qr, Icons.qr_code_scanner_rounded, l10n.addScanQr),
    (_AddAction.link, Icons.link_rounded, l10n.addEnterLink),
    (_AddAction.manual, Icons.edit_note_rounded, l10n.addManually),
  ]);
  if (action == null || !anchor.mounted) return;
  switch (action) {
    case _AddAction.clipboard:
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!anchor.mounted) return;
      if (text == null || text.trim().isEmpty) {
        _snack(anchor, l10n.clipboardEmpty);
        return;
      }
      await importWithFeedback(anchor, ref, text);
    case _AddAction.qr:
      final text = await Navigator.push<String>(
        anchor,
        CupertinoPageRoute(builder: (_) => const QrScannerPage()),
      );
      if (text != null && anchor.mounted) {
        await importWithFeedback(anchor, ref, text);
      }
    case _AddAction.link:
      final text = await showDialog<String>(
        context: anchor,
        builder: (_) => const _LinkDialog(),
      );
      if (text != null && anchor.mounted) {
        await importWithFeedback(anchor, ref, text);
      }
    case _AddAction.manual:
      final protocol = await _menu<ServerProtocol>(anchor, [
        for (final p in ServerProtocol.values) (p, null, p.label),
      ]);
      if (protocol == null || !anchor.mounted) return;
      await Navigator.push(
        anchor,
        CupertinoPageRoute<void>(
          builder: (_) => ServerDetailsScreen.create(protocol: protocol),
        ),
      );
  }
}

/// Pop-up menu right-aligned under [anchor].
Future<T?> _menu<T>(BuildContext anchor, List<(T, IconData?, String)> items) {
  final theme = Theme.of(anchor);
  final colors = AppColors.of(anchor);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  // Opens just below the button, right edges aligned.
  final rect = Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy + box.size.height,
    box.size.width,
    0,
  );
  return showMenu<T>(
    context: anchor,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    color: colors.card,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdAll,
      side: BorderSide(color: colors.cardBorder, width: 0.5),
    ),
    constraints: const BoxConstraints(minWidth: 230),
    items: [
      for (final (value, icon, label) in items)
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
              ],
              Text(label, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
    ],
  );
}

/// Imports [text] as servers or a subscription, with a blocking spinner
/// while a subscription downloads, and reports the result in a snackbar.
Future<void> importWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final l10n = context.l10n;
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  String message;
  try {
    final added = await ref.read(serversProvider.notifier).importAuto(text);
    message = l10n.addedServers(added);
  } on ImportException catch (e) {
    message = switch (e.kind) {
      ImportFailure.duplicateSubscription => l10n.subscriptionExists,
      ImportFailure.duplicateGroup => l10n.groupExists(e.name ?? ''),
      ImportFailure.other => l10n.importFailed(e.message),
    };
  } finally {
    navigator.pop();
  }
  if (context.mounted) _snack(context, message);
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    Navigator.pop(context, _text.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addEnterLink),
      content: TextField(
        controller: _text,
        autofocus: true,
        autocorrect: false,
        minLines: 1,
        maxLines: 5,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: 'vless://…  https://…',
          helperText: l10n.linkHint,
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importAction)),
      ],
    );
  }
}
