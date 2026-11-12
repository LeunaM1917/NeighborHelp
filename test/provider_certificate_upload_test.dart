import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/provider_certification.dart';
import 'package:neighbor_help/screens/provider/provider_certification_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_profile_editor_dialog.dart';
import 'package:neighbor_help/services/certificate_document.dart';
import 'package:neighbor_help/services/firestore_service.dart';
import 'package:neighbor_help/theme/app_theme.dart';
import 'support/ui_test_support.dart';

class CertificateStore extends Fake implements FirestoreService {
  Map<String, dynamic>? saved;
  @override
  Future<ServiceProviderProfile?> getProviderProfile(String id) async =>
      ServiceProviderProfile.fromFirestore(id, {'userId': id});
  @override
  Future<void> updateServiceProvider({
    required String providerId,
    required Map<String, dynamic> data,
  }) async => saved = data;
}

void main() {
  setUpOfflineFonts();
  testWidgets(
    'chooser cancellation unlocks retry; upload and saved record share one certificate ID',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = CertificateStore();
      final choice = Completer<CertificateDocument?>();
      var picks = 0;
      String? uploadedId;
      await tester.pumpWidget(
        MaterialApp(
          theme: neighborHelpTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ProviderProfileEditorDialog.open(
                  context,
                  title: 'Certification',
                  child: ProviderCertificationDialog(
                    providerId: 'provider',
                    showHeader: false,
                    firestore: store,
                    initial: const ProviderCertificationEntry(
                      name: 'Carpentry NC II',
                      certificationId: 'NC-123',
                      issueDate: '2025-01-01',
                      expirationDate: '2030-01-01',
                    ),
                    pickDocument: () {
                      picks++;
                      return picks == 1
                          ? choice.future
                          : Future.value(
                              CertificateDocument(
                                name: 'certificate.PDF',
                                bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
                              ),
                            );
                    },
                    uploadDocument: (id, document) async {
                      uploadedId = id;
                      return 'gs://test/certificates/provider/$id/proof.pdf';
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final uploadLabel = find.text('Upload PDF or image (up to 5 MB)');
      final upload = find
          .ancestor(
            of: uploadLabel,
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .first;
      await tester.ensureVisible(upload);
      await tester.tap(upload);
      await tester.pump();
      expect(picks, 1);
      expect(tester.widget<OutlinedButton>(upload).onPressed, isNull);
      choice.complete(null);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(upload).onPressed, isNotNull);
      await tester.tap(upload);
      await tester.pumpAndSettle();
      expect(picks, 2);
      expect(uploadedId, isNotEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final cert = (store.saved!['certificationHistory'] as List).single as Map;
      expect(cert['id'], uploadedId);
      expect(cert['url'], contains('/$uploadedId/'));
      expect(cert['status'], 'Pending');
      expect(store.saved!['approvedCertificationIds'], isEmpty);
      expect(find.byKey(ProviderProfileEditorDialog.closeKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'certificate validation rejects empty, large and unsupported documents',
    () {
      for (final document in [
        CertificateDocument(name: 'empty.pdf', bytes: Uint8List(0)),
        CertificateDocument(
          name: 'big.pdf',
          bytes: Uint8List(5 * 1024 * 1024 + 1),
        ),
        CertificateDocument(name: 'notes.txt', bytes: Uint8List(4)),
      ]) {
        expect(document.validate, throwsStateError);
      }
    },
  );
}
