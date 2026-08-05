import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import 'admin_activity_widgets.dart';
import 'admin_bookings_widgets.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_notifications_widgets.dart';
import 'admin_providers_widgets.dart';
import 'admin_reports_widgets.dart';
import 'admin_services_widgets.dart';

void showAdminServiceDetail(
  BuildContext context, {
  required AdminServiceTableRow row,
  required void Function(String action) onAction,
}) {
  final s = row.service;
  final dateFmt = DateFormat('MMM d, yyyy');
  final timeFmt = DateFormat('h:mm a');

  final detailActions = <AdminDetailAction>[
    AdminDetailAction(label: 'View provider profile', onPressed: () => onAction('provider')),
    if (s.approvalStatus == ServiceApprovalStatus.pending) ...[
      AdminDetailAction(label: 'Approve listing', filled: true, onPressed: () => onAction('approve')),
      AdminDetailAction(label: 'Reject listing', destructive: true, onPressed: () => onAction('reject')),
    ],
    if (s.approvalStatus == ServiceApprovalStatus.approved)
      AdminDetailAction(
        label: s.isActive ? 'Hide from marketplace' : 'Show on marketplace',
        onPressed: () => onAction(s.isActive ? 'hide' : 'show'),
      ),
  ];

  showAdminRecordDetailDialog(
    context,
    title: s.serviceTitle,
    subtitle: s.category.isEmpty ? null : s.category,
    body: [
      adminDetailLine('Provider', row.providerLabel),
      if (row.providerArea.isNotEmpty) adminDetailLine('Area', row.providerArea),
      adminDetailLine('Price', '₱${s.estimatedPrice.toStringAsFixed(0)} (${s.priceType})'),
      adminDetailLine('Duration', s.estimatedDuration.isEmpty ? '—' : s.estimatedDuration),
      adminDetailLine('Status', _serviceStatusLabel(s)),
      adminDetailLine('Service ID', s.serviceId),
      adminDetailLine('Provider ID', s.providerId),
      if (s.description.trim().isNotEmpty) adminDetailLine('Description', s.description.trim()),
      if (s.rejectionReason.trim().isNotEmpty) adminDetailLine('Rejection reason', s.rejectionReason.trim()),
      adminDetailLine('Created', '${dateFmt.format(s.createdAt.toDate())} ${timeFmt.format(s.createdAt.toDate())}'),
      adminDetailLine('Updated', '${dateFmt.format(s.updatedAt.toDate())} ${timeFmt.format(s.updatedAt.toDate())}'),
      adminDetailLine('Marketplace', s.isMarketplaceVisible ? 'Visible' : 'Hidden'),
      adminDetailLine('Images', '${s.serviceImages.length} photo(s)'),
    ],
    actions: detailActions,
  );
}

String _serviceStatusLabel(ServiceListing s) {
  switch (s.approvalStatus) {
    case ServiceApprovalStatus.pending:
      return 'Pending review';
    case ServiceApprovalStatus.rejected:
      return 'Rejected';
    case ServiceApprovalStatus.draft:
      return 'Draft';
    case ServiceApprovalStatus.approved:
      return s.isActive ? 'Live on marketplace' : 'Approved but paused';
  }
}

void showAdminCustomerDetail(
  BuildContext context, {
  required AppUser user,
  required int bookingCount,
  required void Function(String action) onAction,
}) {
  final dateFmt = DateFormat('MMM d, yyyy');
  final lastActive = user.lastActive ?? user.updatedAt;

  showAdminRecordDetailDialog(
    context,
    title: user.fullName.isNotEmpty ? user.fullName : user.email,
    subtitle: user.email,
    body: [
      adminDetailLine('User ID', user.userId),
      adminDetailLine('Email', user.email),
      adminDetailLine('Account status', user.accountStatus.firestoreValue),
      adminDetailLine('Bookings', '$bookingCount'),
      adminDetailLine('Joined', dateFmt.format(user.createdAt.toDate())),
      adminDetailLine('Last activity', dateFmt.format(lastActive.toDate())),
      if (user.address?.trim().isNotEmpty == true) adminDetailLine('Address', user.address!.trim()),
    ],
    actions: [
      AdminDetailAction(label: 'View bookings', onPressed: () => onAction('bookings')),
      AdminDetailAction(label: 'Send notification', onPressed: () => onAction('notify')),
      if (user.accountStatus.firestoreValue != 'active')
        AdminDetailAction(label: 'Set active', filled: true, onPressed: () => onAction('active')),
      if (user.accountStatus.firestoreValue != 'suspended')
        AdminDetailAction(label: 'Suspend account', onPressed: () => onAction('suspend')),
      AdminDetailAction(label: 'Deactivate account', destructive: true, onPressed: () => onAction('deactivate')),
    ],
  );
}

void showAdminProviderDetail(
  BuildContext context, {
  required AdminProviderTableRow row,
  required void Function(String action) onAction,
}) {
  final p = row.profile;
  final user = row.user;
  final dateFmt = DateFormat('MMM d, yyyy');
  final name = (user?.fullName ?? '').trim().isNotEmpty ? user!.fullName : 'Provider';

  showAdminRecordDetailDialog(
    context,
    title: name,
    subtitle: p.serviceArea.isEmpty ? null : p.serviceArea,
    body: [
      if (user != null) adminDetailLine('Email', user.email),
      adminDetailLine('Provider ID', p.providerId),
      if (user != null) adminDetailLine('User ID', user.userId),
      adminDetailLine('Verification', p.verificationStatus),
      adminDetailLine('Verified badge', p.isVerified ? 'Yes' : 'No'),
      adminDetailLine('Rating', p.averageRating.toStringAsFixed(1)),
      adminDetailLine('Completed bookings', '${p.completedBookings}'),
      adminDetailLine('Listed services', '${row.serviceCount}'),
      if (row.topServiceLabel.isNotEmpty) adminDetailLine('Top service', row.topServiceLabel),
      adminDetailLine('Joined', dateFmt.format(p.createdAt.toDate())),
      if (user != null) adminDetailLine('Account', user.accountStatus.firestoreValue),
    ],
    actions: [
      AdminDetailAction(label: 'Review verification', onPressed: () => onAction('verify')),
      AdminDetailAction(label: 'View services', onPressed: () => onAction('services')),
      AdminDetailAction(label: 'Send notification', onPressed: () => onAction('notify')),
      if (user != null && user.accountStatus.firestoreValue != 'active')
        AdminDetailAction(label: 'Set active', filled: true, onPressed: () => onAction('active')),
      if (user != null && user.accountStatus.firestoreValue != 'suspended')
        AdminDetailAction(label: 'Suspend account', onPressed: () => onAction('suspend')),
      if (user != null)
        AdminDetailAction(label: 'Deactivate account', destructive: true, onPressed: () => onAction('deactivate')),
    ],
  );
}

void showAdminBookingDetail(
  BuildContext context, {
  required AdminBookingTableRow row,
  required void Function(String action) onAction,
}) {
  final b = row.booking;
  final dateFmt = DateFormat('MMM d, yyyy');
  final timeFmt = DateFormat('h:mm a');

  showAdminRecordDetailDialog(
    context,
    title: 'Booking ${row.shortBookingId}',
    subtitle: b.status,
    body: [
      adminDetailLine('Booking ID', b.bookingId),
      adminDetailLine('Customer', row.customerLabel),
      adminDetailLine('Provider', row.providerLabel),
      adminDetailLine('Service ID', b.serviceId),
      adminDetailLine('Status', b.status),
      adminDetailLine('Scheduled', '${dateFmt.format(b.scheduledDate.toDate())} ${timeFmt.format(b.scheduledDate.toDate())}'),
      adminDetailLine('Updated', '${dateFmt.format(b.updatedAt.toDate())} ${timeFmt.format(b.updatedAt.toDate())}'),
      if (b.serviceLocation.isNotEmpty) adminDetailLine('Location', b.serviceLocation),
      if (b.notes != null && b.notes!.isNotEmpty) adminDetailLine('Notes', b.notes!),
      if (b.cancellationReason != null && b.cancellationReason!.isNotEmpty)
        adminDetailLine('Cancellation', b.cancellationReason!),
    ],
    actions: [
      AdminDetailAction(label: 'Update status', filled: true, onPressed: () => onAction('status')),
      AdminDetailAction(label: 'View customer', onPressed: () => onAction('customer')),
      AdminDetailAction(label: 'View provider', onPressed: () => onAction('provider')),
      AdminDetailAction(label: 'Copy booking ID', onPressed: () => onAction('copy')),
    ],
  );
}

void showAdminOverviewBookingDetail(
  BuildContext context, {
  required Booking booking,
  required Map<String, AppUser> usersById,
  required Map<String, ServiceListing> servicesById,
  VoidCallback? onViewAllBookings,
}) {
  final dateFmt = DateFormat('MMM d, yyyy • h:mm a');
  final customer = usersById[booking.customerId];
  final provider = usersById[booking.providerId];
  final service = servicesById[booking.serviceId];

  showAdminRecordDetailDialog(
    context,
    title: 'Booking ${adminBookingDisplayId(booking.bookingId)}',
    subtitle: booking.status,
    body: [
      adminDetailLine('Booking ID', booking.bookingId),
      adminDetailLine('Customer', customer?.fullName.isNotEmpty == true ? customer!.fullName : booking.customerId),
      adminDetailLine('Provider', provider?.fullName.isNotEmpty == true ? provider!.fullName : booking.providerId),
      adminDetailLine('Service', service?.serviceTitle ?? booking.serviceId),
      adminDetailLine('Status', booking.status),
      adminDetailLine('Scheduled', dateFmt.format(booking.scheduledDate.toDate())),
      if (booking.serviceLocation.isNotEmpty) adminDetailLine('Location', booking.serviceLocation),
    ],
    actions: [
      if (onViewAllBookings != null)
        AdminDetailAction(label: 'Open bookings tab', filled: true, onPressed: onViewAllBookings),
    ],
  );
}

void showAdminActivityDetail(
  BuildContext context, {
  required AdminActivityEntry entry,
  required void Function(String action) onAction,
}) {
  final dateFmt = DateFormat('MMM d, yyyy');
  final timeFmt = DateFormat('h:mm a');

  showAdminRecordDetailDialog(
    context,
    title: entry.eventTitle,
    subtitle: entry.status,
    body: [
      adminDetailLine('Actor', entry.actorId),
      adminDetailLine('Type', entry.type.name),
      adminDetailLine('Time', '${dateFmt.format(entry.time)} ${timeFmt.format(entry.time)}'),
      if (entry.referenceId != null) adminDetailLine('Reference', entry.referenceId!),
      if (entry.booking != null) adminDetailLine('Booking status', entry.booking!.status),
      if (entry.service != null) adminDetailLine('Service', entry.service!.serviceTitle),
      if (entry.provider != null) adminDetailLine('Verification', entry.provider!.verificationStatus),
    ],
    actions: [
      AdminDetailAction(label: 'Copy actor ID', onPressed: () => onAction('copy')),
    ],
  );
}

void showAdminCategoryReportDetail(BuildContext context, {required CategoryReportRow row}) {
  showAdminRecordDetailDialog(
    context,
    title: row.category,
    subtitle: 'Category performance',
    body: [
      adminDetailLine('Total bookings', '${row.total}'),
      adminDetailLine('Completed', '${row.completed}'),
      adminDetailLine('Completion rate', '${(row.completionRate * 100).toStringAsFixed(0)}%'),
      adminDetailLine('Average rating', row.avgRating > 0 ? row.avgRating.toStringAsFixed(1) : '—'),
    ],
  );
}

void showAdminNotificationDetail(
  BuildContext context, {
  required NotificationHistoryRow row,
}) {
  final dateFmt = DateFormat('MMM d, yyyy');
  final timeFmt = DateFormat('h:mm a');

  showAdminRecordDetailDialog(
    context,
    title: row.title,
    subtitle: row.audience,
    body: [
      adminDetailLine('Message', row.message),
      adminDetailLine('Type', row.type),
      adminDetailLine('Recipients', '${row.count}'),
      adminDetailLine('Status', row.status),
      adminDetailLine('Sent', '${dateFmt.format(row.sentAt)} ${timeFmt.format(row.sentAt)}'),
      adminDetailLine('Channels', 'In-app, email, push'),
    ],
  );
}
