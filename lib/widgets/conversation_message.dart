import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_image.dart';

class ConversationMessage extends StatelessWidget {
  const ConversationMessage({
    super.key,
    required this.mine,
    required this.senderName,
    required this.text,
    required this.mediaUrl,
    this.sentAt,
  });
  final bool mine;
  final String senderName, text, mediaUrl;
  final DateTime? sentAt;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = sentAt == null
        ? ''
        : '${DateFormat('MMM d, h:mm a').format(sentAt!.toUtc().add(const Duration(hours: 8)))} Manila time';
    return Semantics(
      container: true,
      label: '$senderName. $time',
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .8,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: mine ? colors.onPrimaryContainer : colors.onSurfaceVariant,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mediaUrl.isNotEmpty)
                  Semantics(
                    image: true,
                    label: 'Photo sent by $senderName',
                    child: SizedBox(
                      width: 240,
                      child: ChatImage(url: mediaUrl),
                    ),
                  ),
                if (text.isNotEmpty) SelectableText(text),
                if (time.isNotEmpty)
                  Text(time, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
