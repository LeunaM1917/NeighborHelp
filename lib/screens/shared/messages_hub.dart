import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../services/marketplace_service.dart';
import 'inquiry_screen.dart';

class MessagesHub extends StatefulWidget {
  const MessagesHub({
    super.key,
    required this.appUser,
    required this.asCustomer,
    this.listScrollController,
  });
  final AppUser appUser;
  final bool asCustomer;
  final ScrollController? listScrollController;
  static VoidCallback? shellMessagesActivator;
  static final pendingBookingId = ValueNotifier<String?>(null);
  static Future<void> openConversation(
    BuildContext context, {
    required AppUser appUser,
    required Booking booking,
    required bool asCustomer,
  }) async {
    if (shellMessagesActivator != null) {
      pendingBookingId.value = booking.bookingId;
      Navigator.of(context).popUntil((r) => r.isFirst);
      shellMessagesActivator!();
      return;
    }
    final id = await MarketplaceService.bookingInquiry(booking.bookingId);
    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InquiryScreen(appUser: appUser, inquiryId: id),
        ),
      );
    }
  }

  @override
  State<MessagesHub> createState() => _MessagesHubState();
}

class _MessagesHubState extends State<MessagesHub> {
  late Future<void> _sync;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _sync = MarketplaceService.syncBookingConversations();
    MessagesHub.pendingBookingId.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  @override
  void dispose() {
    MessagesHub.pendingBookingId.removeListener(_openPending);
    super.dispose();
  }

  Future<void> _openPending() async {
    final bookingId = MessagesHub.pendingBookingId.value;
    if (_opening || bookingId == null || !mounted) return;
    _opening = true;
    try {
      final id = await MarketplaceService.bookingInquiry(bookingId);
      if (!mounted) return;
      if (MessagesHub.pendingBookingId.value == bookingId) {
        MessagesHub.pendingBookingId.value = null;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InquiryScreen(appUser: widget.appUser, inquiryId: id),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this conversation. Retry from the booking.',
            ),
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Messages',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      FutureBuilder<void>(
        future: _sync,
        builder: (context, snap) {
          if (snap.hasError) {
            return TextButton.icon(
              onPressed: () => setState(() {
                _sync = MarketplaceService.syncBookingConversations();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry loading older booking conversations'),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator(
              semanticsLabel: 'Importing older booking conversations',
            );
          }
          return const SizedBox.shrink();
        },
      ),
      Expanded(
        child: InquiryInbox(
          appUser: widget.appUser,
          scrollController: widget.listScrollController,
        ),
      ),
    ],
  );
}
