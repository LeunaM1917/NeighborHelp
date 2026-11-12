import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/notification.dart';
import '../models/provider.dart';
import '../models/service.dart';
import '../models/user_role.dart';
import '../theme/role_theme.dart';
import '../utils/notification_destination.dart';
import '../widgets/dispute_case_panel.dart';
import '../screens/admin/widgets/admin_table_details.dart';
import '../screens/admin/widgets/admin_detail_dialog.dart';
import '../screens/customer/customer_booking_detail_screen.dart';
import '../screens/customer/customer_service_detail_screen.dart';
import '../screens/provider/provider_booking_detail_screen.dart';
import '../screens/shared/inquiry_screen.dart';
import '../screens/shared/messages_hub.dart';

class NotificationNavigationScope extends InheritedWidget {
  const NotificationNavigationScope({super.key, required this.onSelectTab, required super.child});
  final ValueChanged<int> onSelectTab;
  static ValueChanged<int>? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NotificationNavigationScope>()?.onSelectTab;
  @override
  bool updateShouldNotify(NotificationNavigationScope oldWidget) => onSelectTab != oldWidget.onSelectTab;
}

typedef NotificationRecordReader = Future<Map<String, dynamic>?> Function(String collection, String id);

/// Fresh, rules-protected reads plus participant checks keep stale notifications
/// from opening a deleted record or another member's private information.
class NotificationRecordLoader {
  NotificationRecordLoader({NotificationRecordReader? read}) : _reader = read ?? _firestoreRead;
  final NotificationRecordReader _reader;
  static Future<Map<String, dynamic>?> _firestoreRead(String collection, String id) async =>
    (await FirebaseFirestore.instance.collection(collection).doc(id).get(const GetOptions(source: Source.server))).data();
  Future<Map<String, dynamic>> read(String collection, String id) async {
    if (id.isEmpty || id.contains('/') || id.length > 1500) throw StateError('Unavailable record');
    final data = await _reader(collection, id);
    if (data == null) throw StateError('Unavailable record');
    return data;
  }
  Future<Booking> booking(String id, AppUser user) async {
    final data = await read('bookings', id);
    if (user.role != UserRole.administrator && ![data['customerId'], data['providerId']].contains(user.userId)) throw StateError('Unavailable record');
    return Booking.fromFirestore(id, data);
  }
  Future<void> conversation(String id, AppUser user) async {
    final data = await read('inquiries', id);
    final participants = data['participantIds'];
    if (participants is! List || !participants.contains(user.userId)) throw StateError('Unavailable conversation');
  }
  Future<Map<String, dynamic>> report(String id, AppUser user) async {
    final data = await read('bookingUserReports', id);
    if (user.role != UserRole.administrator && ![data['reporterId'], data['reportedUserId']].contains(user.userId)) throw StateError('Unavailable record');
    return data;
  }
  Future<ServiceListing> service(String id, AppUser user) async {
    final service = ServiceListing.fromFirestore(id, await read('services', id));
    if (user.role != UserRole.administrator && service.providerId != user.userId &&
        (user.role != UserRole.customer || !service.isMarketplaceVisible)) throw StateError('Unavailable record');
    return service;
  }
  Future<ServiceProviderProfile> certificateOwner(String id, AppUser user) async {
    if (user.role != UserRole.administrator && user.role != UserRole.provider) throw StateError('Unavailable record');
    final data = await read('serviceProviders', id);
    if (user.role != UserRole.administrator && (data['userId'] ?? id) != user.userId) throw StateError('Unavailable record');
    return ServiceProviderProfile.fromFirestore(id, data);
  }
}

class NotificationNavigator {
  NotificationNavigator({NotificationRecordLoader? records}) : records = records ?? NotificationRecordLoader();
  final NotificationRecordLoader records;

  Future<void> open(BuildContext context, {required AppUser user, required AppNotification note, ValueChanged<int>? onSelectTab}) async {
    final select = onSelectTab ?? NotificationNavigationScope.maybeOf(context);
    final destination = notificationDestination(note, user.role);
    try {
      if (note.userId != user.userId) throw StateError('Unavailable notification');
      final admin = user.role == UserRole.administrator;
      switch (destination.kind) {
        case NotificationDestinationKind.section:
          if (select != null && destination.tab != null) { select(destination.tab!); return; }
          if (context.mounted) _details(context, user, note.title, {'Message': note.message});
        case NotificationDestinationKind.details:
          _details(context, user, note.title, {'Message': note.message, 'Type': note.notificationType});
        case NotificationDestinationKind.booking:
          final booking = await records.booking(destination.id!, user);
          if (!context.mounted) return;
          if (admin) {
            select?.call(7);
            showAdminOverviewBookingDetail(context, booking: booking, usersById: const {}, servicesById: const {}, onViewAllBookings: select == null ? null : () => select(7));
          } else {
            select?.call(2);
            _push(context, user, user.role == UserRole.customer
              ? CustomerBookingDetailScreen(appUser: user, booking: booking)
              : ProviderBookingDetailScreen(appUser: user, booking: booking));
          }
        case NotificationDestinationKind.conversation:
          if (destination.ownerId == 'booking') {
            final booking = await records.booking(destination.id!, user);
            if (!context.mounted) return;
            if (admin) throw StateError('Private conversations require case participation');
            await MessagesHub.openConversation(context, appUser: user, booking: booking, asCustomer: user.role == UserRole.customer);
          } else {
            await records.conversation(destination.id!, user);
            if (!context.mounted) return;
            if (!admin) select?.call(3);
            _push(context, user, InquiryScreen(appUser: user, inquiryId: destination.id!));
          }
        case NotificationDestinationKind.service:
          final service = await records.service(destination.id!, user);
          if (!context.mounted) return;
          if (user.role == UserRole.customer) {
            select?.call(1);
            _push(context, user, CustomerServiceDetailScreen(appUser: user, listing: service));
          } else {
            select?.call(admin ? 6 : 1);
            _details(context, user, service.serviceTitle, {'Service ID': service.serviceId, 'Category': service.category,
              'Status': service.approvalStatus.name, 'Description': service.description,
              'Price': 'PHP ${service.estimatedPrice.toStringAsFixed(2)} (${service.priceType})',
              if (service.rejectionReason.isNotEmpty) 'Rejection reason': service.rejectionReason},
              select: select, tab: admin ? 6 : 1, action: 'Open services');
          }
        case NotificationDestinationKind.certificate:
          final owner = destination.ownerId ?? user.userId;
          final profile = await records.certificateOwner(owner, user);
          final certificate = profile.effectiveCertificationHistory.where((c) => c.id == destination.id).firstOrNull;
          if (certificate == null) throw StateError('Unavailable certificate');
          if (!context.mounted) return;
          select?.call(admin ? 5 : 4);
          _details(context, user, certificate.name, {'Certificate ID': certificate.id,
            'Issuer': certificate.provider, 'Certificate number': certificate.certificationId,
            'Status': certificate.status.name, 'Issued': certificate.issueDate, 'Expires': certificate.expirationDate,
            if (certificate.verificationNotes.isNotEmpty) 'Review notes': certificate.verificationNotes,
            if (certificate.rejectionReason.isNotEmpty) 'Rejection reason': certificate.rejectionReason},
            select: select, tab: admin ? 5 : 4, action: admin ? 'Open certificates' : 'Open profile');
        case NotificationDestinationKind.verification:
          if (!admin) {
            if (destination.id != null && destination.id != user.userId) throw StateError('Unavailable record');
            if (select != null) { select(4); return; }
            _details(context, user, note.title, {'Message': note.message});
            return;
          }
          select?.call(4);
          if (destination.id == null) return;
          final collection = note.sourceCollection == 'serviceProviders' ? 'serviceProviders' : 'users';
          final record = await records.read(collection, destination.id!);
          if (!context.mounted) return;
          _details(context, user, 'Verification details', {'User ID': destination.id!, 'Status': record['verificationStatus']?.toString() ?? 'Pending',
            'Identity check': record['diditStatus']?.toString() ?? 'Not started',
            'Verified': record['isVerified'] == true ? 'Yes' : 'No'}, select: select, tab: 4, action: 'Open verification');
        case NotificationDestinationKind.report:
          await records.report(destination.id!, user);
          if (!context.mounted) return;
          if (admin) select?.call(3);
          _push(context, user, Scaffold(appBar: AppBar(title: const Text('Report details')), body: SingleChildScrollView(
            padding: const EdgeInsets.all(20), child: DisputeCasePanel(appUser: user, reportId: destination.id!,
              onOpenConversation: (id) async {
                try { await records.conversation(id, user); if (context.mounted) _push(context, user, InquiryScreen(appUser: user, inquiryId: id)); }
                catch (_) { if (context.mounted) _unavailable(context); }
              }))));
        case NotificationDestinationKind.review:
          final review = await records.read('reviews', destination.id!);
          if (!admin && ![review['providerId'], review['customerId']].contains(user.userId)) throw StateError('Unavailable review');
          if (!context.mounted) return;
          _details(context, user, 'Review details', {'Rating': '${review['rating'] ?? '—'} / 5', 'Comment': review['comment']?.toString() ?? '',
            'Booking ID': review['bookingId']?.toString() ?? ''});
        case NotificationDestinationKind.user:
          if (!admin) throw StateError('Unavailable account');
          final record = await records.read('users', destination.id!);
          if (!context.mounted) return;
          select?.call(destination.tab!);
          _details(context, user, record['fullName']?.toString() ?? 'Account details', {'User ID': destination.id!,
            'Role': record['role']?.toString() ?? '', 'Account status': record['accountStatus']?.toString() ?? ''},
            select: select, tab: destination.tab, action: destination.tab == 2 ? 'Open providers' : 'Open customers');
      }
    } catch (_) {
      if (context.mounted) {
        if (destination.tab != null) select?.call(destination.tab!);
        _unavailable(context);
      }
    }
  }
  static void _unavailable(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This record is unavailable or you no longer have access.')));
  static void _push(BuildContext context, AppUser user, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => RoleThemeScope(palette: RoleTheme.forBadge(user.role.firestoreValue), child: page)));
  }
  static void _details(BuildContext context, AppUser user, String title, Map<String, String> fields, {ValueChanged<int>? select, int? tab, String? action}) {
    _push(context, user, Scaffold(appBar: AppBar(title: Text(title)), body: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final field in fields.entries) adminDetailLine(field.key, field.value.isEmpty ? '—' : field.value),
        if (select != null && tab != null && action != null) Align(alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () { Navigator.of(context).pop(); select(tab); }, child: Text(action))),
      ]))));
  }
}
