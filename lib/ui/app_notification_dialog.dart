import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared notice/confirmation surface. Editing forms keep their own dialogs.
class AppNotificationDialog extends StatelessWidget {
  const AppNotificationDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
  });

  static const preferredSize = Size(560, 360);
  static const surfaceKey = ValueKey('app-notification-surface');
  final Widget? title, content, icon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor:
        Theme.of(context).dialogTheme.backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    constraints: BoxConstraints(
      minWidth: 0,
      maxWidth: preferredSize.width,
      maxHeight: preferredSize.height,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: SizedBox(
      key: surfaceKey,
      width: preferredSize.width,
      height: preferredSize.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 300 ||
              (constraints.maxWidth < 420 && (actions?.length ?? 0) > 2) ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final buttons = actions ?? const <Widget>[];
          final footer = Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: buttons,
            ),
          );
          final message = Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: DefaultTextStyle.merge(
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: content ?? const SizedBox.shrink(),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 12)],
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .4,
                        ),
                        child: SingleChildScrollView(
                          child: DefaultTextStyle.merge(
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            child: title ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      message,
                      if (compact && buttons.isNotEmpty) footer,
                    ],
                  ),
                ),
              ),
              if (!compact && buttons.isNotEmpty) footer,
            ],
          );
        },
      ),
    ),
  );
}
