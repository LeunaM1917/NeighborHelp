import 'certificate_document.dart';
import 'certificate_document_picker_native.dart'
    if (dart.library.js_interop) 'certificate_document_picker_web.dart'
    as platform;

/// Called directly from the Upload click, before any asynchronous work.
Future<CertificateDocument?> pickCertificateDocument() =>
    platform.pickCertificateDocument();
