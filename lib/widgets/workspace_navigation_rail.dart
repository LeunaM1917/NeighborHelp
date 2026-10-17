import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_marketing_assets.dart';
import '../theme/role_theme.dart';

/// A destination keeps its original shell index, even when grouped in a menu.
class WorkspaceNavigationItem {
  const WorkspaceNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.shortLabel,
    this.index,
    this.children = const [],
  }) : assert(index == null || index >= 0);

  final String label;
  final String? shortLabel;
  final IconData icon;
  final IconData? selectedIcon;
  final int? index;
  final List<WorkspaceNavigationItem> children;

  bool contains(int selectedIndex) =>
      index == selectedIndex ||
      children.any((child) => child.contains(selectedIndex));
}

/// A narrow, persistent desktop rail. Only grouped destinations open flyouts.
class WorkspaceNavigationRail extends StatelessWidget {
  const WorkspaceNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.account,
    this.bottomActions,
    this.iconBuilder,
  });

  static const double width = 96;

  final List<WorkspaceNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget? account;
  final Widget? bottomActions;
  final Widget Function(int index, bool selected)? iconBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: IconButton(
            tooltip: 'NeighborHelp home',
            onPressed: () => onSelect(0),
            icon: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                FigmaMarketingAssets.navLogo,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.groups_2_rounded,
                  color: context.roleColors.primary,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        if (account != null)
          Padding(padding: const EdgeInsets.only(bottom: 20), child: account),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                for (final item in items)
                  _NavigationDestination(
                    key: ValueKey(item.label),
                    item: item,
                    currentIndex: currentIndex,
                    onSelect: onSelect,
                    iconBuilder: iconBuilder,
                  ),
              ],
            ),
          ),
        ),
        if (bottomActions != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: bottomActions,
          ),
      ],
    ),
  );
}

/// Touch and keyboard access to the same grouped destinations on small screens.
class WorkspaceNavigationBar extends StatelessWidget {
  const WorkspaceNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<WorkspaceNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _NavigationDestination(
                item: item,
                currentIndex: currentIndex,
                onSelect: onSelect,
                compact: true,
              ),
            ),
        ],
      ),
    ),
  );
}

class _NavigationDestination extends StatefulWidget {
  const _NavigationDestination({
    super.key,
    required this.item,
    required this.currentIndex,
    required this.onSelect,
    this.compact = false,
    this.iconBuilder,
  });

  final WorkspaceNavigationItem item;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool compact;
  final Widget Function(int index, bool selected)? iconBuilder;

  @override
  State<_NavigationDestination> createState() => _NavigationDestinationState();
}

class _NavigationDestinationState extends State<_NavigationDestination> {
  final _menu = MenuController();
  final _buttonFocus = FocusNode();
  final _firstMenuFocus = FocusNode();
  Timer? _closeTimer;
  bool _openedByHover = false;

  void _keepOpen() => _closeTimer?.cancel();

  void _closeLater() {
    if (!_openedByHover) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _menu.isOpen) _menu.close();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _buttonFocus.dispose();
    _firstMenuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = item.contains(widget.currentIndex);
    if (item.children.isEmpty) {
      return _button(context, selected, () => widget.onSelect(item.index!));
    }

    return MenuAnchor(
      controller: _menu,
      childFocusNode: _buttonFocus,
      consumeOutsideTap: true,
      style: MenuStyle(
        alignment: widget.compact ? Alignment.topLeft : Alignment.topRight,
        minimumSize: const WidgetStatePropertyAll(Size(224, 0)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      alignmentOffset: widget.compact ? Offset.zero : const Offset(6, 0),
      onClose: () {
        _keepOpen();
        _openedByHover = false;
      },
      menuChildren: [
        for (final destination in item.children)
          MouseRegion(
            onEnter: (_) => _keepOpen(),
            onExit: (_) => _closeLater(),
            child: MenuItemButton(
              focusNode: destination == item.children.first
                  ? _firstMenuFocus
                  : null,
              onPressed: () => widget.onSelect(destination.index!),
              leadingIcon: Icon(destination.icon, size: 20),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                  destination.index == widget.currentIndex
                      ? context.roleColors.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                backgroundColor: destination.index == widget.currentIndex
                    ? WidgetStatePropertyAll(context.roleColors.tint)
                    : null,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              child: Semantics(
                selected: destination.index == widget.currentIndex,
                child: Text(
                  destination.label,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => MouseRegion(
        onEnter: (_) {
          _keepOpen();
          if (!widget.compact && !controller.isOpen) {
            _openedByHover = true;
            controller.open();
          }
        },
        onExit: (_) => _closeLater(),
        child: _button(context, selected, () {
          _keepOpen();
          _openedByHover = false;
          // Mouse entry may already have opened the flyout before the click.
          // Keep it open for selection; Escape or an outside click dismisses it.
          if (!controller.isOpen) controller.open();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && controller.isOpen) _firstMenuFocus.requestFocus();
          });
        }),
      ),
    );
  }

  Widget _button(BuildContext context, bool selected, VoidCallback onPressed) {
    final item = widget.item;
    final colors = Theme.of(context).colorScheme;
    final role = context.roleColors;
    final icon = item.index != null
        ? widget.iconBuilder?.call(item.index!, selected)
        : null;

    return Semantics(
      selected: selected,
      child: TextButton(
        focusNode: _buttonFocus,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? role.primary : colors.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          minimumSize: Size(widget.compact ? 48 : 84, 72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? role.tint : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  icon ??
                  Icon(
                    selected ? item.selectedIcon ?? item.icon : item.icon,
                    size: 23,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.compact ? item.shortLabel ?? item.label : item.label,
              maxLines: widget.compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.3,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (item.children.isNotEmpty && !widget.compact)
              const Icon(Icons.chevron_right_rounded, size: 12),
          ],
        ),
      ),
    );
  }
}
