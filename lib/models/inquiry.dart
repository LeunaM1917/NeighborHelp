import 'package:cloud_firestore/cloud_firestore.dart';

class Inquiry {
  Inquiry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  bool get isDispute => data['kind'] == 'dispute';
  String get reportId => data['reportId'] as String? ?? '';
  bool get isClosedDispute =>
      isDispute && ['resolved', 'dismissed'].contains(data['caseStatus']);
  int unreadFor(String uid) => isDispute
      ? ((data['unreadCounts'] as Map?)?[uid] as num?)?.toInt() ?? 0
      : (data[uid == customerId ? 'customerUnreadCount' : 'providerUnreadCount']
                    as num?)
                ?.toInt() ??
            0;
  String get customerId => data['customerId'] as String;
  String get providerId => data['providerId'] as String;
  String get serviceId => data['serviceId'] as String;
  String get serviceTitle =>
      data['serviceTitle'] as String? ?? 'Service inquiry';
  String get customerName => data['customerName'] as String? ?? 'Customer';
  String get providerName => data['providerName'] as String? ?? 'Provider';
  String get lastMessage => data['lastMessage'] as String? ?? '';
  bool get hasDiscussion =>
      (data['customerMessageCount'] as num? ?? 0) > 0 &&
      (data['providerMessageCount'] as num? ?? 0) > 0;
  List<String> get blockedBy =>
      List<String>.from(data['blockedBy'] as List? ?? const []);
  bool get isBlocked => blockedBy.isNotEmpty;
  DateTime get updatedAt =>
      (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
}
