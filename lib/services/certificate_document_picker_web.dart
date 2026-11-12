import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'certificate_document.dart';

/// Keep the input connected until the browser finishes choosing or cancelling.
/// Launch synchronously to retain the Upload button's browser user activation.
Future<CertificateDocument?> pickCertificateDocument() {
  final result = Completer<CertificateDocument?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png'
    ..id = 'neighborhelp-certificate-file-input';
  input.style.cssText =
      'position:fixed;left:-10000px;width:1px;height:1px;opacity:0;';
  var reading = false;
  var blurred = false;
  Timer? cancelTimer;
  final blur = ((web.Event _) {
    blurred = true;
  }).toJS;
  final focus = ((web.Event _) {
    if (!blurred || reading || result.isCompleted) return;
    cancelTimer?.cancel();
    cancelTimer = Timer(const Duration(milliseconds: 500), () {
      if (!reading && !result.isCompleted && (input.files?.length ?? 0) == 0) {
        result.complete(null);
      }
    });
  }).toJS;
  final change = ((web.Event _) {
    if (reading || result.isCompleted) return;
    reading = true;
    unawaited(() async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          result.complete(null);
          return;
        }
        if (file.size > 5 * 1024 * 1024) {
          throw StateError('Choose a file up to 5 MB.');
        }
        final buffer = (await file.arrayBuffer().toDart).toDart;
        final document = CertificateDocument(
          name: file.name,
          bytes: buffer.asUint8List(),
        );
        document.validate();
        result.complete(document);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }());
  }).toJS;
  final cancel = ((web.Event _) {
    if (!reading && !result.isCompleted) result.complete(null);
  }).toJS;
  void cleanup() {
    cancelTimer?.cancel();
    web.window.removeEventListener('blur', blur);
    web.window.removeEventListener('focus', focus);
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    input.remove();
  }

  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  web.window.addEventListener('blur', blur);
  web.window.addEventListener('focus', focus);
  web.document.body!.append(input);
  try {
    input.showPicker();
  } catch (_) {
    cleanup();
    throw StateError(
      'Your browser blocked the file chooser. Click Upload again to choose your certificate.',
    );
  }
  return result.future.whenComplete(cleanup);
}
