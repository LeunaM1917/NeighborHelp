import 'package:cloud_firestore/cloud_firestore.dart';

class Inquiry {
  Inquiry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
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
  DateTime get updatedAt =>
      (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
}
