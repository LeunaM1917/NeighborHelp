import '../ui/workflow_ui.dart';
import '../l10n/app_strings.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import 'account_setup_gate.dart';
import '../services/firestore_service.dart';

Future<bool> reviewAndRespondToOffer(
  BuildContext context, {
  required Booking booking,
  required AppUser appUser,
  required String providerId,
  required bool accept,
}) async {
  if (accept && !await requireAccountSetup(context, appUser: appUser, role: UserRole.provider, action: 'accept a booking')) return false;
  if (!context.mounted) return false;
  final current = await FirestoreService().getBooking(booking.bookingId);
  if (current == null || !context.mounted) return false;
  if (current.isExpired) {
    throw StateError('This offer expired. Discuss and send a new offer.');
  }
  if (accept && current.agreement != null) {
    final agreed = await confirmServiceAgreement(
      context,
      agreement: current.agreement!,
      title: 'Accept service agreement',
      confirmation:
          'I am at least 18, legally able to contract, qualified for this work, and voluntarily accept these exact terms.',
    );
    if (agreed != true) return false;
  }
  await FirestoreService().providerRespondToBooking(
    bookingId: booking.bookingId,
    providerId: providerId,
    accept: accept,
    agreementHash: current.agreement?['hash'] as String?,
  );
  return true;
}

class OfferChangeButton extends StatelessWidget {
  const OfferChangeButton({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.edit_note),
    label: const Text('Request changes'),
    onPressed: () async {
      final reason = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => WorkflowDialog(
          title: const Text('Request changes to this offer'),
          content: TextField(
            controller: reason,
            maxLength: 3000,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Explain the scope, price or schedule changes needed. The customer must send a revised offer.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('Back')),
            ),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length >= 10) {
                  Navigator.pop(ctx, reason.text.trim());
                }
              },
              child: const Text('Request changes'),
            ),
          ],
        ),
      );
      reason.dispose();
      if (result == null) return;
      try {
        await FirestoreService().requestOfferChanges(booking.bookingId, result);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is StateError
                    ? e.message.toString()
                    : 'Could not request changes.',
              ),
            ),
          );
        }
      }
    },
  );
}

Future<bool?> confirmServiceAgreement(
  BuildContext context, {
  required Map<String, dynamic> agreement,
  required String title,
  required String confirmation,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    bool accepted = false;
    return StatefulBuilder(
      builder: (context, setState) => WorkflowDialog(
        title: Text(title),
        content: SizedBox(
          width: 640,
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(agreement['text'] as String),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (v) => setState(() => accepted = v ?? false),
                title: Text(context.tr(confirmation)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Back')),
          ),
          FilledButton(
            onPressed: accepted ? () => Navigator.pop(context, true) : null,
            child: Text(context.tr('Agree and continue')),
          ),
        ],
      ),
    );
  },
);

class ServiceAgreementCard extends StatelessWidget {
  const ServiceAgreementCard({super.key, required this.booking});
  final Booking booking;
  String _record() {
    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    String time(dynamic v) => v == null
        ? 'Not yet accepted'
        : '${format.format(v.toDate().toUtc().add(const Duration(hours: 8)))} Asia/Manila';
    return '${booking.agreement?['text']}\n\nACCEPTANCE RECORD\nCustomer accepted: ${time(booking.customerAcceptedAt)}\nCustomer fingerprint: ${booking.customerAcceptedHash ?? ""}\nProvider accepted: ${time(booking.providerAcceptedAt)}\nProvider fingerprint: ${booking.providerAcceptedHash ?? ""}\nSHA-256: ${booking.agreement?['hash']}\nCurrent job status: ${booking.status}\n${booking.changeRequest ?? ""}';
  }

  @override
  Widget build(BuildContext context) {
    if (booking.agreement == null) {
      return const WorkflowSurface(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Historical booking: its recorded price is preserved. Pending requests must be replaced with a fixed or daily contract offer before acceptance.',
          ),
        ),
      );
    }
    return WorkflowSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: WorkflowFields(
          children: [
            if (booking.isPending || booking.isExpired)
              Semantics(
                liveRegion: true,
                child: Text(
                  booking.isExpired
                      ? 'Offer expired. Discuss a new schedule and send a new offer to continue.'
                      : 'Respond by ${DateFormat('MMM d, yyyy h:mm a').format(booking.offerDeadline.toUtc().add(const Duration(hours: 8)))} Manila time. Unanswered offers expire after 72 hours or when work starts, whichever comes first.',
                ),
              ),
            Text(
              context.tr('Service agreement'),
              style: WorkflowStyles.sectionTitle,
            ),
            Text(
              booking.isExpired
                  ? 'Expired without provider acceptance'
                  : booking.providerAcceptedAt == null
                  ? 'Offered by customer · awaiting provider acceptance'
                  : 'Accepted by both parties',
            ),
            if (booking.changeRequest != null)
              Text('Requested changes: ${booking.changeRequest}'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Read terms and acceptance record'),
              children: [SelectableText(_record())],
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download agreement'),
              onPressed: () async {
                try {
                  await FilePicker.platform.saveFile(
                    dialogTitle: 'Save service agreement',
                    fileName: 'neighborhelp-agreement-${booking.bookingId}.txt',
                    bytes: Uint8List.fromList(utf8.encode(_record())),
                    type: FileType.custom,
                    allowedExtensions: ['txt'],
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not download. You can copy the agreement text above.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
