import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/firestore_service.dart';
import '../services/booking_availability.dart';
import '../screens/shared/agreement_amendment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRescheduleCard extends StatefulWidget {
  const BookingRescheduleCard({
    super.key,
    required this.booking,
    required this.asCustomer,
    this.loadAvailability,
  });
  final Booking booking;
  final bool asCustomer;
  final Future<BookingAvailability> Function()? loadAvailability;
  @override
  State<BookingRescheduleCard> createState() => _BookingRescheduleCardState();
}

class _BookingRescheduleCardState extends State<BookingRescheduleCard> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not update the schedule. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    await _run(() async {
      final availability =
          await (widget.loadAvailability?.call() ??
              BookingAvailability.load(
                providerId: widget.booking.providerId,
                serviceId: widget.booking.serviceId,
                excludeBookingId: widget.booking.bookingId,
              ));
      if (!mounted) return;
      final day = await chooseAvailableDay(context, availability);
      if (day == null || !mounted) return;
      final start = await chooseAvailableStart(context, availability, day);
      if (start != null) {
        await FirestoreService().requestReschedule(
          widget.booking.bookingId,
          start,
        );
      }
    });
  }

  Future<void> _proposeEstimate() async {
    final b = widget.booking;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgreementAmendmentScreen(
          bookingId: b.bookingId,
          bookingData: {
            ...b.toMap(),
            if (b.rescheduleDate != null)
              'scheduledDate': Timestamp.fromDate(b.rescheduleDate!),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    if (!b.isPending && !b.isAccepted) return const SizedBox.shrink();
    if (b.agreement != null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'To change the agreed schedule, scope or price, discuss it in the inquiry, cancel the existing offer with a reason, and send a new offer for both parties to accept. Accepted terms are retained.',
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule changes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                b.rescheduleDate == null
                    ? b.requestVersion == 2
                          ? 'Ask for a preferred start. The provider sends revised terms for customer approval before the confirmed schedule changes.'
                          : 'A new schedule takes effect after the provider accepts it.'
                    : 'Requested: ${MaterialLocalizations.of(context).formatMediumDate(b.rescheduleDate!)} ${TimeOfDay.fromDateTime(b.rescheduleDate!).format(context)}. The original schedule remains in place until accepted.',
              ),
              const SizedBox(height: 8),
              if (widget.asCustomer)
                OutlinedButton(
                  onPressed: _busy ? null : _request,
                  child: Text(
                    b.rescheduleDate == null
                        ? 'Request a new date'
                        : 'Change requested date',
                  ),
                ),
              if (!widget.asCustomer && b.rescheduleDate != null)
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => b.requestVersion == 2
                                  ? _proposeEstimate()
                                  : FirestoreService().respondToReschedule(
                                      b.bookingId,
                                      approve: true,
                                    ),
                            ),
                      child: Text(
                        b.requestVersion == 2
                            ? 'Set revised estimate'
                            : 'Accept new date',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => FirestoreService().respondToReschedule(
                                b.bookingId,
                                approve: false,
                              ),
                            ),
                      child: const Text('Keep original date'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
