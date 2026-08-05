import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/provider_certification.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/loading_indicator.dart';
import '../widgets/admin_widgets.dart';

/// Read-only Admin view of certificates authenticated by Verification Agency.
class AdminCertificatesPage extends StatefulWidget {
  const AdminCertificatesPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AdminCertificatesPage> createState() => _AdminCertificatesPageState();
}

class _AdminCertificatesPageState extends State<AdminCertificatesPage> {
  final _searchController = TextEditingController();
  String _search = '';
  /// Default to Agency-approved so Admin can audit authenticated credentials.
  String _filter = 'Approved';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Certificates',
        subtitle: 'Connect a Firebase administrator account to view agency-authenticated credentials.',
        child: const AdminErrorBox(
          message: 'Sign in with a Firebase user whose Firestore role is Administrator.',
        ),
      );
    }

    final firestore = FirestoreService();

    return StreamBuilder<List<ServiceProviderProfile>>(
      stream: firestore.serviceProvidersStream(),
      builder: (context, providerSnap) {
        return StreamBuilder<List<AppUser>>(
          stream: firestore.allUsersStream(),
          builder: (context, userSnap) {
            if (!providerSnap.hasData || !userSnap.hasData) {
              return AdminPageFrame(
                auth: widget.auth,
                title: 'Certificates',
                subtitle: 'Credentials authenticated by the Verification Agency.',
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: LoadingIndicator(message: 'Loading certificates…'),
                ),
              );
            }

            final users = {for (final u in userSnap.data!) u.userId: u};
            final rows = <_AdminCertRow>[];
            for (final profile in providerSnap.data!) {
              final user = users[profile.userId];
              final name = user?.fullName.trim();
              final email = user?.email.trim() ?? '';
              for (final cert in profile.effectiveCertificationHistory) {
                rows.add(
                  _AdminCertRow(
                    profile: profile,
                    entry: cert,
                    providerName: (name == null || name.isEmpty) ? 'Provider' : name,
                    providerEmail: email,
                  ),
                );
              }
            }

            final pending = rows.where((r) => r.entry.isPending).length;
            final approved = rows.where((r) => r.entry.isApproved).length;
            final rejected = rows.where((r) => r.entry.isRejected).length;

            var filtered = rows.where((r) {
              switch (_filter) {
                case 'Pending':
                  return r.entry.isPending;
                case 'Rejected':
                  return r.entry.isRejected;
                case 'All':
                  return true;
                default:
                  return r.entry.isApproved;
              }
            }).toList();

            final q = _search.trim().toLowerCase();
            if (q.isNotEmpty) {
              filtered = filtered.where((r) {
                return r.providerName.toLowerCase().contains(q) ||
                    r.providerEmail.toLowerCase().contains(q) ||
                    r.entry.name.toLowerCase().contains(q) ||
                    r.entry.provider.toLowerCase().contains(q) ||
                    r.entry.certificationId.toLowerCase().contains(q);
              }).toList();
            }

            filtered.sort((a, b) {
              final aAt = a.entry.reviewedAt?.millisecondsSinceEpoch ?? 0;
              final bAt = b.entry.reviewedAt?.millisecondsSinceEpoch ?? 0;
              if (aAt != bAt) return bAt.compareTo(aAt);
              return a.providerName.compareTo(b.providerName);
            });

            return AdminPageFrame(
              auth: widget.auth,
              title: 'Certificates',
              subtitle:
                  'View credentials authenticated by the Verification Agency. Approve/reject actions stay with the Agency role.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminMetricGrid(
                    children: [
                      _StatCard(value: '$approved', label: 'Authenticated', color: FigmaColors.green),
                      _StatCard(value: '$pending', label: 'Pending Agency', color: FigmaColors.orange600),
                      _StatCard(value: '$rejected', label: 'Rejected', color: FigmaColors.red600),
                      _StatCard(value: '${rows.length}', label: 'Total submitted', color: FigmaColors.navy),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search by provider, email, certificate name, or ID…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: FigmaColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in const ['Approved', 'Pending', 'Rejected', 'All'])
                        ChoiceChip(
                          label: Text(f == 'Approved' ? 'Authenticated' : f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Results (${filtered.length})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.gray800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: FigmaColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FigmaColors.gray200),
                      ),
                      child: Text(
                        _filter == 'Approved'
                            ? 'No Agency-authenticated certificates yet.'
                            : 'No certificates in this filter.',
                        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                      ),
                    )
                  else
                    for (final row in filtered) ...[
                      _CertCard(row: row),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminCertRow {
  const _AdminCertRow({
    required this.profile,
    required this.entry,
    required this.providerName,
    required this.providerEmail,
  });

  final ServiceProviderProfile profile;
  final ProviderCertificationEntry entry;
  final String providerName;
  final String providerEmail;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
        ],
      ),
    );
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.row});

  final _AdminCertRow row;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    final statusColor = entry.isApproved
        ? FigmaColors.green
        : entry.isRejected
            ? FigmaColors.red600
            : FigmaColors.orange600;
    final statusLabel = entry.isApproved
        ? 'Authenticated'
        : entry.status.firestoreValue;

    String? reviewedLine;
    if (entry.reviewedAt != null || entry.reviewedByRole.isNotEmpty) {
      final parts = <String>[];
      if (entry.reviewedByRole.isNotEmpty) {
        parts.add(entry.reviewedByRole);
      }
      if (entry.reviewedAt != null) {
        parts.add(DateFormat('MMM d, yyyy').format(entry.reviewedAt!.toDate()));
      }
      reviewedLine = parts.join(' · ');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.gray900,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.providerName,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          if (row.providerEmail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              row.providerEmail,
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
            ),
          ],
          if (entry.subtitleLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.subtitleLine, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
          ],
          if (entry.certificationId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ID: ${entry.certificationId}',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
            ),
          ],
          if (entry.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.description,
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.4),
            ),
          ],
          if (entry.url.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.url, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.navy)),
          ],
          if (reviewedLine != null) ...[
            const SizedBox(height: 10),
            Text(
              'Reviewed by $reviewedLine',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray700),
            ),
          ],
          if (entry.isRejected && entry.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${entry.rejectionReason}',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.red600),
            ),
          ],
        ],
      ),
    );
  }
}
