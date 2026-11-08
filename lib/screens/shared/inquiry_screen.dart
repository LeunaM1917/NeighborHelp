import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/inquiry.dart';
import '../../models/booking.dart';
import '../../services/marketplace_service.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/chat_image.dart';
import '../customer/contract_offer_screen.dart';
import '../customer/customer_booking_detail_screen.dart';
import '../provider/provider_booking_detail_screen.dart';

class InquiryInbox extends StatelessWidget {
  const InquiryInbox({super.key, required this.appUser});
  final AppUser appUser;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Inquiry>>(
    stream: MarketplaceService.inbox(appUser.userId),
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
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No inquiries yet. Customers can open a service and select Message Provider to discuss a job before hiring.',
            ),
          ),
        );
      }
      return ListView(
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
      await MarketplaceService.send(
        widget.inquiryId,
        text: photo ? '' : _text.text.trim(),
        mediaUrl: media,
      );
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
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${t.serviceTitle}\nDiscuss scope, materials, schedule and price. You may compare several providers. Messaging does not reserve a job.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.appUser.userId == t.customerId)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                FilledButton.icon(
                                  onPressed: t.hasDiscussion
                                      ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => ContractOfferScreen(
                                              appUser: widget.appUser,
                                              inquiry: t,
                                            ),
                                          ),
                                        )
                                      : null,
                                  icon: const Icon(Icons.description_outlined),
                                  label: const Text(
                                    'Prepare fixed or daily offer',
                                  ),
                                ),
                                if (!t.hasDiscussion)
                                  const Text(
                                    'Both parties must send a message before an offer can be sent.',
                                  ),
                              ],
                            ),
                          ),
                        _InquiryOffers(appUser: widget.appUser, inquiry: t),
                        const Divider(),
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
                                      return Align(
                                        alignment: mine
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.sizeOf(
                                                  context,
                                                ).width *
                                                .75,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: mine
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if ((m['mediaUrl'] as String? ??
                                                      '')
                                                  .isNotEmpty)
                                                SizedBox(
                                                  width: 240,
                                                  child: ChatImage(
                                                    url:
                                                        m['mediaUrl'] as String,
                                                  ),
                                                ),
                                              if ((m['text'] as String? ?? '')
                                                  .isNotEmpty)
                                                SelectableText(
                                                  m['text'] as String,
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
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: _sending
                                    ? null
                                    : () => _send(photo: true),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                tooltip: 'Send photo',
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _text,
                                  maxLength: 6000,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText: 'Discuss the job…',
                                    counterText: '',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _sending ? null : _send,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                tooltip: 'Send message',
                              ),
                            ],
                          ),
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
      return SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final b in offers)
              SizedBox(
                width: 260,
                child: Card(
                  child: ListTile(
                    title: Text(
                      '${b.status} · ₱${b.totalFee?.toStringAsFixed(2) ?? "0"}',
                    ),
                    subtitle: Text(
                      b.pricingSummary ?? 'Contract offer',
                      maxLines: 2,
                    ),
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
                ),
              ),
          ],
        ),
      );
    },
  );
}
