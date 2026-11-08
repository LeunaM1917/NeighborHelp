import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'admin_certificate_review_page.dart';

class AdminCertificatesPage extends StatelessWidget {
  const AdminCertificatesPage({super.key, required this.auth});
  final AuthService auth;
  @override
  Widget build(BuildContext context) => const AdminCertificateReviewPage();
}
