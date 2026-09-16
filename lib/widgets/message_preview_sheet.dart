import 'package:flutter/material.dart';

import 'adaptive_buttons.dart';

/// A bottom sheet that lets the user read and edit a message before an
/// action that would send/plan it on their behalf actually happens, rather
/// than firing that action silently in the background. Pop with the
/// (possibly edited) message text to confirm, or `null` to cancel.
class MessagePreviewSheet extends StatefulWidget {
  const MessagePreviewSheet({
    super.key,
    required this.title,
    required this.recipientName,
    required this.initialMessage,
    required this.confirmLabel,
    required this.confirmIcon,
  });

  final String title;
  final String recipientName;
  final String initialMessage;
  final String confirmLabel;
  final IconData confirmIcon;

  @override
  State<MessagePreviewSheet> createState() => _MessagePreviewSheetState();
}

class _MessagePreviewSheetState extends State<MessagePreviewSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'To ${widget.recipientName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AdaptiveOutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveFilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                  icon: Icon(widget.confirmIcon),
                  label: Text(widget.confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return content;
  }
}
