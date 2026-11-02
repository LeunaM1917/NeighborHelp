import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/firestore_service.dart';

class BookingRescheduleCard extends StatefulWidget {
  const BookingRescheduleCard({
    super.key,
    required this.booking,
    required this.asCustomer,
  });
  final Booking booking;
  final bool asCustomer;
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
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    await _run(
      () =>
          FirestoreService().requestReschedule(widget.booking.bookingId, when),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    if (!b.isPending && !b.isAccepted) return const SizedBox.shrink();
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
                    ? 'A new schedule takes effect after the provider accepts it.'
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
                              () => FirestoreService().respondToReschedule(
                                b.bookingId,
                                approve: true,
                              ),
                            ),
                      child: const Text('Accept new date'),
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
