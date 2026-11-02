import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../theme/app_theme.dart';

/// Name and URL of a plain subscription; pops `(name, url)` on save.
class EditSubscriptionDialog extends StatefulWidget {
  const EditSubscriptionDialog({
    super.key,
    required this.name,
    required this.url,
  });

  final String name;
  final String url;

  @override
  State<EditSubscriptionDialog> createState() => _EditSubscriptionDialogState();
}

class _EditSubscriptionDialogState extends State<EditSubscriptionDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _url = TextEditingController(text: widget.url);

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _url.text.trim().isEmpty) return;
    Navigator.pop(context, (_name.text.trim(), _url.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.editSubscription),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.subscriptionName),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _url,
            autocorrect: false,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l10n.subscriptionUrl),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
