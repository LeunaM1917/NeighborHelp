import '../../ui/app_notification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/widgets/figma_status_chip.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/inquiry.dart';
import '../../models/message.dart';
import '../../models/user_role.dart';
import '../../models/service.dart';
import '../../services/messaging_repository.dart';
import '../../services/marketplace_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/chat_image.dart';
import '../../widgets/dispute_case_panel.dart';
import '../../widgets/data_stream_builder.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stream_snapshot.dart';
import '../../widgets/work_completion_card.dart';
import '../customer/customer_service_detail_screen.dart';
import '../customer/customer_booking_detail_screen.dart';
import '../provider/provider_booking_detail_screen.dart';
import '../provider/provider_booking_request_review.dart';

class _Conversation {
  const _Conversation(this.inquiry, this.bookings, this.uid);
  final Inquiry inquiry;
  final List<Booking> bookings;
  final String uid;
  String get threadId => inquiry.id;
  String get customerId => inquiry.customerId;
  String get providerId => inquiry.providerId;
  String get otherUserId => uid == customerId ? providerId : customerId;
  String get name => inquiry.isDispute
      ? 'Dispute · ${inquiry.customerName} / ${inquiry.providerName}'
      : uid == customerId
      ? inquiry.providerName
      : inquiry.customerName;
  Booking? get primaryBooking => bookings.firstOrNull;
}

/// The original conversation list, chat and booking-sidebar layout, backed by
/// canonical inquiries for both pre-contract and historical booking messages.
class MessagesHub extends StatefulWidget {
  const MessagesHub({
    super.key,
    required this.appUser,
    required this.asCustomer,
    this.listScrollController,
    this.syncHistory,
    this.conversations,
    this.repository,
    this.initialInquiryId,
  });
  final AppUser appUser;
  final bool asCustomer;
  final ScrollController? listScrollController;
  final Future<void> Function()? syncHistory;
  final Stream<List<Inquiry>>? conversations;
  final MessagingRepository? repository;
  final String? initialInquiryId;
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
      Navigator.of(context).popUntil((route) => route.isFirst);
      shellMessagesActivator!();
      return;
    }
    final id = await MarketplaceService.bookingInquiry(booking.bookingId);
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Messages')),
          body: RoleThemeScope(
            palette: asCustomer ? RoleTheme.customer : RoleTheme.provider,
            child: MessagesHub(
              appUser: appUser,
              asCustomer: asCustomer,
              initialInquiryId: id,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<MessagesHub> createState() => _MessagesHubState();
}

class _MessagesHubState extends State<MessagesHub> {
  late final MessagingRepository _repository;
  late final Stream<List<Inquiry>> _inbox;
  late final Stream<List<Booking>> _bookings;
  late Future<void> _sync;
  final _searchController = TextEditingController();
  String _search = '', _chatFilter = '';
  String? _selectedId;
  String? _detailsFor;
  AppUser? _otherUser;
  ServiceListing? _service;
  bool _showInfo = true, _opening = false;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MessagingRepository();
    _inbox = widget.conversations ?? _repository.inbox(widget.appUser.userId);
    _bookings = widget.appUser.role == UserRole.administrator
        ? Stream.value(<Booking>[])
        : _repository.bookings(widget.appUser.userId, widget.asCustomer);
    _selectedId = widget.initialInquiryId;
    _sync = _synchronize();
    MessagesHub.pendingBookingId.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  Future<void> _synchronize() => widget.appUser.role == UserRole.administrator
      ? Future.value()
      : Future<void>.sync(widget.syncHistory ?? _repository.synchronize);
  @override
  void dispose() {
    MessagesHub.pendingBookingId.removeListener(_openPending);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPending() async {
    final booking = MessagesHub.pendingBookingId.value;
    if (!mounted || _opening || booking == null) return;
    _opening = true;
    try {
      final id = await _repository.inquiryForBooking(booking);
      if (!mounted) return;
      setState(() {
        _selectedId = id;
        _detailsFor = null;
        _otherUser = null;
        _service = null;
      });
      if (MessagesHub.pendingBookingId.value == booking) {
        MessagesHub.pendingBookingId.value = null;
      }
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

  Future<void> _selectConversation(_Conversation thread) async {
    setState(() {
      _selectedId = thread.threadId;
      _detailsFor = thread.threadId;
      _otherUser = null;
      _service = null;
      _chatFilter = '';
    });
    Future<T?> optional<T>(Future<T?> Function() read) async {
      try {
        return await read().timeout(const Duration(seconds: 12));
      } catch (_) {
        return null;
      }
    }

    if (thread.inquiry.isDispute) return;

    final details = await Future.wait<Object?>([
      optional(() => _repository.user(thread.otherUserId)),
      optional(() => _repository.service(thread.inquiry.serviceId)),
    ]);
    if (!mounted || _selectedId != thread.threadId) return;
    setState(() {
      _otherUser = details[0] as AppUser?;
      _service = details[1] as ServiceListing?;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => ColoredBox(
      color: FigmaColors.gray50,
      child: FigmaWideContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: MobileLayout.isNativeApp(context) ? 8 : 20,
          ),
          child: _MessagesFramedCard(
            height:
                bounds.maxHeight -
                (MobileLayout.isNativeApp(context) ? 16 : 40),
            child: FutureBuilder<void>(
              future: _sync,
              builder: (context, history) => Column(
                children: [
                  if (history.hasError)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _sync = _synchronize();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Retry loading older booking conversations',
                      ),
                    )
                  else if (history.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Importing older booking conversations',
                    ),
                  Expanded(
                    child: DataStreamBuilder<List<Inquiry>>(
                      stream: _inbox,
                      label: 'conversations',
                      onRetry: () => setState(() {
                        _sync = _synchronize();
                      }),
                      builder: (context, snapshot) {
                        final inquiries = snapshot.data ?? [];
                        if (isStreamWaiting(snapshot)) {
                          return const Center(
                            child: LoadingIndicator(
                              message: 'Loading messages…',
                            ),
                          );
                        }
                        return StreamBuilder<List<Booking>>(
                          stream: _bookings,
                          builder: (context, bookings) {
                            final threads = inquiries.map((inquiry) {
                              final related =
                                  (bookings.data ?? <Booking>[])
                                      .where(
                                        (b) => (inquiry.isDispute
                                            ? b.bookingId ==
                                                  inquiry.data['bookingId']
                                            : b.inquiryId == inquiry.id ||
                                                  (b.customerId ==
                                                          inquiry.customerId &&
                                                      b.providerId ==
                                                          inquiry.providerId)),
                                      )
                                      .toList()
                                    ..sort(
                                      (a, b) =>
                                          b.updatedAt.compareTo(a.updatedAt),
                                    );
                              return _Conversation(
                                inquiry,
                                inquiry.isDispute ? <Booking>[] : related,
                                widget.appUser.userId,
                              );
                            }).toList();
                            final selected = threads
                                .where((t) => t.threadId == _selectedId)
                                .firstOrNull;
                            final visible = threads
                                .where(
                                  (t) =>
                                      '${t.name} ${t.inquiry.serviceTitle} ${t.inquiry.lastMessage}'
                                          .toLowerCase()
                                          .contains(_search.toLowerCase()),
                                )
                                .toList();
                            return LayoutBuilder(
                              builder: (context, layout) {
                                final twoPane = layout.maxWidth >= 720,
                                    threePane = layout.maxWidth >= 1024;
                                if (selected != null &&
                                    _detailsFor != selected.threadId) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted &&
                                        _selectedId == selected.threadId &&
                                        _detailsFor != selected.threadId) {
                                      _selectConversation(selected);
                                    }
                                  });
                                }
                                if (_selectedId == null &&
                                    threads.isNotEmpty &&
                                    twoPane) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted && _selectedId == null) {
                                      _selectConversation(threads.first);
                                    }
                                  });
                                }
                                final empty = history.hasError
                                    ? 'Your previous conversations have not loaded. Retry loading older booking conversations above.'
                                    : history.connectionState !=
                                          ConnectionState.done
                                    ? 'Loading previous conversations…'
                                    : 'No conversations yet. Message a provider to discuss a job before hiring.';
                                final list = _ConversationListPane(
                                  threads: visible,
                                  selectedOtherUserId: selected?.otherUserId,
                                  appUser: widget.appUser,
                                  asCustomer: widget.asCustomer,
                                  searchController: _searchController,
                                  listScrollController:
                                      widget.listScrollController,
                                  onSearchChanged: (value) =>
                                      setState(() => _search = value),
                                  onSelect: _selectConversation,
                                  repository: _repository,
                                  emptyMessage: _search.isNotEmpty
                                      ? 'No conversations match your search.'
                                      : empty,
                                );
                                Widget chat({VoidCallback? onBack}) =>
                                    _ChatPane(
                                      key: ValueKey(selected!.threadId),
                                      appUser: widget.appUser,
                                      asCustomer: widget.asCustomer,
                                      thread: selected,
                                      booking: selected.primaryBooking,
                                      otherUser: _otherUser,
                                      service: _service,
                                      chatFilter: _chatFilter,
                                      onChatFilterChanged: (value) =>
                                          setState(() => _chatFilter = value),
                                      onBack: onBack,
                                      onToggleInfo: () => setState(
                                        () => _showInfo = !_showInfo,
                                      ),
                                      infoVisible: _showInfo,
                                      repository: _repository,
                                    );
                                if (!twoPane) {
                                  return selected == null
                                      ? list
                                      : chat(
                                          onBack: () => setState(
                                            () => _selectedId = null,
                                          ),
                                        );
                                }
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: threePane ? 340 : 300,
                                      child: list,
                                    ),
                                    const VerticalDivider(
                                      width: 1,
                                      color: FigmaColors.gray200,
                                    ),
                                    Expanded(
                                      child: selected == null
                                          ? _EmptyChatPlaceholder(
                                              asCustomer: widget.asCustomer,
                                            )
                                          : chat(),
                                    ),
                                    if (threePane &&
                                        _showInfo &&
                                        selected != null) ...[
                                      const VerticalDivider(
                                        width: 1,
                                        color: FigmaColors.gray200,
                                      ),
                                      SizedBox(
                                        width: 300,
                                        child: _InfoPane(
                                          repository: _repository,
                                          appUser: widget.appUser,
                                          asCustomer: widget.asCustomer,
                                          thread: selected,
                                          booking: selected.primaryBooking,
                                          otherUser: _otherUser,
                                          service: _service,
                                          onClose: () =>
                                              setState(() => _showInfo = false),
                                          onMessageSearchChanged: (value) =>
                                              setState(
                                                () => _chatFilter = value,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessagesFramedCard extends StatelessWidget {
  const _MessagesFramedCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.gray200),
        ),
        child: SizedBox(
          height: height.isFinite && height > 0 ? height : null,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

// --- Conversation list (left pane) ---

class _ConversationListPane extends StatelessWidget {
  const _ConversationListPane({
    required this.threads,
    required this.selectedOtherUserId,
    required this.appUser,
    required this.asCustomer,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelect,
    this.listScrollController,
    required this.repository,
    required this.emptyMessage,
  });

  final List<_Conversation> threads;
  final String? selectedOtherUserId;
  final AppUser appUser;
  final bool asCustomer;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_Conversation> onSelect;
  final ScrollController? listScrollController;
  final MessagingRepository repository;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Messages',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Conversation options',
                icon: const Icon(Icons.more_horiz, color: FigmaColors.gray600),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: GoogleFonts.inter(
                color: FigmaColors.gray500,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: FigmaColors.gray500,
              ),
              suffixIcon: IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.tune,
                  size: 20,
                  color: FigmaColors.gray500,
                ),
              ),
              filled: true,
              fillColor: FigmaColors.gray50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: FigmaColors.gray200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: FigmaColors.gray200),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: threads.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(emptyMessage, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  controller: listScrollController,
                  itemCount: threads.length,
                  itemBuilder: (context, i) {
                    final thread = threads[i];
                    return _ConversationTile(
                      thread: thread,
                      repository: repository,
                      selected: thread.otherUserId == selectedOtherUserId,
                      appUser: appUser,
                      asCustomer: asCustomer,
                      onTap: () => onSelect(thread),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.thread,
    required this.selected,
    required this.appUser,
    required this.asCustomer,
    required this.onTap,
    required this.repository,
  });
  final _Conversation thread;
  final bool selected, asCustomer;
  final AppUser appUser;
  final VoidCallback onTap;
  final MessagingRepository repository;
  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser?>(
    future: repository.user(thread.otherUserId),
    builder: (context, userSnap) {
      final name = userSnap.data?.fullName ?? thread.name;
      final subtitle = thread.bookings.length > 1
          ? '${thread.inquiry.serviceTitle} · ${thread.bookings.length} bookings'
          : thread.inquiry.serviceTitle;
      final active = thread.bookings.any((b) => b.isAccepted || b.isInProgress);
      final dateFmt = DateFormat('M/d/yy');
      return Material(
        color: selected ? FigmaColors.gray50 : FigmaColors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected
                      ? context.roleColors.primary
                      : Colors.transparent,
                  width: 3,
                ),
                bottom: const BorderSide(color: FigmaColors.gray100),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarWithStatus(
                  name: name,
                  photoUrl: userSnap.data?.profilePhotoUrl,
                  online: active,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateFmt.format(
                              thread.inquiry.updatedAt.toUtc().add(
                                const Duration(hours: 8),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: FigmaColors.gray500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FigmaColors.gray600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        thread.inquiry.lastMessage,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: FigmaColors.gray500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({
    required this.name,
    this.photoUrl,
    this.online = false,
  });

  final String name;
  final String? photoUrl;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: FigmaColors.gray200,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  _initials(name),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.gray700,
                  ),
                )
              : null,
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: online ? FigmaColors.green : const Color(0xFFEAB308),
              shape: BoxShape.circle,
              border: Border.all(color: FigmaColors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// --- Chat pane (center) ---

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder({required this.asCustomer});

  final bool asCustomer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a conversation',
        style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray500),
      ),
    );
  }
}

class _ChatPane extends StatefulWidget {
  const _ChatPane({
    super.key,
    required this.appUser,
    required this.asCustomer,
    required this.thread,
    required this.booking,
    required this.otherUser,
    required this.service,
    required this.chatFilter,
    required this.onChatFilterChanged,
    this.onBack,
    required this.onToggleInfo,
    this.infoVisible = true,
    required this.repository,
  });
  final AppUser appUser;
  final bool asCustomer;
  final _Conversation thread;
  final Booking? booking;
  final AppUser? otherUser;
  final ServiceListing? service;
  final String chatFilter;
  final ValueChanged<String> onChatFilterChanged;
  final VoidCallback? onBack;
  final VoidCallback onToggleInfo;
  final bool infoVisible;
  final MessagingRepository repository;
  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false, _markingRead = false;
  late Stream<List<ChatMessage>> _messagesStream;
  Map<String, String>? _retryMessage;
  int _messageCount = 0;
  @override
  void initState() {
    super.initState();
    _messagesStream = widget.repository.messages(widget.thread.threadId);
    _markRead();
  }

  @override
  void didUpdateWidget(covariant _ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thread.inquiry.unreadFor(widget.appUser.userId) > 0) _markRead();
  }

  Future<void> _markRead() async {
    if (_markingRead) return;
    _markingRead = true;
    try {
      await widget.repository.command(widget.thread.threadId, 'read');
    } catch (_) {
    } finally {
      _markingRead = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send({bool photo = false}) async {
    if (_sending ||
        widget.thread.inquiry.isBlocked ||
        widget.thread.inquiry.isClosedDispute ||
        (!photo && _controller.text.trim().isEmpty)) {
      return;
    }
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
        media = await widget.repository.uploadPhoto(
          widget.thread.threadId,
          widget.appUser.userId,
          await picked.readAsBytes(),
        );
      }
      final text = photo ? '' : _controller.text.trim();
      final id =
          _retryMessage?['text'] == text && _retryMessage?['mediaUrl'] == media
          ? _retryMessage!['messageId']!
          : widget.repository.newId();
      _retryMessage = {'messageId': id, 'text': text, 'mediaUrl': media};
      await widget.repository.send(
        widget.thread.threadId,
        messageId: id,
        text: text,
        mediaUrl: media,
      );
      _retryMessage = null;
      if (!photo && _controller.text.trim() == text) _controller.clear();
    } catch (e) {
      _showError(e, 'Message could not be sent. Please retry.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retrySend() async {
    final message = _retryMessage;
    if (message == null || _sending || widget.thread.inquiry.isBlocked) return;
    setState(() => _sending = true);
    try {
      await widget.repository.send(
        widget.thread.threadId,
        messageId: message['messageId']!,
        text: message['text']!,
        mediaUrl: message['mediaUrl']!,
      );
      if (_controller.text.trim() == message['text']) _controller.clear();
      _retryMessage = null;
    } catch (e) {
      _showError(
        e,
        'Could not confirm delivery. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(Object error, String fallback) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError ? error.message.toString() : fallback,
          ),
        ),
      );
    }
  }

  void _scrollForNewMessages(List<ChatMessage> messages) {
    if (messages.length == _messageCount) return;
    final nearEnd =
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.offset <
            100;
    _messageCount = messages.length;
    if (nearEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  void _showMobileInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .85,
        child: _InfoPane(
          repository: widget.repository,
          appUser: widget.appUser,
          asCustomer: widget.asCustomer,
          thread: widget.thread,
          booking: widget.booking,
          otherUser: widget.otherUser,
          service: widget.service,
          onClose: () => Navigator.pop(sheet),
          onMessageSearchChanged: widget.onChatFilterChanged,
        ),
      ),
    );
  }

  Future<void> _safetyAction(String action) async {
    String? reason;
    if (action == 'report') {
      final share = await showDialog<bool>(
        context: context,
        builder: (context) => AppNotificationDialog(
          title: const Text('Report this inquiry?'),
          content: const Text(
            'Your explanation and the latest 10 messages will be shared with the system administrator as evidence. Use blocking separately to stop messages and new offers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue report'),
            ),
          ],
        ),
      );
      if (share != true || !mounted) return;
      reason = await askRecordedReason(context, 'Explain the concern');
      if (reason == null) return;
    }
    try {
      await widget.repository.command(
        widget.thread.threadId,
        action,
        data: {
          if (reason != null) 'reason': reason,
          if (action == 'report') 'reportId': widget.repository.newId(),
        },
      );
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
      _showError(e, 'Could not save the action. Retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.otherUser?.fullName ?? widget.thread.name;
    final serviceTitle =
        widget.service?.serviceTitle ?? widget.thread.inquiry.serviceTitle;
    final timeFmt = DateFormat('h:mm a • MMM d');
    final compact = widget.onBack != null || MobileLayout.isNativeApp(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 20,
            vertical: 12,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FigmaColors.gray200)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 14,
                          color: FigmaColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            serviceTitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: FigmaColors.gray600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.thread.inquiry.isDispute || compact)
                PopupMenuButton<String>(
                  tooltip: 'Conversation safety',
                  onSelected: (action) {
                    if (action == 'info') {
                      _showMobileInfo();
                    } else {
                      _safetyAction(action);
                    }
                  },
                  itemBuilder: (_) => [
                    if (compact)
                      const PopupMenuItem(
                        value: 'info',
                        child: Text('Conversation info'),
                      ),
                    if (!widget.thread.inquiry.isDispute)
                      PopupMenuItem(
                        value:
                            widget.thread.inquiry.blockedBy.contains(
                              widget.appUser.userId,
                            )
                            ? 'unblock'
                            : 'block',
                        child: Text(
                          widget.thread.inquiry.blockedBy.contains(
                                widget.appUser.userId,
                              )
                              ? 'Unblock conversation'
                              : 'Block conversation',
                        ),
                      ),
                    if (!widget.thread.inquiry.isDispute)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report to administrator'),
                      ),
                  ],
                ),
              if (!compact) ...[
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.videocam_outlined, size: 22),
                  tooltip: 'Video call',
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  tooltip: 'Schedule',
                ),
                IconButton(
                  onPressed: widget.onToggleInfo,
                  icon: Icon(
                    widget.infoVisible
                        ? Icons.chevron_right
                        : Icons.info_outline,
                    size: 20,
                  ),
                  tooltip: widget.infoVisible
                      ? 'Hide conversation info'
                      : 'Show conversation info',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: DataStreamBuilder<List<ChatMessage>>(
            label: 'messages',
            onRetry: () => setState(
              () => _messagesStream = widget.repository.messages(
                widget.thread.threadId,
              ),
            ),
            stream: _messagesStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load messages.',
                      style: GoogleFonts.inter(color: FigmaColors.gray600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (isStreamWaiting(snap)) {
                return const Center(
                  child: LoadingIndicator(message: 'Loading messages…'),
                );
              }
              var messages = snap.data ?? [];
              _scrollForNewMessages(messages);
              if (widget.chatFilter.isNotEmpty) {
                final q = widget.chatFilter.toLowerCase();
                messages = messages
                    .where(
                      (m) => (m.messageText ?? '').toLowerCase().contains(q),
                    )
                    .toList();
              }

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  if (widget.booking != null)
                    _BookingContextCard(
                      booking: widget.booking!,
                      service: widget.service,
                      appUser: widget.appUser,
                      asCustomer: widget.asCustomer,
                    ),
                  const SizedBox(height: 20),
                  if (messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Send a message to start the conversation.',
                        style: GoogleFonts.inter(color: FigmaColors.gray500),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final m in messages) ...[
                      _MessageBlock(
                        message: m,
                        senderName: m.senderId == widget.appUser.userId
                            ? 'You'
                            : widget.thread.inquiry.isDispute
                            ? '${m.senderName}${m.senderRole == 'Administrator' ? ' · Administrator' : ''}'
                            : name,
                        photoUrl: m.senderId == widget.appUser.userId
                            ? widget.appUser.profilePhotoUrl
                            : widget.thread.inquiry.isDispute
                            ? null
                            : widget.otherUser?.profilePhotoUrl,
                        timeLabel: timeFmt.format(
                          m.sentAt.toDate().toUtc().add(
                            const Duration(hours: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                ],
              );
            },
          ),
        ),
        if (widget.thread.inquiry.isBlocked)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'This conversation is blocked. Messages and new offers are paused. You can still view history and report a concern.',
            ),
          ),
        if (widget.thread.inquiry.isClosedDispute)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'This dispute is closed. Its messages, evidence and recorded outcome remain available.',
            ),
          ),
        if (_retryMessage != null &&
            !widget.thread.inquiry.isBlocked &&
            !widget.thread.inquiry.isClosedDispute)
          TextButton.icon(
            onPressed: _sending ? null : _retrySend,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry message with uncertain delivery'),
          ),
        _MessageComposer(
          enabled:
              !widget.thread.inquiry.isBlocked &&
              !widget.thread.inquiry.isClosedDispute,
          controller: _controller,
          sending: _sending,
          onSend: _send,
          onAttach: () => _send(photo: true),
        ),
      ],
    );
  }
}

class _BookingContextCard extends StatelessWidget {
  const _BookingContextCard({
    required this.booking,
    required this.service,
    required this.appUser,
    required this.asCustomer,
  });

  final Booking booking;
  final ServiceListing? service;
  final AppUser appUser;
  final bool asCustomer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service?.serviceTitle ?? 'Booking',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${booking.status} • ${booking.scheduledWindowLabel}',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
          ),
          if (booking.serviceLocation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              booking.serviceLocation,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FigmaColors.gray500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                if (asCustomer) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerBookingDetailScreen(
                        appUser: appUser,
                        booking: booking,
                      ),
                    ),
                  );
                } else if (booking.isPending) {
                  showProviderBookingRequestReview(
                    context,
                    appUser: appUser,
                    booking: booking,
                  );
                } else {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderBookingDetailScreen(
                        appUser: appUser,
                        booking: booking,
                      ),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: FigmaColors.green,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View details',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({
    required this.message,
    required this.senderName,
    required this.timeLabel,
    this.photoUrl,
  });

  final ChatMessage message;
  final String senderName;
  final String timeLabel;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: FigmaColors.gray200,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  _initials(senderName),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    senderName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FigmaColors.gray500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (message.mediaUrl?.isNotEmpty == true)
                ChatImage(url: message.mediaUrl!),
              Text(
                message.messageText ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: FigmaColors.gray800,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    this.enabled = true,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final compact =
        MobileLayout.isNativeApp(context) ||
        MediaQuery.sizeOf(context).width < 720;
    final rc = context.roleColors;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (enabled && !sending && controller.value.composing.isCollapsed) {
            onSend();
          }
        },
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 20,
          10,
          compact ? 12 : 20,
          compact ? 12 : 16,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: FigmaColors.gray200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              enabled: enabled && !sending,
              maxLength: 6000,
              controller: controller,
              minLines: compact ? 1 : 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Send a message…',
                counterText: '',
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500),
                filled: true,
                fillColor: FigmaColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaColors.gray300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaColors.gray300),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              onSubmitted: (_) {
                if (enabled && !sending) onSend();
              },
            ),
            if (compact) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: sending || !enabled ? null : onAttach,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach image'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: sending || !enabled ? null : onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: rc.primary,
                    foregroundColor: FigmaColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: sending
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, size: 18),
                  label: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FigmaColors.white,
                          ),
                        )
                      : Text(
                          'Send',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.text_fields, size: 20),
                    color: FigmaColors.gray600,
                  ),
                  IconButton(
                    onPressed: sending || !enabled ? null : onAttach,
                    tooltip: 'Attach an image',
                    icon: const Icon(Icons.attach_file, size: 20),
                    color: FigmaColors.gray600,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                    color: FigmaColors.gray600,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.emoji_emotions_outlined, size: 20),
                    color: FigmaColors.gray600,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    color: FigmaColors.gray600,
                  ),
                  FilledButton(
                    onPressed: sending || !enabled ? null : onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: rc.primary,
                      foregroundColor: FigmaColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FigmaColors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Send',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.send_rounded, size: 18),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPane extends StatefulWidget {
  const _InfoPane({
    required this.repository,
    required this.appUser,
    required this.asCustomer,
    required this.booking,
    required this.thread,
    required this.otherUser,
    required this.service,
    required this.onClose,
    this.onMessageSearchChanged,
  });

  final MessagingRepository repository;
  final AppUser appUser;
  final bool asCustomer;
  final Booking? booking;
  final _Conversation thread;
  final AppUser? otherUser;
  final ServiceListing? service;
  final VoidCallback onClose;
  final ValueChanged<String>? onMessageSearchChanged;

  @override
  State<_InfoPane> createState() => _InfoPaneState();
}

class _InfoPaneState extends State<_InfoPane> {
  @override
  Widget build(BuildContext context) {
    final name = widget.otherUser?.fullName ?? widget.thread.name;
    final roleLabel = widget.asCustomer ? 'Service provider' : 'Customer';

    return ColoredBox(
      color: FigmaColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Hide conversation info',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (widget.thread.inquiry.isDispute) ...[
                  Text(
                    '${widget.thread.inquiry.customerName} ? Customer\n${widget.thread.inquiry.providerName} ? Provider\n${widget.thread.inquiry.data['adminName'] ?? 'System Administrator'} ? Administrator',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  DisputeCasePanel(
                    key: ValueKey(widget.thread.inquiry.reportId),
                    appUser: widget.appUser,
                    reportId: widget.thread.inquiry.reportId,
                    reports: widget.repository.report(
                      widget.thread.inquiry.reportId,
                    ),
                    events: widget.repository.reportEvents(
                      widget.thread.inquiry.reportId,
                    ),
                  ),
                ] else ...[
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: FigmaColors.gray200,
                      backgroundImage: widget.otherUser?.profilePhotoUrl != null
                          ? NetworkImage(widget.otherUser!.profilePhotoUrl!)
                          : null,
                      child: widget.otherUser?.profilePhotoUrl == null
                          ? Text(
                              _initials(name),
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 14,
                        color: FigmaColors.gray500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: FigmaColors.gray600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.booking != null)
                    Text(
                      'Scheduled ${widget.booking!.scheduledWindowLabel}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FigmaColors.gray500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  if (widget.booking != null)
                    TextButton.icon(
                      onPressed: () => _openBooking(
                        context,
                        widget.appUser,
                        widget.asCustomer,
                        widget.booking!,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View booking'),
                    ),
                  if (widget.asCustomer)
                    TextButton.icon(
                      onPressed:
                          widget.service?.isMarketplaceVisible == true &&
                              !widget.thread.inquiry.isBlocked
                          ? () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerServiceDetailScreen(
                                  appUser: widget.appUser,
                                  listing: widget.service!,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Request booking'),
                    ),
                  const SizedBox(height: 20),
                  _InfoExpansion(
                    icon: Icons.timeline_outlined,
                    title: 'Activity timeline',
                    child: widget.booking == null
                        ? const Text('Booking activity will appear here.')
                        : BookingStatusTracker(status: widget.booking!.status),
                  ),
                  if (widget.thread.bookings.length > 1)
                    _InfoExpansion(
                      icon: Icons.history,
                      title: 'Previous offers and bookings',
                      child: Column(
                        children: [
                          for (final b in widget.thread.bookings)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(b.status),
                              subtitle: Text(
                                b.pricingSummary ?? b.scheduledWindowLabel,
                              ),
                              onTap: () => _openBooking(
                                context,
                                widget.appUser,
                                widget.asCustomer,
                                b,
                              ),
                            ),
                        ],
                      ),
                    ),
                  _InfoExpansion(
                    icon: Icons.search,
                    title: 'Search messages',
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter in conversation…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: widget.onMessageSearchChanged,
                    ),
                  ),
                  if (widget.booking != null)
                    _InfoExpansion(
                      icon: Icons.description_outlined,
                      title: 'Booking details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.service?.serviceTitle ?? 'Service',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FigmaStatusChip(status: widget.booking!.status),
                          if (widget.booking!.serviceLocation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.booking!.serviceLocation,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: FigmaColors.gray600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  _InfoExpansion(
                    icon: Icons.folder_outlined,
                    title: 'Files and links',
                    child: Text(
                      'Shared images are available in the conversation.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: FigmaColors.gray500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone conversation (chat + info) — same center/right panes as [MessagesHub].

void _openBooking(
  BuildContext context,
  AppUser user,
  bool asCustomer,
  Booking booking,
) {
  if (!asCustomer && booking.isPending) {
    showProviderBookingRequestReview(context, appUser: user, booking: booking);
    return;
  }
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => asCustomer
          ? CustomerBookingDetailScreen(appUser: user, booking: booking)
          : ProviderBookingDetailScreen(appUser: user, booking: booking),
    ),
  );
}

class _InfoExpansion extends StatelessWidget {
  const _InfoExpansion({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: FigmaColors.gray200),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: FigmaColors.gray700),
        title: Text(
          title,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [child],
      ),
    );
  }
}
