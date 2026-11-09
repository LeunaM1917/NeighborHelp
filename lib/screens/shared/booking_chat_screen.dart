import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../services/marketplace_service.dart';
import 'inquiry_screen.dart';

/// Booking and pre-contract chat share the same protected conversation.
class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({
    super.key,
    required this.appUser,
    required this.booking,
    required this.otherPartyName,
    required this.otherPartyId,
  });
  final AppUser appUser;
  final Booking booking;
  final String otherPartyName;
  final String otherPartyId;
  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  late Future<String> _thread;
  @override
  void initState() {
    super.initState();
    _thread = MarketplaceService.bookingInquiry(widget.booking.bookingId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _thread,
    builder: (context, snap) {
      if (snap.hasData) {
        return InquiryScreen(appUser: widget.appUser, inquiryId: snap.data!);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: Center(
          child: snap.hasError
              ? FilledButton(
                  onPressed: () => setState(() {
                    _thread = MarketplaceService.bookingInquiry(
                      widget.booking.bookingId,
                    );
                  }),
                  child: const Text('Retry loading conversation'),
                )
              : const CircularProgressIndicator(
                  semanticsLabel: 'Loading conversation history',
                ),
        ),
      );
    },
  );
}
