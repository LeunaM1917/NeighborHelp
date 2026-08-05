import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';

/// Help dropdown anchored under the top-bar help icon (same pattern as notifications).
class HelpSupportPopover {
  HelpSupportPopover._();

  static OverlayEntry? _entry;

  static void toggle(
    BuildContext context, {
    GlobalKey? anchorKey,
    required String roleLabel,
  }) {
    if (_entry != null) {
      hide();
      return;
    }

    if (MobileLayout.useBottomSheets(context)) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scrollController) => _HelpSheet(
            roleLabel: roleLabel,
            scrollController: scrollController,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      return;
    }

    final screen = MediaQuery.sizeOf(context);
    const popupWidth = 400.0;
    const maxHeight = 420.0;

    double left;
    double top;

    if (anchorKey != null) {
      final anchorContext = anchorKey.currentContext;
      final box = anchorContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final anchorOffset = box.localToGlobal(Offset.zero);
      final anchorSize = box.size;
      left = anchorOffset.dx + anchorSize.width - popupWidth;
      top = anchorOffset.dy + anchorSize.height + 10;
    } else {
      left = screen.width - popupWidth - 12;
      top = 74;
    }

    left = left.clamp(12.0, screen.width - popupWidth - 12.0);

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: hide,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: Material(
              color: Colors.transparent,
              child: _HelpDropdown(
                roleLabel: roleLabel,
                maxHeight: maxHeight,
                onClose: hide,
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  /// Opens the help panel (e.g. from Profile settings without an anchor key).
  static void show(BuildContext context, {required String roleLabel}) {
    hide();
    toggle(context, roleLabel: roleLabel);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({
    required this.roleLabel,
    required this.scrollController,
    required this.onClose,
  });

  final String roleLabel;
  final ScrollController scrollController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: _HelpDropdown(
          roleLabel: roleLabel,
          maxHeight: double.infinity,
          onClose: onClose,
          scrollController: scrollController,
          showHeaderClose: false,
        ),
      ),
    );
  }
}

class _HelpDropdown extends StatelessWidget {
  const _HelpDropdown({
    required this.roleLabel,
    required this.maxHeight,
    required this.onClose,
    this.scrollController,
    this.showHeaderClose = true,
  });

  final String roleLabel;
  final double maxHeight;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final bool showHeaderClose;

  List<_HelpTopic> get _topics => [
        _HelpTopic(
          icon: Icons.explore_outlined,
          title: 'Getting started',
          body: roleLabel == 'Customer'
              ? 'Browse services, pick a provider, and send a booking request. Track status under Bookings.'
              : 'Add services under Services, respond to jobs under Jobs, and keep your availability updated.',
        ),
        _HelpTopic(
          icon: Icons.chat_bubble_outline,
          title: 'Messages',
          body: 'Open Messages to chat with the other party about an active booking.',
        ),
        _HelpTopic(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          body: 'Tap the bell icon in the top bar for booking updates and platform announcements.',
        ),
        _HelpTopic(
          icon: Icons.mail_outline,
          title: 'Contact',
          body: 'Email support@neighborhelp.com for account or safety issues.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 44, 8),
                  child: Text(
                    'Help & support',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                ),
                if (scrollController != null)
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _topics.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: FigmaColors.gray200),
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        return _HelpRow(topic: topic, accent: role.primary);
                      },
                    ),
                  )
                else
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: _topics.length > 3,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _topics.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: FigmaColors.gray200),
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          return _HelpRow(topic: topic, accent: role.primary);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            if (showHeaderClose)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  style: IconButton.styleFrom(
                    foregroundColor: FigmaColors.gray600,
                    hoverColor: FigmaColors.gray100,
                  ),
                ),
              )
            else
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HelpTopic {
  const _HelpTopic({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.topic, required this.accent});

  final _HelpTopic topic;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.white,
      child: InkWell(
        onTap: () {},
        hoverColor: FigmaColors.gray50,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(topic.icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.body,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
