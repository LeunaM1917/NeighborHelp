import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../figma_ui/widgets/figma_status_chip.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/message.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stream_snapshot.dart';
import '../customer/customer_booking_detail_screen.dart';
import '../provider/provider_booking_detail_screen.dart';
import '../provider/provider_booking_request_review.dart';
import '../../utils/message_thread.dart';

/// Canonical in-app messaging for **Customer** and **Provider** shells.
///
/// Same three-pane layout for both roles: conversation list · chat · info sidebar.
/// Role differences are limited to labels, booking filters, and theme (green vs navy).
class MessagesHub extends StatefulWidget {
  const MessagesHub({
    super.key,
    required this.appUser,
    required this.asCustomer,
    this.listScrollController,
  });

  final AppUser appUser;
  final bool asCustomer;
  /// Shell tab re-tap scroll (conversation list).
  final ScrollController? listScrollController;

  /// Registered by the active customer/provider shell so deep links can switch
  /// to the Messages tab instead of pushing a throwaway conversation page.
  static VoidCallback? shellMessagesActivator;

  /// Booking the in-shell Messages tab should open as soon as it loads.
  static final ValueNotifier<String?> pendingBookingId = ValueNotifier<String?>(null);

  /// Opens a conversation. When a shell is active this jumps to the real
  /// Messages tab (so the dedicated page is used) and selects the booking.
  /// Otherwise it falls back to pushing a standalone conversation page.
  static Future<void> openConversation(
    BuildContext context, {
    required AppUser appUser,
    required Booking booking,
    required bool asCustomer,
  }) {
    final activator = shellMessagesActivator;
    if (activator != null) {
      pendingBookingId.value = booking.bookingId;
      // Drop any detail routes stacked on top of the shell, then reveal the tab.
      Navigator.of(context).popUntil((route) => route.isFirst);
      activator();
      return Future<void>.value();
    }

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoleThemeScope(
          palette: asCustomer ? RoleTheme.customer : RoleTheme.provider,
          child: _MessagesConversationPage(
            appUser: appUser,
            booking: booking,
            asCustomer: asCustomer,
          ),
        ),
      ),
    );
  }

  @override
  State<MessagesHub> createState() => _MessagesHubState();
}

class _MessagesHubState extends State<MessagesHub> {
  MessageConversationThread? _selectedThread;
  Booking? _selected;
  AppUser? _otherUser;
  ServiceListing? _service;
  bool _showInfo = true;
  String _search = '';
  String _chatFilter = '';
  String? _pendingOpenId;
  late final TextEditingController _listSearchController;

  @override
  void initState() {
    super.initState();
    _listSearchController = TextEditingController();
    _pendingOpenId = MessagesHub.pendingBookingId.value;
    MessagesHub.pendingBookingId.addListener(_onPendingChanged);
  }

  @override
  void dispose() {
    MessagesHub.pendingBookingId.removeListener(_onPendingChanged);
    _listSearchController.dispose();
    super.dispose();
  }

  void _onPendingChanged() {
    final id = MessagesHub.pendingBookingId.value;
    if (id != null && mounted) {
      setState(() => _pendingOpenId = id);
    }
  }

  Future<void> _selectConversation(MessageConversationThread thread) async {
    final firestore = FirestoreService();
    final booking = thread.primaryBooking;
    final other = await firestore.getUser(thread.otherUserId);
    final service = await firestore.getService(booking.serviceId);
    if (!mounted) return;
    setState(() {
      _selectedThread = thread;
      _selected = booking;
      _otherUser = other;
      _service = service;
      _chatFilter = '';
    });
  }

  void _clearSelection() => setState(() {
        _selectedThread = null;
        _selected = null;
        _otherUser = null;
        _service = null;
      });

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: FigmaColors.gray50,
          child: FigmaWideContainer(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: MobileLayout.isNativeApp(context) ? 8 : 20,
              ),
              child: _MessagesFramedCard(
                height: constraints.maxHeight - 40,
                child: StreamBuilder<List<Booking>>(
                  stream: firestore.bookingsForUser(widget.appUser.userId, asCustomer: widget.asCustomer),
                  builder: (context, snap) {
          if (isStreamWaiting(snap)) {
            return const Center(child: LoadingIndicator(message: 'Loading messages…'));
          }
          var bookings = (snap.data ?? [])
              .where((b) {
                final s = b.status.toLowerCase();
                return s != 'cancelled' && s != 'canceled';
              })
              .toList();

          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            bookings = bookings
                .where((b) => b.serviceLocation.toLowerCase().contains(q) || b.status.toLowerCase().contains(q))
                .toList();
          }

          if (bookings.isEmpty) {
            return Center(
              child: FigmaEmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No conversations yet',
                message: widget.asCustomer
                    ? 'Book a service to message your provider about the job.'
                    : 'When customers book your services, conversations appear here.',
              ),
            );
          }

          final threads = MessageConversationThread.groupBookings(
            bookings: bookings,
            asCustomer: widget.asCustomer,
          );

          if (_selectedThread != null &&
              !threads.any((t) => t.otherUserId == _selectedThread!.otherUserId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _clearSelection());
          }

          final pendingId = _pendingOpenId;
          if (pendingId != null) {
            MessageConversationThread? targetThread;
            for (final t in threads) {
              if (t.bookingIds.contains(pendingId)) {
                targetThread = t;
                break;
              }
            }
            final openThread = targetThread;
            if (openThread != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_selectedThread?.otherUserId != openThread.otherUserId) {
                  _selectConversation(openThread);
                }
                _pendingOpenId = null;
                if (MessagesHub.pendingBookingId.value == pendingId) {
                  MessagesHub.pendingBookingId.value = null;
                }
              });
            }
          }

          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final threePane = w >= 1024;
              final twoPane = w >= 720;

              if (pendingId == null && _selectedThread == null && threads.isNotEmpty && twoPane) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedThread == null) _selectConversation(threads.first);
                });
              }

              if (!twoPane) {
                if (_selected == null) {
                  return _ConversationListPane(
                    threads: threads,
                    selectedOtherUserId: null,
                    appUser: widget.appUser,
                    asCustomer: widget.asCustomer,
                    searchController: _listSearchController,
                    listScrollController: widget.listScrollController,
                    onSearchChanged: (v) => setState(() => _search = v),
                    onSelect: _selectConversation,
                  );
                }
                return _ChatPane(
                  appUser: widget.appUser,
                  asCustomer: widget.asCustomer,
                  thread: _selectedThread!,
                  booking: _selected!,
                  otherUser: _otherUser,
                  service: _service,
                  chatFilter: _chatFilter,
                  onChatFilterChanged: (v) => setState(() => _chatFilter = v),
                  onBack: _clearSelection,
                  onToggleInfo: () {},
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: threePane ? 340 : 300,
                    child: _ConversationListPane(
                      threads: threads,
                      selectedOtherUserId: _selectedThread?.otherUserId,
                      appUser: widget.appUser,
                      asCustomer: widget.asCustomer,
                      searchController: _listSearchController,
                      listScrollController: widget.listScrollController,
                      onSearchChanged: (v) => setState(() => _search = v),
                      onSelect: _selectConversation,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: FigmaColors.gray200),
                  Expanded(
                    child: _selected == null
                        ? _EmptyChatPlaceholder(asCustomer: widget.asCustomer)
                        : _ChatPane(
                            appUser: widget.appUser,
                            asCustomer: widget.asCustomer,
                            thread: _selectedThread!,
                            booking: _selected!,
                            otherUser: _otherUser,
                            service: _service,
                            chatFilter: _chatFilter,
                            onChatFilterChanged: (v) => setState(() => _chatFilter = v),
                            showInfoInChat: twoPane && !threePane && _showInfo,
                            onToggleInfo: () => setState(() => _showInfo = !_showInfo),
                            infoVisible: _showInfo,
                          ),
                  ),
                  if (threePane && _showInfo && _selected != null) ...[
                    const VerticalDivider(width: 1, color: FigmaColors.gray200),
                    SizedBox(
                      width: 300,
                      child: _InfoPane(
                        appUser: widget.appUser,
                        asCustomer: widget.asCustomer,
                        booking: _selected!,
                        otherUser: _otherUser,
                        service: _service,
                        onClose: () => setState(() => _showInfo = false),
                        onMessageSearchChanged: (v) => setState(() => _chatFilter = v),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Centered white card with side breathing room (matches shell nav width).
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
  });

  final List<MessageConversationThread> threads;
  final String? selectedOtherUserId;
  final AppUser appUser;
  final bool asCustomer;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MessageConversationThread> onSelect;
  final ScrollController? listScrollController;

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
                child: Text('Messages', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () {},
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
              hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20, color: FigmaColors.gray500),
              suffixIcon: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.tune, size: 20, color: FigmaColors.gray500),
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
          child: ListView.builder(
            controller: listScrollController,
            itemCount: threads.length,
            itemBuilder: (context, i) {
              final thread = threads[i];
              return _ConversationTile(
                thread: thread,
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
  });

  final MessageConversationThread thread;
  final bool selected;
  final AppUser appUser;
  final bool asCustomer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final booking = thread.primaryBooking;
    final dateFmt = DateFormat('M/d/yy');

    return FutureBuilder<AppUser?>(
      future: firestore.getUser(thread.otherUserId),
      builder: (context, userSnap) {
        final name = userSnap.data?.fullName ?? (asCustomer ? 'Provider' : 'Customer');
        return FutureBuilder<ServiceListing?>(
          future: firestore.getService(booking.serviceId),
          builder: (context, serviceSnap) {
            final serviceTitle = serviceSnap.data?.serviceTitle ?? 'Service booking';
            final subtitle = thread.bookings.length > 1
                ? '$serviceTitle · ${thread.bookings.length} bookings'
                : serviceTitle;
            final active = thread.bookings.any((b) => _isActiveStatus(b.status));

            return Material(
              color: selected ? FigmaColors.gray50 : FigmaColors.white,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: selected ? context.roleColors.primary : Colors.transparent,
                        width: 3,
                      ),
                      bottom: const BorderSide(color: FigmaColors.gray100),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarWithStatus(name: name, photoUrl: userSnap.data?.profilePhotoUrl, online: active),
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
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      dateFmt.format(booking.updatedAt.toDate()),
                                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                _ConversationPreview(
                                  customerId: thread.customerId,
                                  providerId: thread.providerId,
                                  bookingIds: thread.bookingIds,
                                  appUserId: appUser.userId,
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
      },
    );
  }

  bool _isActiveStatus(String status) {
    final s = status.toLowerCase();
    return s == 'accepted' || s == 'in progress' || s == 'pending';
  }
}

/// Last-message preview for the conversation list (uses replay-cached stream).
class _ConversationPreview extends StatelessWidget {
  const _ConversationPreview({
    required this.customerId,
    required this.providerId,
    required this.bookingIds,
    required this.appUserId,
  });

  final String customerId;
  final String providerId;
  final List<String> bookingIds;
  final String appUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: FirestoreService().messagesForConversationThread(
        customerId: customerId,
        providerId: providerId,
        bookingIds: bookingIds,
      ),
      builder: (context, snap) {
        final style = GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500);
        if (!snap.hasData) {
          return Text('Start a conversation', style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
        }
        final messages = snap.data!;
        if (messages.isEmpty) {
          return Text('Start a conversation', style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
        }
        final last = messages.last;
        var text = last.messageText ?? '';
        if (last.senderId == appUserId) text = 'You: $text';
        if (text.length > 60) text = '${text.substring(0, 60)}…';
        return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({required this.name, this.photoUrl, this.online = false});

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
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.gray700),
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
    this.showInfoInChat = false,
  });

  final AppUser appUser;
  final bool asCustomer;
  final MessageConversationThread thread;
  final Booking booking;
  final AppUser? otherUser;
  final ServiceListing? service;
  final String chatFilter;
  final ValueChanged<String> onChatFilterChanged;
  final VoidCallback? onBack;
  final VoidCallback onToggleInfo;
  final bool infoVisible;
  final bool showInfoInChat;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  late Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirestoreService().messagesForConversationThread(
      customerId: widget.thread.customerId,
      providerId: widget.thread.providerId,
      bookingIds: widget.thread.bookingIds,
    );
    _markRead();
  }

  Future<void> _markRead() async {
    try {
      await FirestoreService().markConversationMessagesRead(
        customerId: widget.thread.customerId,
        providerId: widget.thread.providerId,
        readerId: widget.appUser.userId,
      );
    } catch (_) {
      // Non-fatal — chat still works if mark-read fails.
    }
  }

  @override
  void didUpdateWidget(covariant _ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.threadId != widget.thread.threadId) {
      _messagesStream = FirestoreService().messagesForConversationThread(
        customerId: widget.thread.customerId,
        providerId: widget.thread.providerId,
        bookingIds: widget.thread.bookingIds,
      );
      _markRead();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await FirestoreService().sendTextMessage(
        bookingId: widget.booking.bookingId,
        customerId: widget.thread.customerId,
        providerId: widget.thread.providerId,
        senderId: widget.appUser.userId,
        receiverId: widget.thread.otherUserId,
        text: text,
      );
      _controller.clear();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.otherUser?.fullName ?? (widget.asCustomer ? 'Provider' : 'Customer');
    final serviceTitle = widget.service?.serviceTitle ?? 'Service booking';
    final timeFmt = DateFormat('h:mm a • MMM d');
    final compact = widget.onBack != null || MobileLayout.isNativeApp(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20, vertical: 12),
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
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                      style: GoogleFonts.inter(fontSize: compact ? 15 : 16, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.work_outline, size: 14, color: FigmaColors.gray500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            serviceTitle,
                            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    widget.infoVisible ? Icons.chevron_right : Icons.info_outline,
                    size: 20,
                  ),
                  tooltip: widget.infoVisible ? 'Hide conversation info' : 'Show conversation info',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
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
                return const Center(child: LoadingIndicator(message: 'Loading messages…'));
              }
              var messages = snap.data ?? [];
              if (widget.chatFilter.isNotEmpty) {
                final q = widget.chatFilter.toLowerCase();
                messages = messages
                    .where((m) => (m.messageText ?? '').toLowerCase().contains(q))
                    .toList();
              }

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  _BookingContextCard(
                    booking: widget.booking,
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
                            : name,
                        photoUrl: m.senderId == widget.appUser.userId
                            ? widget.appUser.profilePhotoUrl
                            : widget.otherUser?.profilePhotoUrl,
                        timeLabel: timeFmt.format(m.sentAt.toDate()),
                      ),
                      const SizedBox(height: 16),
                    ],
                ],
              );
            },
          ),
        ),
        _MessageComposer(
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
        if (widget.showInfoInChat)
          SizedBox(
            height: 300,
            child: _InfoPane(
              appUser: widget.appUser,
              asCustomer: widget.asCustomer,
              booking: widget.booking,
              otherUser: widget.otherUser,
              service: widget.service,
              onClose: widget.onToggleInfo,
              onMessageSearchChanged: widget.onChatFilterChanged,
            ),
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
            Text(booking.serviceLocation, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
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
                      builder: (_) => CustomerBookingDetailScreen(appUser: appUser, booking: booking),
                    ),
                  );
                } else if (booking.isPending) {
                  showProviderBookingRequestReview(context, appUser: appUser, booking: booking);
                } else {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderBookingDetailScreen(appUser: appUser, booking: booking),
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
              child: Text('View details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
              ? Text(_initials(senderName), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(senderName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(timeLabel, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.messageText ?? '',
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800, height: 1.5),
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final compact = MobileLayout.isNativeApp(context);
    final rc = context.roleColors;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, compact ? 12 : 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FigmaColors.gray200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: compact ? 1 : 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Send a message…',
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
            onSubmitted: (_) => onSend(),
          ),
          if (compact) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: rc.primary,
                  foregroundColor: FigmaColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: sending
                    ? const SizedBox.shrink()
                    : const Icon(Icons.send_rounded, size: 18),
                label: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                      )
                    : Text('Send', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.text_fields, size: 20), color: FigmaColors.gray600),
                IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file, size: 20), color: FigmaColors.gray600),
                IconButton(onPressed: () {}, icon: const Icon(Icons.auto_awesome_outlined, size: 20), color: FigmaColors.gray600),
                IconButton(onPressed: () {}, icon: const Icon(Icons.emoji_emotions_outlined, size: 20), color: FigmaColors.gray600),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, size: 20), color: FigmaColors.gray600),
                FilledButton(
                  onPressed: sending ? null : onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: rc.primary,
                    foregroundColor: FigmaColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Send', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
    );
  }
}

// --- Info pane (right) ---

class _InfoPane extends StatefulWidget {
  const _InfoPane({
    required this.appUser,
    required this.asCustomer,
    required this.booking,
    required this.otherUser,
    required this.service,
    required this.onClose,
    this.onMessageSearchChanged,
  });

  final AppUser appUser;
  final bool asCustomer;
  final Booking booking;
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
    final name = widget.otherUser?.fullName ?? (widget.asCustomer ? 'Provider' : 'Customer');
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
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: FigmaColors.gray200,
                    backgroundImage: widget.otherUser?.profilePhotoUrl != null
                        ? NetworkImage(widget.otherUser!.profilePhotoUrl!)
                        : null,
                    child: widget.otherUser?.profilePhotoUrl == null
                        ? Text(_initials(name), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_outline, size: 14, color: FigmaColors.gray500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        roleLabel,
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule, size: 14, color: FigmaColors.gray500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Scheduled ${widget.booking.scheduledWindowLabel}',
                        style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    if (widget.asCustomer) {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerBookingDetailScreen(
                            appUser: widget.appUser,
                            booking: widget.booking,
                          ),
                        ),
                      );
                    } else if (widget.booking.isPending) {
                      showProviderBookingRequestReview(
                        context,
                        appUser: widget.appUser,
                        booking: widget.booking,
                      );
                    } else {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderBookingDetailScreen(
                            appUser: widget.appUser,
                            booking: widget.booking,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        color: context.roleColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'View booking',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.roleColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _InfoExpansion(
                  icon: Icons.timeline_outlined,
                  title: 'Activity timeline',
                  child: BookingStatusTracker(status: widget.booking.status),
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
                _InfoExpansion(
                  icon: Icons.description_outlined,
                  title: 'Booking details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.service?.serviceTitle ?? 'Service', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      FigmaStatusChip(status: widget.booking.status),
                      if (widget.booking.serviceLocation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(widget.booking.serviceLocation, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                      ],
                    ],
                  ),
                ),
                _InfoExpansion(
                  icon: Icons.folder_outlined,
                  title: 'Files and links',
                  child: Text(
                    'No files shared yet.',
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone conversation (chat + info) — same center/right panes as [MessagesHub].
class _MessagesConversationPage extends StatefulWidget {
  const _MessagesConversationPage({
    required this.appUser,
    required this.booking,
    required this.asCustomer,
  });

  final AppUser appUser;
  final Booking booking;
  final bool asCustomer;

  @override
  State<_MessagesConversationPage> createState() => _MessagesConversationPageState();
}

class _MessagesConversationPageState extends State<_MessagesConversationPage> {
  AppUser? _otherUser;
  ServiceListing? _service;
  String _chatFilter = '';
  bool _loading = true;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final firestore = FirestoreService();
    final otherId = widget.asCustomer ? widget.booking.providerId : widget.booking.customerId;
    final other = await firestore.getUser(otherId);
    final service = await firestore.getService(widget.booking.serviceId);
    if (!mounted) return;
    setState(() {
      _otherUser = other;
      _service = service;
      _loading = false;
    });
  }

  Widget _buildFramedBody(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingIndicator(message: 'Loading conversation…'));
    }

    final otherId = widget.asCustomer ? widget.booking.providerId : widget.booking.customerId;
    final thread = MessageConversationThread(
      otherUserId: otherId,
      bookings: [widget.booking],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final chat = _ChatPane(
          appUser: widget.appUser,
          asCustomer: widget.asCustomer,
          thread: thread,
          booking: widget.booking,
          otherUser: _otherUser,
          service: _service,
          chatFilter: _chatFilter,
          onChatFilterChanged: (v) => setState(() => _chatFilter = v),
          onBack: wide ? null : () => Navigator.pop(context),
          onToggleInfo: () => setState(() => _showInfo = !_showInfo),
          infoVisible: _showInfo,
          showInfoInChat: !wide && _showInfo,
        );

        if (!wide) return chat;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: chat),
            if (_showInfo) ...[
              const VerticalDivider(width: 1, color: FigmaColors.gray200),
              SizedBox(
                width: 300,
                child: _InfoPane(
                  appUser: widget.appUser,
                  asCustomer: widget.asCustomer,
                  booking: widget.booking,
                  otherUser: _otherUser,
                  service: _service,
                  onClose: () => setState(() => _showInfo = false),
                  onMessageSearchChanged: (v) => setState(() => _chatFilter = v),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  Text('Messages', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, outer) {
                  return FigmaWideContainer(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      child: _MessagesFramedCard(
                        height: outer.maxHeight,
                        child: _buildFramedBody(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoExpansion extends StatelessWidget {
  const _InfoExpansion({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: FigmaColors.gray200),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: FigmaColors.gray700),
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [child],
      ),
    );
  }
}
