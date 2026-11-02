import 'package:flutter/material.dart';

/// A popup scrollbar and its scroll view always share one owned controller.
class ManagedScrollbar extends StatefulWidget {
  const ManagedScrollbar({
    super.key,
    required this.builder,
    this.thumbVisibility = false,
  });
  final Widget Function(ScrollController controller) builder;
  final bool thumbVisibility;

  @override
  State<ManagedScrollbar> createState() => _ManagedScrollbarState();
}

class _ManagedScrollbarState extends State<ManagedScrollbar> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: widget.thumbVisibility,
    child: widget.builder(_controller),
  );
}
