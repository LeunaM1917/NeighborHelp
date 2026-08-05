import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/message.dart';
import '../../services/firestore_service.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stream_snapshot.dart';

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
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await FirestoreService().sendTextMessage(
        bookingId: widget.booking.bookingId,
        customerId: widget.booking.customerId,
        providerId: widget.booking.providerId,
        senderId: widget.appUser.userId,
        receiverId: widget.otherPartyId,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final firestore = FirestoreService();
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            FigmaWideContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AppPageHeader(
                  title: widget.otherPartyName,
                  subtitle: 'Booking conversation',
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: firestore.messagesForConversationThread(
                  customerId: widget.booking.customerId,
                  providerId: widget.booking.providerId,
                  bookingIds: [widget.booking.bookingId],
                ),
                builder: (context, snap) {
                  if (isStreamWaiting(snap)) {
                    return const Center(child: LoadingIndicator(message: 'Loading messages…'));
                  }
                  final messages = snap.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Send a message about this booking.',
                        style: GoogleFonts.inter(color: FigmaColors.gray500),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m.senderId == widget.appUser.userId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? rc.primary : FigmaColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: mine ? null : Border.all(color: FigmaColors.gray200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.messageText ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: mine ? FigmaColors.white : FigmaColors.gray900,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeFmt.format(m.sentAt.toDate()),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: mine ? FigmaColors.white.withValues(alpha: 0.7) : FigmaColors.gray400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Material(
              color: FigmaColors.white,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: FigmaColors.gray200)),
                ),
                child: FigmaWideContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Type a message…',
                              hintStyle: GoogleFonts.inter(color: FigmaColors.gray500),
                              filled: true,
                              fillColor: FigmaColors.gray50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: FigmaColors.gray200),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _sending ? null : _send,
                          style: FilledButton.styleFrom(
                            backgroundColor: rc.primary,
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white))
                              : const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
