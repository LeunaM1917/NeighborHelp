import 'package:flutter_test/flutter_test.dart';
import 'support/certificate_picker_browser_stub.dart'
    if (dart.library.js_interop) 'support/certificate_picker_browser_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerCertificatePickerBrowserTests();
}
