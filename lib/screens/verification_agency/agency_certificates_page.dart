import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/provider_certification.dart';
import '../../services/firestore_service.dart';
import '../../theme/adaptive_breakpoints.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../admin/widgets/admin_widgets.dart';

/// Verification Agency queue to authenticate provider-submitted certificates.
class AgencyCertificatesPage extends StatefulWidget {
  const AgencyCertificatesPage({
    super.key,
    required this.reviewerUserId,
  });

  final String reviewerUserId;

  @override
  State<AgencyCertificatesPage> createState() => _AgencyCertificatesPageState();
}

class _AgencyCertificatesPageState extends State<AgencyCertificatesPage> {
  String _filter = 'Pending';
  final _busyKeys = <String>{};

  String _key(String providerId, String certId) => '$providerId::$certId';

  Future<void> _review({
    required ServiceProviderProfile profile,
    required ProviderCertificationEntry entry,
    required bool approve,
  }) async {
    var cert = entry;
    if (cert.id.isEmpty) {
      cert = cert.copyWith(id: ProviderCertificationEntry.newId());
      // Persist id first so review can target it.
      final history = List<ProviderCertificationEntry>.from(profile.effectiveCertificationHistory);
      final idx = history.indexWhere(
        (e) => e.name == entry.name && e.provider == entry.provider && e.issueDate == entry.issueDate,
      );
      if (idx >= 0) {
        history[idx] = cert;
        await FirestoreService().updateServiceProvider(
          providerId: profile.providerId,
          data: {
            'certificationHistory': ProviderCertificationEntry.listToFirestore(history),
            'certifications': history.map((e) => e.displayLine).toList(),
          },
        );
      }
    }

    final key = _key(profile.providerId, cert.id);
    setState(() => _busyKeys.add(key));
    try {
      String reason = '';
      if (!approve) {
        reason = await _askRejectionReason() ?? '';
        if (!mounted) return;
        if (reason.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rejection reason is required')),
          );
          return;
        }
      }
      await FirestoreService().agencyReviewCertification(
        providerId: profile.providerId,
        certificationEntryId: cert.id,
        approve: approve,
        reviewedByUserId: widget.reviewerUserId,
        rejectionReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Certificate authenticated' : 'Certificate rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject certificate'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (shown to the provider)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final pad = MobileLayout.isNativePlatform || AdaptiveBreakpoints.isCompact(context) ? 16.0 : 28.0;

    return StreamBuilder<List<ServiceProviderProfile>>(
      stream: firestore.serviceProvidersStream(),
      builder: (context, providerSnap) {
        return StreamBuilder<List<AppUser>>(
          stream: firestore.allUsersStream(),
          builder: (context, userSnap) {
            if (!providerSnap.hasData || !userSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: LoadingIndicator(message: 'Loading certificates…'),
              );
            }

            final users = {for (final u in userSnap.data!) u.userId: u};
            final rows = <_CertReviewRow>[];
            for (final profile in providerSnap.data!) {
              final name = users[profile.userId]?.fullName.trim();
              for (final cert in profile.effectiveCertificationHistory) {
                rows.add(
                  _CertReviewRow(
                    profile: profile,
                    entry: cert,
                    providerName: (name == null || name.isEmpty) ? 'Provider' : name,
                  ),
                );
              }
            }

            final pending = rows.where((r) => r.entry.isPending).length;
            final approved = rows.where((r) => r.entry.isApproved).length;
            final rejected = rows.where((r) => r.entry.isRejected).length;

            final filtered = rows.where((r) {
              switch (_filter) {
                case 'Approved':
                  return r.entry.isApproved;
                case 'Rejected':
                  return r.entry.isRejected;
                case 'All':
                  return true;
                default:
                  return r.entry.isPending;
              }
            }).toList()
              ..sort((a, b) => a.providerName.compareTo(b.providerName));

            return Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Certificate authentication',
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review licenses and credentials submitted by providers. Authenticate valid certificates before they can publish services.',
                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  AdminMetricGrid(
                    children: [
                      _StatCard(value: '$pending', label: 'Pending', color: FigmaColors.orange600),
                      _StatCard(value: '$approved', label: 'Authenticated', color: FigmaColors.green),
                      _StatCard(value: '$rejected', label: 'Rejected', color: FigmaColors.red600),
                      _StatCard(value: '${rows.length}', label: 'Total submitted', color: FigmaColors.navy),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in const ['Pending', 'Approved', 'Rejected', 'All'])
                        ChoiceChip(
                          label: Text(f == 'Approved' ? 'Authenticated' : f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: FigmaColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FigmaColors.gray200),
                      ),
                      child: Text(
                        _filter == 'Pending'
                            ? 'No certificates waiting for authentication.'
                            : 'No certificates in this filter.',
                        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                      ),
                    )
                  else
                    for (final row in filtered) ...[
                      _CertCard(
                        row: row,
                        busy: _busyKeys.contains(_key(row.profile.providerId, row.entry.id)),
                        onApprove: row.entry.isPending
                            ? () => _review(profile: row.profile, entry: row.entry, approve: true)
                            : null,
                        onReject: row.entry.isPending
                            ? () => _review(profile: row.profile, entry: row.entry, approve: false)
                            : null,
                      ),
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

class _CertReviewRow {
  const _CertReviewRow({
    required this.profile,
    required this.entry,
    required this.providerName,
  });

  final ServiceProviderProfile profile;
  final ProviderCertificationEntry entry;
  final String providerName;
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
  const _CertCard({
    required this.row,
    required this.busy,
    this.onApprove,
    this.onReject,
  });

  final _CertReviewRow row;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final entry = row.entry;
    final statusColor = entry.isApproved
        ? FigmaColors.green
        : entry.isRejected
            ? FigmaColors.red600
            : FigmaColors.orange600;

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
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                ),
              ),
              Text(
                entry.status.firestoreValue == 'Approved' ? 'Authenticated' : entry.status.firestoreValue,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Provider: ${row.providerName}',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700),
          ),
          if (entry.subtitleLine.isNotEmpty) ...[
            const SizedBox(height: 4),
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
            Text(entry.description, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.4)),
          ],
          if (entry.url.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.url, style: GoogleFonts.inter(fontSize: 12, color: rc.primary)),
          ],
          if (entry.isRejected && entry.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${entry.rejectionReason}',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.red600),
            ),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Authenticate'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
