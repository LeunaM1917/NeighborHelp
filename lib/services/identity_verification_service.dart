import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/functions_config.dart';
import 'firestore_service.dart';

/// Thrown when [IdentityVerificationService] cannot create a Didit session.
class VerificationStartException implements Exception {
  VerificationStartException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Cloud Functions region for NeighborHelp (`firebase deploy` default).
/// CORS-enabled HTTP function for Flutter web (callable URL blocks browser fetch).
const kCreateDiditSessionHttpFunction = 'createDiditSessionHttp';

/// Who is verifying: stored on `users` (customer) or `serviceProviders` (provider).
enum VerificationSubject {
  customer('customer'),
  provider('provider');

  const VerificationSubject(this.apiValue);
  final String apiValue;
}

/// Drives Didit hosted identity verification for customers and providers.
class IdentityVerificationService {
  IdentityVerificationService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion);

  final FirebaseFunctions _functions;

  Future<String> refreshDiditStatusForAdmin({
    required String userId,
    required VerificationSubject subject,
  }) async {
    final callable = _functions.httpsCallable(
      'refreshDiditStatus',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    try {
      final result = await callable.call<dynamic>({
        'userId': userId,
        'subject': subject.apiValue,
      });
      final map = result.data is Map ? Map<String, dynamic>.from(result.data as Map) : <String, dynamic>{};
      final status = (map['diditStatus'] as String?)?.trim() ?? '';
      if (status.isEmpty) {
        throw VerificationStartException('Refresh succeeded but no Didit status was returned.');
      }
      return status;
    } on FirebaseFunctionsException catch (e) {
      throw VerificationStartException(
        _friendlyFunctionsMessage(e),
        code: e.code,
      );
    }
  }

  Future<bool> startGovernmentIdVerification({
    required String documentType,
    required String documentLabel,
    String? callbackUrl,
    VerificationSubject subject = VerificationSubject.provider,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw VerificationStartException('Sign in required to verify your ID.');
    }

    if (subject == VerificationSubject.provider) {
      await FirestoreService().ensureServiceProviderProfile(uid);
    }
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final url = await _createSessionUrl(
      callbackUrl: callbackUrl,
      documentType: documentType,
      documentLabel: documentLabel,
      subject: subject,
    );
    final uri = Uri.parse(url);
    if (kIsWeb) {
      if (await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      )) {
        return true;
      }
      return launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<String> _createSessionUrl({
    String? callbackUrl,
    required String documentType,
    required String documentLabel,
    required VerificationSubject subject,
  }) async {
    final payload = <String, dynamic>{
      'documentType': documentType,
      'documentLabel': documentLabel,
      'subject': subject.apiValue,
      if (callbackUrl != null && callbackUrl.isNotEmpty) 'callback': callbackUrl,
    };

    if (kIsWeb) {
      return _createSessionUrlViaHttp(payload);
    }
    return _createSessionUrlViaSdk(payload);
  }

  Future<String> _createSessionUrlViaSdk(Map<String, dynamic> payload) async {
    final callable = _functions.httpsCallable(
      'createDiditSession',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    try {
      final result = await callable.call<dynamic>(payload);
      return _urlFromCallableData(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'createDiditSession SDK failed: code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      throw VerificationStartException(
        _friendlyFunctionsMessage(e),
        code: e.code,
      );
    }
  }

  /// POST to [createDiditSessionHttp] — supports browser CORS (callable URL does not).
  Future<String> _createSessionUrlViaHttp(Map<String, dynamic> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw VerificationStartException('Sign in required to verify your ID.', code: 'unauthenticated');
    }

    final projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      throw VerificationStartException('Firebase project is not configured.');
    }

    final idToken = await user.getIdToken(true);
    final uri = Uri.parse(
      'https://$kNeighborHelpFunctionsRegion-$projectId.cloudfunctions.net/$kCreateDiditSessionHttpFunction',
    );

    if (kDebugMode) {
      debugPrint('createDiditSessionHttp POST $uri');
    }

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on http.ClientException catch (e) {
      if (kDebugMode) debugPrint('createDiditSessionHttp network error: $e');
      throw VerificationStartException(
        'Network blocked the verification request. Allow cloudfunctions.net in your '
        'browser or ad blocker, then try again.',
        code: 'unavailable',
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      throw VerificationStartException(
        'Invalid response from verification server (HTTP ${response.statusCode}).',
        code: 'internal',
      );
    }

    if (response.statusCode == 200 && body['url'] is String) {
      return body['url'] as String;
    }

    final code = (body['code'] as String? ?? 'internal').toLowerCase();
    final error = body['error'] as String? ?? body['message'] as String?;
    if (kDebugMode) {
      debugPrint('createDiditSessionHttp error: code=$code error=$error');
    }
    throw VerificationStartException(
      _friendlyHttpError(code, error, null),
      code: code,
    );
  }

  String _urlFromCallableData(Object? data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final url = map['url'] as String?;
    if (url == null || url.isEmpty) {
      throw VerificationStartException('Verification session did not return a URL.');
    }
    return url;
  }

  String _friendlyHttpError(String status, String? message, Object? details) {
    final serverMsg = _nonEmptyMessage(message);
    final detailsMsg = _detailsMessage(details);
    switch (status) {
      case 'failed-precondition':
        return serverMsg ??
            detailsMsg ??
            'Verification is not set up on the server. Deploy functions with Didit keys in functions/.env.';
      case 'unauthenticated':
        return serverMsg ?? 'Please sign in again, then retry verification.';
      case 'invalid-argument':
        return serverMsg ?? 'Select a valid government ID type.';
      case 'unavailable':
        return serverMsg ?? 'Could not reach the verification service. Check your connection and try again.';
      case 'internal':
        return serverMsg ??
            detailsMsg ??
            'Could not create a verification session. Check Firebase logs for createDiditSession.';
      default:
        return serverMsg ?? detailsMsg ?? 'Could not start verification ($status).';
    }
  }

  String _friendlyFunctionsMessage(FirebaseFunctionsException e) {
    final serverMsg = _nonEmptyMessage(e.message);
    final detailsMsg = _detailsMessage(e.details);

    switch (e.code) {
      case 'failed-precondition':
        return serverMsg ??
            detailsMsg ??
            'Verification is not set up on the server. Deploy functions with Didit keys in functions/.env.';
      case 'unauthenticated':
        return serverMsg ?? 'Please sign in again, then retry verification.';
      case 'invalid-argument':
        return serverMsg ?? 'Select a valid government ID type.';
      case 'unavailable':
        return serverMsg ?? 'Could not reach the verification service. Check your connection and try again.';
      case 'internal':
        return serverMsg ??
            detailsMsg ??
            'Could not create a verification session. Check Firebase logs for createDiditSession.';
      default:
        return serverMsg ?? detailsMsg ?? 'Could not start verification (${e.code}).';
    }
  }

  String? _nonEmptyMessage(String? message) {
    final m = message?.trim();
    if (m == null || m.isEmpty || m == 'internal' || m == 'INTERNAL') return null;
    return m;
  }

  String? _detailsMessage(Object? details) {
    if (details == null) return null;
    if (details is String) {
      final m = details.trim();
      return m.isEmpty || m == 'internal' ? null : m;
    }
    if (details is Map) {
      final m = details['message'] ?? details['detail'];
      if (m is String) return _nonEmptyMessage(m);
    }
    return null;
  }
}
