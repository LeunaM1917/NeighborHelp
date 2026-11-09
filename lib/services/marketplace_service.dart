import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/functions_config.dart';
import '../models/inquiry.dart';

class MarketplaceService {
  static Future<String> bookingInquiry(String bookingId) async {
    Map<String, dynamic> result;
    do {
      result = await command('inquiryCommand', {
        'action': 'bookingThread',
        'bookingId': bookingId,
      });
    } while (result['hasMore'] == true);
    return result['inquiryId'] as String;
  }

  static Future<void> syncBookingConversations() async {
    String cursor = '';
    bool more;
    do {
      final result = await command('inquiryCommand', {
        'action': 'syncBookings',
        'cursor': cursor,
      });
      more = result['hasMore'] == true;
      cursor = result['cursor'] as String? ?? '';
    } while (more);
  }

  static final _db = FirebaseFirestore.instance;
  static Future<Map<String, dynamic>> command(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StateError(
        e.message ?? 'Could not complete this action. Please retry.',
      );
    }
  }

  static Future<String> openInquiry(String serviceId) async =>
      (await command('inquiryCommand', {
            'action': 'open',
            'serviceId': serviceId,
          }))['inquiryId']
          as String;
  static Stream<Inquiry?> inquiry(String id) => _db
      .collection('inquiries')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Inquiry(s.id, s.data()!) : null);
  static Stream<List<Inquiry>> inbox(String uid) => _db
      .collection('inquiries')
      .where('participantIds', arrayContains: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map((d) => Inquiry(d.id, d.data())).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });
  static Stream<QuerySnapshot<Map<String, dynamic>>> messages(String id) => _db
      .collection('inquiries')
      .doc(id)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots();
  static Future<void> send(
    String id, {
    String text = '',
    String mediaUrl = '',
    String? messageId,
  }) async {
    await command('inquiryCommand', {
      'action': 'send',
      'inquiryId': id,
      'messageId': messageId ?? _db.collection('inquiries').doc().id,
      'text': text,
      'mediaUrl': mediaUrl,
    });
  }
}
