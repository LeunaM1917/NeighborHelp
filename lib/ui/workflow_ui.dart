import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../figma_ui/figma_colors.dart';
import 'app_ui_kit.dart';

/// Presentation shared by the newer booking, agreement and safety workflows.
/// Scoped to these components so established app pages retain their design.
class WorkflowTheme extends StatelessWidget {
  const WorkflowTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: FigmaColors.gray300),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: FigmaColors.white,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          alignLabelWithHint: true,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: FigmaColors.gray600,
          ),
          floatingLabelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FigmaColors.navy,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: FigmaColors.gray400,
          ),
          helperStyle: GoogleFonts.inter(
            fontSize: 12,
            color: FigmaColors.gray500,
            height: 1.4,
          ),
          counterStyle: GoogleFonts.inter(
            fontSize: 11,
            color: FigmaColors.gray400,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: FigmaColors.navy, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        textTheme: theme.textTheme.copyWith(
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            color: FigmaColors.gray700,
            height: 1.5,
          ),
          titleMedium: WorkflowStyles.sectionTitle,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style:
              theme.filledButtonTheme.style?.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ) ??
              FilledButton.styleFrom(
                minimumSize: const Size(48, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 44),
            foregroundColor: FigmaColors.navy,
            side: const BorderSide(color: FigmaColors.gray300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        expansionTileTheme: theme.expansionTileTheme.copyWith(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          shape: const Border(bottom: BorderSide(color: FigmaColors.gray200)),
          collapsedShape: const Border(
            bottom: BorderSide(color: FigmaColors.gray200),
          ),
          iconColor: FigmaColors.navy,
          collapsedIconColor: FigmaColors.gray500,
        ),
        dividerTheme: const DividerThemeData(
          color: FigmaColors.gray200,
          thickness: 1,
          space: 24,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: GoogleFonts.inter(
          fontSize: 13,
          color: FigmaColors.gray600,
          height: 1.5,
        ),
        child: child,
      ),
    );
  }
}

abstract final class WorkflowStyles {
  static TextStyle get sectionTitle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: FigmaColors.gray900,
    height: 1.4,
  );
}

class WorkflowPage extends StatelessWidget {
  const WorkflowPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.maxWidth = 960,
  });
  final String title, subtitle;
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => WorkflowTheme(
    child: ColoredBox(
      color: FigmaColors.gray50,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 32,
            vertical: constraints.maxWidth < 600 ? 20 : 32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(title: title, subtitle: subtitle),
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1) const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkflowFields extends StatelessWidget {
  const WorkflowFields({super.key, required this.children, this.spacing = 18});
  final List<Widget> children;
  final double spacing;
  @override
  Widget build(BuildContext context) {
    final fields = children
        .where((w) => w is! SizedBox || w.child != null || w.height == null)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          fields[i],
          if (i < fields.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class WorkflowSection extends StatelessWidget {
  const WorkflowSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowHeading(title: title, icon: icon, subtitle: subtitle),
        const SizedBox(height: 24),
        WorkflowFields(children: children),
      ],
    ),
  );
}

class WorkflowHeading extends StatelessWidget {
  const WorkflowHeading({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: FigmaColors.tintBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: FigmaColors.navy),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: WorkflowStyles.sectionTitle),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: FigmaColors.gray500,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class WorkflowNotice extends StatelessWidget {
  const WorkflowNotice({
    super.key,
    required this.child,
    this.icon = Icons.info_outline,
  });
  final Widget child;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FigmaColors.tintBlue,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: FigmaColors.navy),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle.merge(
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: FigmaColors.gray700,
            ),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class WorkflowSurface extends StatelessWidget {
  const WorkflowSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: WorkflowTheme(
      child: AppSurfaceCard(padding: EdgeInsets.zero, child: child),
    ),
  );
}

class WorkflowActions extends StatelessWidget {
  const WorkflowActions({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: constraints.maxWidth < 600 ? constraints.maxWidth : 280,
        child: child,
      ),
    ),
  );
}

class WorkflowDialog extends StatelessWidget {
  const WorkflowDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
  });
  final Widget? title, content;
  final List<Widget>? actions;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => WorkflowTheme(
    child: AlertDialog(
      title: title,
      content: content,
      actions: actions,
      scrollable: scrollable,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: FigmaColors.gray900,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        color: FigmaColors.gray600,
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    ),
  );
}

class WorkflowStatus extends StatelessWidget {
  const WorkflowStatus({super.key, required this.label, required this.status});
  final String label, status;
  @override
  Widget build(BuildContext context) {
    final positive = [
      'approved',
      'resolved',
      'accepted',
      'completed',
    ].contains(status.toLowerCase());
    final negative = ['rejected', 'disputed'].contains(status.toLowerCase());
    final color = positive
        ? FigmaColors.green
        : negative
        ? FigmaColors.red600
        : FigmaColors.navy;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: positive
              ? FigmaColors.tintGreen
              : negative
              ? FigmaColors.red50
              : FigmaColors.tintBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
