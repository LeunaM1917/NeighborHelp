import '../../l10n/app_strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/conversation_composer.dart';
import '../../widgets/conversation_message.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/inquiry.dart';
import '../../models/booking.dart';
import '../../services/marketplace_service.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/work_completion_card.dart';
import '../customer/contract_offer_screen.dart';
import '../customer/customer_booking_detail_screen.dart';
import '../provider/provider_booking_detail_screen.dart';

class InquiryInbox extends StatelessWidget {
  const InquiryInbox({
    super.key,
    required this.appUser,
    this.scrollController,
    this.conversations,
    this.emptyMessage,
  });
  final AppUser appUser;
  final ScrollController? scrollController;
  final Stream<List<Inquiry>>? conversations;
  final String? emptyMessage;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Inquiry>>(
    stream: conversations ?? MarketplaceService.inbox(appUser.userId),
    builder: (context, snap) {
      if (snap.hasError) {
        return const Center(
          child: Text(
            'Could not load inquiries. Check your connection and retry.',
          ),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.data!.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              emptyMessage ??
                  'No inquiries yet. Customers can open a service and select Message Provider to discuss a job before hiring.',
            ),
          ),
        );
      }
      return ListView(
        controller: scrollController,
        children: [
          for (final t in snap.data!)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.forum_outlined)),
              title: Text(
                appUser.userId == t.customerId
                    ? t.providerName
                    : t.customerName,
              ),
              subtitle: Text(
                '${t.serviceTitle}\n${t.lastMessage}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Icon(
                t.hasDiscussion
                    ? Icons.description_outlined
                    : Icons.chat_bubble_outline,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      InquiryScreen(appUser: appUser, inquiryId: t.id),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({
    super.key,
    required this.appUser,
    required this.inquiryId,
  });
  final AppUser appUser;
  final String inquiryId;
  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  bool _markingRead = false;
  Map<String, String>? _retryMessage;
  Future<void> _retrySend() async {
    final message = _retryMessage;
    if (_sending || message == null) return;
    setState(() => _sending = true);
    try {
      await MarketplaceService.send(
        widget.inquiryId,
        text: message['text']!,
        mediaUrl: message['mediaUrl']!,
        messageId: message['messageId'],
      );
      if (_text.text.trim() == message['text']) _text.clear();
      _retryMessage = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not confirm delivery. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _safetyAction(String action) async {
    String? reason;
    if (action == 'report') {
      final share = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Report this inquiry?')),
          content: const Text(
            'Your explanation and the latest 10 messages will be shared with the system administrator as evidence. Use blocking separately to stop messages and new offers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Continue report')),
            ),
          ],
        ),
      );
      if (share != true || !mounted) return;
      reason = await askRecordedReason(context, 'Explain the concern');
      if (reason == null) return;
    }
    try {
      await MarketplaceService.command('inquiryCommand', {
        'action': action,
        'inquiryId': widget.inquiryId,
        if (reason != null) 'reason': reason,
        if (action == 'report')
          'reportId': FirebaseFirestore.instance
              .collection('bookingUserReports')
              .doc()
              .id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'report'
                  ? 'Report submitted to the system administrator.'
                  : action == 'block'
                  ? 'Conversation blocked.'
                  : 'Your block was removed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save the action. Retry.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send({bool photo = false}) async {
    if (_sending || (!photo && _text.text.trim().isEmpty)) return;
    setState(() => _sending = true);
    try {
      String media = '';
      if (photo) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (picked == null) return;
        media = await StorageService().uploadInquiryImage(
          inquiryId: widget.inquiryId,
          senderId: widget.appUser.userId,
          bytes: await picked.readAsBytes(),
        );
      }
      final messageId =
          _retryMessage?['text'] == (photo ? '' : _text.text.trim()) &&
              _retryMessage?['mediaUrl'] == media
          ? _retryMessage!['messageId']!
          : FirebaseFirestore.instance.collection('inquiries').doc().id;
      _retryMessage = {
        'messageId': messageId,
        'text': photo ? '' : _text.text.trim(),
        'mediaUrl': media,
      };
      await MarketplaceService.send(
        widget.inquiryId,
        text: photo ? '' : _text.text.trim(),
        mediaUrl: media,
        messageId: messageId,
      );
      _retryMessage = null;
      if (!photo) _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Message could not be sent. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Inquiry?>(
    stream: MarketplaceService.inquiry(widget.inquiryId),
    builder: (context, snap) {
      final t = snap.data;
      if (t != null &&
          !_markingRead &&
          (t.data[widget.appUser.userId == t.customerId
                          ? 'customerUnreadCount'
                          : 'providerUnreadCount']
                      as num? ??
                  0) >
              0) {
        _markingRead = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await MarketplaceService.command('inquiryCommand', {
              'action': 'read',
              'inquiryId': t.id,
            });
          } catch (_) {
          } finally {
            _markingRead = false;
          }
        });
      }
      return Scaffold(
        appBar: AppBar(
          actions: [
            if (t != null)
              PopupMenuButton<String>(
                tooltip: context.tr('Conversation safety'),
                onSelected: _safetyAction,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: t.blockedBy.contains(widget.appUser.userId)
                        ? 'unblock'
                        : 'block',
                    child: Text(
                      t.blockedBy.contains(widget.appUser.userId)
                          ? 'Unblock conversation'
                          : 'Block conversation',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Text(context.tr('Report to administrator')),
                  ),
                ],
              ),
          ],
          title: Text(
            t == null
                ? 'Service inquiry'
                : widget.appUser.userId == t.customerId
                ? t.providerName
                : t.customerName,
          ),
        ),
        body: snap.hasError
            ? const Center(
                child: Text(
                  'Conversation unavailable. Check your access and connection.',
                ),
              )
            : t == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .32,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (t.isBlocked)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'This conversation is blocked. Messages and new offers are paused. You can still view history and report a concern.',
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '${t.serviceTitle}\nDiscuss scope, materials, schedule and price. You may compare several providers. Messaging does not reserve a job.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (widget.appUser.userId == t.customerId)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Column(
                                      children: [
                                        FilledButton.icon(
                                          onPressed:
                                              t.hasDiscussion && !t.isBlocked
                                              ? () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        ContractOfferScreen(
                                                          appUser:
                                                              widget.appUser,
                                                          inquiry: t,
                                                        ),
                                                  ),
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.description_outlined,
                                          ),
                                          label: Text(
                                            context.tr(
                                              'Prepare fixed or daily offer',
                                            ),
                                          ),
                                        ),
                                        if (!t.hasDiscussion)
                                          const Text(
                                            'Both parties must send a message before an offer can be sent.',
                                          ),
                                      ],
                                    ),
                                  ),
                                _InquiryOffers(
                                  appUser: widget.appUser,
                                  inquiry: t,
                                ),
                                const Divider(),
                                if (_retryMessage != null && !t.isBlocked)
                                  TextButton.icon(
                                    onPressed: _sending ? null : _retrySend,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text(
                                      'Retry message with uncertain delivery',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: MarketplaceService.messages(t.id),
                                builder: (context, messages) {
                                  if (messages.hasError) {
                                    return const Center(
                                      child: Text('Could not load messages.'),
                                    );
                                  }
                                  if (!messages.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final list = messages.data!.docs.reversed
                                      .toList();
                                  return ListView.builder(
                                    reverse: true,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: list.length,
                                    itemBuilder: (context, i) {
                                      final m = list[i].data(),
                                          mine =
                                              m['senderId'] ==
                                              widget.appUser.userId;
                                      return ConversationMessage(
                                        mine: mine,
                                        senderName: mine
                                            ? 'You'
                                            : (widget.appUser.userId ==
                                                      t.customerId
                                                  ? t.providerName
                                                  : t.customerName),
                                        text: m['text'] as String? ?? '',
                                        mediaUrl:
                                            m['mediaUrl'] as String? ?? '',
                                        sentAt: (m['sentAt'] as Timestamp?)
                                            ?.toDate(),
                                      );
                                    },
                                  );
                                },
                              ),
                        ),
                        ConversationComposer(
                          controller: _text,
                          enabled: !t.isBlocked,
                          sending: _sending,
                          sendLabel: context.tr('Send message'),
                          photoLabel: context.tr('Send photo'),
                          onSend: _send,
                          onPhoto: () => _send(photo: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}

class _InquiryOffers extends StatelessWidget {
  const _InquiryOffers({required this.appUser, required this.inquiry});
  final AppUser appUser;
  final Inquiry inquiry;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Booking>>(
    stream: FirestoreService().bookingsForUser(
      appUser.userId,
      asCustomer: appUser.userId == inquiry.customerId,
    ),
    builder: (context, snap) {
      final offers = (snap.data ?? [])
          .where((b) => b.inquiryId == inquiry.id)
          .toList();
      if (offers.isEmpty) return const SizedBox.shrink();
      return ExpansionTile(
        title: Text('Offers and contracts (${offers.length})'),
        children: [
          for (final b in offers)
            ListTile(
              title: Text(
                '${b.status} - PHP ${b.totalFee?.toStringAsFixed(2) ?? "0"}',
              ),
              subtitle: Text(b.pricingSummary ?? 'Contract offer'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => appUser.userId == inquiry.customerId
                      ? CustomerBookingDetailScreen(
                          appUser: appUser,
                          booking: b,
                        )
                      : ProviderBookingDetailScreen(
                          appUser: appUser,
                          booking: b,
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
