import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../services/auth_service.dart';

/// Horizontal scroll + visible scrollbar for wide admin [DataTable]s.
class AdminHorizontalScrollTable extends StatefulWidget {
  const AdminHorizontalScrollTable({
    super.key,
    required this.child,
    this.minTableWidth = 1000,
  });

  final Widget child;
  final double minTableWidth;

  @override
  State<AdminHorizontalScrollTable> createState() => _AdminHorizontalScrollTableState();
}

class _AdminHorizontalScrollTableState extends State<AdminHorizontalScrollTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final minW = math.max(
          viewport.isFinite && viewport > 0 ? viewport : widget.minTableWidth,
          widget.minTableWidth,
        );
        return Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minW),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Styled dropdown for admin table filter toolbars.
Widget adminFilterDropdown({
  required String value,
  required List<String> options,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: FigmaColors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: FigmaColors.gray300),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        isExpanded: true,
        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

/// Search + dropdown filters for admin data tables. Wraps on narrow split-pane columns.
class AdminTableFilterToolbar extends StatelessWidget {
  const AdminTableFilterToolbar({
    super.key,
    required this.search,
    this.filters = const [],
    this.actions = const [],
    this.stackBelowWidth = 520,
  });

  final Widget search;
  final List<Widget> filters;
  final List<Widget> actions;
  final double stackBelowWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        if (w < stackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              for (final f in filters) ...[const SizedBox(height: 12), f],
              for (final a in actions) ...[const SizedBox(height: 12), a],
            ],
          );
        }

        const gap = 10.0;
        final filterCount = filters.length;
        final filterSlot = filterCount == 0
            ? 0.0
            : math.min(152.0, math.max(120.0, (w - 220) / filterCount));
        final reserved = filterCount * (filterSlot + gap) + gap * (actions.length + 1);
        final searchW = math.max(160.0, w - reserved).clamp(160.0, w);

        return Wrap(
          spacing: gap,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(width: searchW, child: search),
            for (final f in filters)
              SizedBox(width: filterSlot, child: f),
            ...actions,
          ],
        );
      },
    );
  }
}

/// Pagination footer that wraps instead of overflowing in narrow table panels.
class AdminTablePaginationBar extends StatelessWidget {
  const AdminTablePaginationBar({
    super.key,
    required this.info,
    required this.controls,
    this.stackBelowWidth = 560,
  });

  final Widget info;
  final Widget controls;
  final double stackBelowWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < stackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 8), controls],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [info, controls],
        );
      },
    );
  }
}

/// Responsive grid for dashboard KPI cards (avoids horizontal overflow).
class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 520 ? 2 : 1;
        const gap = 16.0;
        final cellW = cols == 1
            ? c.maxWidth
            : math.max(150.0, (c.maxWidth - gap * (cols - 1)) / cols);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cellW, child: child),
          ],
        );
      },
    );
  }
}

/// Stacks [main] and optional [side] on narrow widths.
class AdminSplitSection extends StatelessWidget {
  const AdminSplitSection({
    super.key,
    required this.main,
    this.side,
    this.sideWidth = 320,
    this.breakpoint = 720,
  });

  final Widget main;
  final Widget? side;
  final double sideWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    if (side == null) return main;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        if (!w.isFinite || w <= 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, const SizedBox(height: 16), side!],
          );
        }
        if (w < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              const SizedBox(height: 16),
              side!,
            ],
          );
        }
        final sideW = math.min(sideWidth, w * 0.34);
        final mainW = math.max(0.0, w - sideW - 16);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: mainW, child: main),
            const SizedBox(width: 16),
            SizedBox(width: sideW, child: side!),
          ],
        );
      },
    );
  }
}

class AdminFirestoreBanner extends StatelessWidget {
  const AdminFirestoreBanner({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    if (!auth.isLocalAdminOnly) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preview mode: Firestore is unavailable without a Firebase admin account. '
              'Create user admin@neighborhelp.com in Firebase Auth, set users/{uid}.role to '
              'Administrator in Firestore, then sign in with admin / admin123.',
              style: GoogleFonts.inter(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Active admin tab scroll controller (from [AdminShell]).
class AdminShellScrollScope extends InheritedWidget {
  const AdminShellScrollScope({
    super.key,
    required this.scrollController,
    required super.child,
  });

  final ScrollController scrollController;

  static ScrollController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminShellScrollScope>()?.scrollController;
  }

  @override
  bool updateShouldNotify(AdminShellScrollScope oldWidget) =>
      scrollController != oldWidget.scrollController;
}

class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.auth,
    this.useDashboardChrome = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final AuthService? auth;
  /// Overview dashboard supplies its own header inside [child].
  final bool useDashboardChrome;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrollController = AdminShellScrollScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;

        return SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            width: pageWidth,
            child: FigmaWideContainer(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: useDashboardChrome ? 28 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              if (!useDashboardChrome && title != null) ...[
                Text(
                  title!,
                  style: GoogleFonts.inter(
                    color: colorScheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant, fontSize: 15, height: 1.45),
                  ),
                const SizedBox(height: 20),
              ],
              if (auth != null) AdminFirestoreBanner(auth: auth!),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            hint,
            style: GoogleFonts.inter(color: colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class AdminDataPanel extends StatelessWidget {
  const AdminDataPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<DataRow> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No records found.',
                style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            AdminHorizontalScrollTable(
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 72,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
                dataTextStyle: GoogleFonts.inter(fontSize: 13),
                columns: [for (final c in columns) DataColumn(label: Text(c))],
                rows: rows,
              ),
            ),
        ],
      ),
    );
  }
}

class AdminLoadingBox extends StatelessWidget {
  const AdminLoadingBox({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class AdminErrorBox extends StatelessWidget {
  const AdminErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, style: TextStyle(color: colorScheme.error)),
    );
  }
}
