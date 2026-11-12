import 'package:file_picker/file_picker.dart';
import 'certificate_document.dart';

Future<CertificateDocument?> pickCertificateDocument() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null) return null;
  final file = result.files.single;
  if (file.bytes == null) {
    throw StateError(
      'Could not read the selected file. Please choose it again.',
    );
  }
  final document = CertificateDocument(name: file.name, bytes: file.bytes!);
  document.validate();
  return document;
}
