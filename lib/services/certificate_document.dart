import 'dart:typed_data';

class CertificateDocument {
  const CertificateDocument({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  String get extension => name.split('.').last.toLowerCase();

  void validate() {
    if (bytes.isEmpty) {
      throw StateError('The selected file is empty. Choose another file.');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('Choose a file up to 5 MB.');
    }
    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
      throw StateError('Use a PDF, JPG or PNG file up to 5 MB.');
    }
  }
}
