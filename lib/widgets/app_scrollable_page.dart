import 'package:flutter/material.dart';

import '../figma_ui/figma_colors.dart';
import 'app_scroll_chrome.dart';

/// Scrollable page body with back-to-top (pushed routes without app shell chrome).
class AppScrollablePage extends StatefulWidget {
  const AppScrollablePage({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
    this.footerClearance = 300,
    this.bottomInset = 28,
  });

  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final double footerClearance;
  final double bottomInset;

  @override
  State<AppScrollablePage> createState() => _AppScrollablePageState();
}

class _AppScrollablePageState extends State<AppScrollablePage> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScrollChrome(
      scrollController: _controller,
      accentColor: widget.accentColor ?? FigmaColors.green,
      bottomInset: widget.bottomInset,
      footerClearance: widget.footerClearance,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
