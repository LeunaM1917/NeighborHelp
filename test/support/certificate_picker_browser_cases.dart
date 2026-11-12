import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:neighbor_help/services/certificate_document_picker.dart';
import 'package:neighbor_help/services/certificate_document.dart';

@JS('HTMLInputElement.prototype')
external JSObject get _inputPrototype;

void registerCertificatePickerBrowserTests() {
  const selector = '#neighborhelp-certificate-file-input';
  late JSAny? originalShowPicker;
  setUp(
    () => originalShowPicker = _inputPrototype.getProperty<JSAny?>(
      'showPicker'.toJS,
    ),
  );
  tearDown(() {
    _inputPrototype.setProperty('showPicker'.toJS, originalShowPicker);
    web.window.delete('neighborHelpTestPickCertificate'.toJS);
    web.window.delete('neighborHelpTestCertificateResult'.toJS);
  });
  test(
    'web certificate picker stays attached until cancel and opens again',
    () async {
      var launches = 0;
      _inputPrototype.setProperty(
        'showPicker'.toJS,
        (() {
          launches++;
        }).toJS,
      );
      for (var i = 0; i < 2; i++) {
        final pending = pickCertificateDocument();
        final input =
            web.document.querySelector(selector)! as web.HTMLInputElement;
        expect(input.isConnected, isTrue);
        expect(input.accept, contains('.pdf'));
        input.dispatchEvent(web.Event('cancel'));
        expect(await pending, isNull);
        expect(web.document.querySelector(selector), isNull);
      }
      expect(launches, 2);
    },
  );
  test(
    'web certificate selection returns PDF bytes and removes its input',
    () async {
      _inputPrototype.setProperty('showPicker'.toJS, (() {}).toJS);
      final pending = pickCertificateDocument();
      final input =
          web.document.querySelector(selector)! as web.HTMLInputElement;
      final transfer = web.DataTransfer();
      final bytes = Uint8List.fromList('%PDF-1.7 fixture'.codeUnits);
      transfer.items.add(
        web.File(
          [bytes.toJS].toJS,
          'certificate.pdf',
          web.FilePropertyBag(type: 'application/pdf'),
        ),
      );
      input.files = transfer.files;
      input.dispatchEvent(web.Event('change'));
      final document = await pending;
      expect(document!.name, 'certificate.pdf');
      expect(document.bytes, bytes);
      expect(web.document.querySelector(selector), isNull);
    },
  );
  test('a browser-blocked chooser cleans up and can be retried', () {
    // No user activation exists in an ordinary asynchronous unit test.
    expect(pickCertificateDocument, throwsStateError);
    expect(web.document.querySelector(selector), isNull);
  });
  if (const bool.fromEnvironment('CERTIFICATE_CHOOSER_BROWSER_INTEGRATION')) {
    test(
      'trusted browser click opens the real chooser and reads the selected PDF',
      () async {
        final selected = Completer<CertificateDocument?>();
        web.window.setProperty(
          'neighborHelpTestPickCertificate'.toJS,
          (() {
            unawaited(
              pickCertificateDocument().then(
                selected.complete,
                onError: selected.completeError,
              ),
            );
          }).toJS,
        );
        final document = await selected.future.timeout(
          const Duration(seconds: 90),
        );
        expect(document?.name, 'certificate-fixture.pdf');
        expect(String.fromCharCodes(document!.bytes), startsWith('%PDF'));
        web.window.setProperty(
          'neighborHelpTestCertificateResult'.toJS,
          document.name.toJS,
        );
      },
      timeout: const Timeout(Duration(seconds: 100)),
    );
  }
}
