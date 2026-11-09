import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    required this.onPhoto,
    this.sendLabel = 'Send message',
    this.photoLabel = 'Send photo',
  });
  final TextEditingController controller;
  final bool enabled, sending;
  final VoidCallback onSend, onPhoto;
  final String sendLabel, photoLabel;
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
        if (enabled && !sending && controller.value.composing.isCollapsed) {
          onSend();
        }
      },
    },
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: photoLabel,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: enabled && !sending ? onPhoto : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled && !sending,
              maxLength: 6000,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Discuss the job',
                helperText: 'Ctrl+Enter sends',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: sendLabel,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: enabled && !sending ? onSend : null,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Sending message',
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}
