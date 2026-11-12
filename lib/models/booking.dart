import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Booking {
  Booking({
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.serviceLocation,
    required this.location,
    required this.scheduledDate,
    this.scheduledEndDate,
    required String status,
    this.offerExpiresAt,
    this.expiredAt,
    this.totalFee,
    this.pricingType,
    this.hourlyRate,
    this.durationHours,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.contractId,
    this.milestoneNumber,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledByRole,
    this.rescheduleDate,
    this.inquiryId,
    this.dailyRate,
    this.numberOfDays,
    this.hoursPerDay,
    this.agreement,
    this.customerAcceptedAt,
    this.providerAcceptedAt,
    this.customerAcceptedHash,
    this.providerAcceptedHash,
    this.changeRequest,
    this.completionReportedAt,
    this.completionResponseDueAt,
    this.correctionRequest,
    this.correctionRequestedAt,
    this.requestVersion = 1,
    this.pendingAmendmentId,
    this.confirmedTerms,
    this.termsStatus,
    this.preferredScheduledDate,
    this.finalFee,
  }) : _status = status;

  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceId;
  final String serviceLocation;
  final GeoPoint location;
  final Timestamp scheduledDate;

  /// Inclusive end of the requested service window (start + [durationHours] when set).
  final Timestamp? scheduledEndDate;
  final String _status;
  final Timestamp? offerExpiresAt;
  final Timestamp? expiredAt;
  DateTime get offerDeadline => offerExpiresAt?.toDate() ?? scheduledStart;
  bool get isExpired =>
      _status.toLowerCase() == 'expired' ||
      _status.toLowerCase() == 'pending' &&
          !DateTime.now().isBefore(offerDeadline);
  String get status => isExpired ? 'Expired' : _status;
  final double? totalFee;

  /// Direct bookings use `hourly` or `fixed`; historical contracts may be daily.
  final String? pricingType;
  final double? hourlyRate;
  final double? durationHours;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? acceptedAt;

  /// When the provider tapped "Start the job" (actual on-site start).
  final Timestamp? startedAt;
  final Timestamp? completedAt;

  /// Active [ServiceContract] this booking belongs to (set when provider accepts).
  final String? contractId;

  /// Milestone index on the contract (1, 2, 3…).
  final int? milestoneNumber;
  final String? cancellationReason;
  final Timestamp? cancelledAt;

  /// `customer` or `provider`
  final String? cancelledByRole;
  final DateTime? rescheduleDate;
  final String? inquiryId;
  final double? dailyRate;
  final int? numberOfDays;
  final double? hoursPerDay;
  final Map<String, dynamic>? agreement;
  final Timestamp? customerAcceptedAt;
  final Timestamp? providerAcceptedAt;
  final String? customerAcceptedHash;
  final String? providerAcceptedHash;
  final String? changeRequest;
  final Timestamp? completionReportedAt;
  final Timestamp? completionResponseDueAt;
  final String? correctionRequest;
  final Timestamp? correctionRequestedAt;
  final int requestVersion;
  final String? pendingAmendmentId, termsStatus;
  final Map<String, dynamic>? confirmedTerms;
  final Timestamp? preferredScheduledDate;
  final double? finalFee;
  bool get requiresProviderEstimate =>
      requestVersion == 2 && confirmedTerms == null;
  bool get hasConfirmedSchedule =>
      isAccepted || isInProgress || isAwaitingConfirmation || isCompleted;
  String get statusLabel =>
      requestVersion == 2 &&
          termsStatus == 'Awaiting customer approval' &&
          !hasConfirmedSchedule
      ? 'Awaiting customer approval'
      : requiresProviderEstimate && isPending
      ? 'Awaiting provider estimate'
      : status;

  factory Booking.fromFirestore(String id, Map<String, dynamic> data) {
    return Booking(
      bookingId: id,
      customerId: data['customerId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      serviceLocation: data['serviceLocation'] as String? ?? '',
      location: data['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      scheduledDate: data['scheduledDate'] as Timestamp? ?? Timestamp.now(),
      scheduledEndDate: data['scheduledEndDate'] as Timestamp?,
      status: data['status'] as String? ?? 'Pending',
      offerExpiresAt: data['offerExpiresAt'] as Timestamp?,
      expiredAt: data['expiredAt'] as Timestamp?,
      totalFee: (data['totalFee'] as num?)?.toDouble(),
      pricingType: data['pricingType'] as String?,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      durationHours: (data['durationHours'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      acceptedAt: data['acceptedAt'] as Timestamp?,
      startedAt: data['startedAt'] as Timestamp?,
      completedAt: data['completedAt'] as Timestamp?,
      contractId: data['contractId'] as String?,
      milestoneNumber: (data['milestoneNumber'] as num?)?.toInt(),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledAt: data['cancelledAt'] as Timestamp?,
      cancelledByRole: data['cancelledByRole'] as String?,
      rescheduleDate:
          ((data['rescheduleRequest'] as Map?)?['scheduledDate'] as Timestamp?)
              ?.toDate(),
      inquiryId: data['inquiryId'] as String?,
      dailyRate: (data['proposedRate'] as num?)?.toDouble(),
      numberOfDays: (data['numberOfDays'] as num?)?.toInt(),
      hoursPerDay: (data['hoursPerDay'] as num?)?.toDouble(),
      agreement: data['agreement'] is Map
          ? Map<String, dynamic>.from(data['agreement'] as Map)
          : null,
      customerAcceptedAt: data['customerAcceptedAt'] as Timestamp?,
      providerAcceptedAt: data['providerAcceptedAt'] as Timestamp?,
      customerAcceptedHash: data['customerAcceptedHash'] as String?,
      providerAcceptedHash: data['providerAcceptedHash'] as String?,
      changeRequest: data['changeRequest'] as String?,
      completionReportedAt: data['completionReportedAt'] as Timestamp?,
      completionResponseDueAt: data['completionResponseDueAt'] as Timestamp?,
      correctionRequest: data['correctionRequest'] as String?,
      correctionRequestedAt: data['correctionRequestedAt'] as Timestamp?,
      requestVersion: (data['requestVersion'] as num?)?.toInt() ?? 1,
      pendingAmendmentId: data['pendingAmendmentId'] as String?,
      confirmedTerms: data['confirmedTerms'] is Map
          ? Map<String, dynamic>.from(data['confirmedTerms'] as Map)
          : null,
      termsStatus: data['termsStatus'] as String?,
      preferredScheduledDate: data['preferredScheduledDate'] as Timestamp?,
      finalFee: (data['finalFee'] as num?)?.toDouble(),
    );
  }

  String get statusNormalized => status.toLowerCase();

  bool get isPending => statusNormalized == 'pending';
  bool get isAccepted => statusNormalized == 'accepted';
  bool get isInProgress => statusNormalized == 'in progress';
  bool get isAwaitingConfirmation =>
      statusNormalized == 'awaiting confirmation';
  bool get isCancelled =>
      statusNormalized == 'cancelled' || statusNormalized == 'canceled';
  bool get wasCancelledByProvider =>
      cancelledByRole?.toLowerCase() == 'provider';
  bool get wasCancelledByCustomer =>
      cancelledByRole?.toLowerCase() == 'customer';
  bool get canProviderCancel => (isAccepted || isInProgress) && !isCancelled;
  bool get canCustomerCancel =>
      canProviderCancel || isPending || statusNormalized == 'changes requested';
  bool get isMilestoneComplete =>
      statusNormalized == 'milestone complete' ||
      statusNormalized == 'completed';
  bool get isCompleted => isMilestoneComplete;

  String get milestoneLabel =>
      milestoneNumber != null ? 'Milestone $milestoneNumber' : 'Booking';

  /// Billable / on-site duration from [startedAt], using [durationHours] or scheduled window.
  double get effectiveDurationHours {
    if (durationHours != null && durationHours! > 0) return durationHours!;
    final end = scheduledEnd;
    if (end != null) {
      final hrs = end.difference(scheduledStart).inMinutes / 60.0;
      if (hrs > 0) return hrs;
    }
    return 1;
  }

  DateTime? get workEndsAt {
    if (agreement != null && startedAt != null) return scheduledEnd;
    final start = startedAt?.toDate();
    if (start == null) return null;
    return start.add(
      Duration(milliseconds: (effectiveDurationHours * 3600000).round()),
    );
  }

  /// Provider may complete only after the work window from actual start has elapsed.
  bool get canCompleteMilestone {
    if (!isInProgress || startedAt == null) return false;
    if (pricingType == 'fixed') return true;
    final end = workEndsAt;
    if (end == null) return false;
    return !DateTime.now().isBefore(end);
  }

  /// Alias kept for existing provider job UI.
  bool get canMarkCompleted => canCompleteMilestone;

  bool get canStartJob => isAccepted && startedAt == null;

  DateTime get scheduledStart => scheduledDate.toDate();

  DateTime? get scheduledEnd {
    if (scheduledEndDate != null) return scheduledEndDate!.toDate();
    if (durationHours != null && durationHours! > 0) {
      return scheduledStart.add(
        Duration(milliseconds: (durationHours! * 3600000).round()),
      );
    }
    return null;
  }

  static String _durationHoursLabel(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()} hr${hours == 1 ? '' : 's'}';
    }
    return '${hours.toStringAsFixed(2)} hrs';
  }

  /// Date and start–end time for booking lists and detail screens.
  String get scheduledWindowLabel {
    final start = scheduledStart.toUtc().add(const Duration(hours: 8));
    final end = scheduledEnd?.toUtc().add(const Duration(hours: 8));
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    if (requiresProviderEstimate) {
      return 'Preferred: ${dateFmt.format(start)} · ${timeFmt.format(start)} (Manila)';
    }
    if (end == null) {
      return DateFormat('MMM d, yyyy • h:mm a').format(start);
    }
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return '${dateFmt.format(start)} • ${timeFmt.format(start)} – ${timeFmt.format(end)}';
    }
    return '${dateFmt.format(start)} ${timeFmt.format(start)} – ${dateFmt.format(end)} ${timeFmt.format(end)}';
  }

  /// Human-readable pricing line for booking detail screens.
  String? get pricingSummary {
    if (pricingType == 'daily' && dailyRate != null && numberOfDays != null) {
      return '₱${dailyRate!.toStringAsFixed(2)}/day × $numberOfDays day(s)';
    }
    if (pricingType == 'hourly' &&
        hourlyRate != null &&
        durationHours != null) {
      return '₱${hourlyRate!.toStringAsFixed(2)}/hr × ${_durationHoursLabel(durationHours!)}';
    }
    if (pricingType == 'fixed') {
      if (durationHours != null) {
        return 'Fixed rate • ${_durationHoursLabel(durationHours!)} window';
      }
      return 'Fixed rate';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'serviceLocation': serviceLocation,
      'location': location,
      'scheduledDate': scheduledDate,
      if (scheduledEndDate != null) 'scheduledEndDate': scheduledEndDate,
      'status': _status,
      'requestVersion': requestVersion,
      if (pendingAmendmentId != null) 'pendingAmendmentId': pendingAmendmentId,
      if (confirmedTerms != null) 'confirmedTerms': confirmedTerms,
      if (termsStatus != null) 'termsStatus': termsStatus,
      if (preferredScheduledDate != null)
        'preferredScheduledDate': preferredScheduledDate,
      if (finalFee != null) 'finalFee': finalFee,
      if (offerExpiresAt != null) 'offerExpiresAt': offerExpiresAt,
      if (expiredAt != null) 'expiredAt': expiredAt,
      'totalFee': totalFee,
      if (pricingType != null) 'pricingType': pricingType,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (durationHours != null) 'durationHours': durationHours,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (acceptedAt != null) 'acceptedAt': acceptedAt,
      if (startedAt != null) 'startedAt': startedAt,
      if (completedAt != null) 'completedAt': completedAt,
      if (contractId != null) 'contractId': contractId,
      if (milestoneNumber != null) 'milestoneNumber': milestoneNumber,
      if (inquiryId != null) 'inquiryId': inquiryId,
      if (dailyRate != null) 'proposedRate': dailyRate,
      if (numberOfDays != null) 'numberOfDays': numberOfDays,
      if (hoursPerDay != null) 'hoursPerDay': hoursPerDay,
      if (agreement != null) 'agreement': agreement,
      if (customerAcceptedAt != null) 'customerAcceptedAt': customerAcceptedAt,
      if (providerAcceptedAt != null) 'providerAcceptedAt': providerAcceptedAt,
      if (customerAcceptedHash != null)
        'customerAcceptedHash': customerAcceptedHash,
      if (providerAcceptedHash != null)
        'providerAcceptedHash': providerAcceptedHash,
      if (changeRequest != null) 'changeRequest': changeRequest,
    };
  }
}
