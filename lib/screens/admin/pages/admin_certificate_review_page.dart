import '../../../ui/workflow_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/provider.dart';
import '../../../models/provider_certification.dart';
import '../../../models/app_user.dart';
import '../../../services/firestore_service.dart';
import '../../../services/marketplace_service.dart';
import '../../../services/storage_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_providers_widgets.dart';
import '../widgets/admin_widgets.dart';

const tesdaRegistryUrl = 'https://www.tesda.gov.ph/rwac';

class AdminCertificateReviewPage extends StatefulWidget {
  const AdminCertificateReviewPage({super.key});
  @override
  State<AdminCertificateReviewPage> createState() =>
      _AdminCertificateReviewPageState();
}

class _AdminCertificateReviewPageState
    extends State<AdminCertificateReviewPage> {
  String _filter = 'Pending';
  String _search = '';
  bool _busy = false;
  Future<void> _review(
    ServiceProviderProfile profile,
    ProviderCertificationEntry cert,
    String holder,
  ) async {
    final notes = TextEditingController(text: cert.verificationNotes);
    var checked = false;
    var decision = 'Pending';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => WorkflowDialog(
          title: const Text('System Administrator certificate review'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: WorkflowFields(
                children: [
                  SelectableText(
                    'Holder: $holder\nQualification: ${cert.name}\nCertificate number: ${cert.certificationId}\nIssuer: ${cert.provider}\nValidity: ${cert.issueDate} to ${cert.expirationDate}',
                  ),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(tesdaRegistryUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Check through TESDA'),
                  ),
                  const Text(
                    'Search the official registry and compare the holder, number, qualification and validity. Opening the link does not verify the certificate. A missing result needs follow-up and is not proof of fraud.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    onChanged: (v) => refresh(() => checked = v ?? false),
                    title: const Text(
                      'I checked the official TESDA registry and confirmed that these details match.',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: decision,
                    decoration: const InputDecoration(
                      labelText: 'Review result',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pending',
                        child: Text('Pending further verification'),
                      ),
                      DropdownMenuItem(
                        value: 'Approved',
                        child: Text('Approve'),
                      ),
                      DropdownMenuItem(
                        value: 'Rejected',
                        child: Text('Reject'),
                      ),
                    ],
                    onChanged: (v) => refresh(() => decision = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 3000,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Review notes and registry findings',
                      hintText:
                          'Record what matched, or explain what needs follow-up or why it was rejected.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed:
                  notes.text.trim().length >= 10 &&
                      (decision != 'Approved' || checked)
                  ? () => Navigator.pop(ctx, {
                      'decision': decision,
                      'registryChecked': checked,
                      'notes': notes.text.trim(),
                    })
                  : null,
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('certificateCommand', {
        'providerId': profile.providerId,
        'certificationEntryId': cert.id,
        ...result,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate review saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save review. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPageFrame(
    useDashboardChrome: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminDashboardHeader(
          title: 'Certificate verification',
          subtitle:
              'The System Administrator verifies TESDA certificates separately from ID Analyzer identity checks. PRC licence verification is not supported.',
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<ServiceProviderProfile>>(
          stream: FirestoreService().serviceProvidersStream(),
          builder: (context, profiles) => StreamBuilder<List<AppUser>>(
            stream: FirestoreService().allUsersStream(),
            builder: (context, users) {
              if (profiles.hasError || users.hasError) {
                return const AdminPanelCard(
                  title: '',
                  child: AdminErrorBox(
                    message:
                        'Could not load certificates. Check administrator access and your connection.',
                  ),
                );
              }
              if (!profiles.hasData || !users.hasData) {
                return const AdminPanelCard(
                  title: '',
                  child: AdminLoadingBox(),
                );
              }
              final names = {for (final u in users.data!) u.userId: u.fullName};
              final rows = [
                for (final p in profiles.data!)
                  for (final c in p.effectiveCertificationHistory)
                    (p, c, names[p.userId] ?? 'Provider'),
              ];
              final filtered = rows
                  .where(
                    (r) =>
                        (_filter == 'All' ||
                            r.$2.status.firestoreValue == _filter) &&
                        '${r.$3} ${r.$2.name} ${r.$2.certificationId}'
                            .toLowerCase()
                            .contains(_search.toLowerCase()),
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminPanelCard(
                    title: '',
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdminTableFilterToolbar(
                            search: TextField(
                              decoration: InputDecoration(
                                hintText:
                                    'Search holder, qualification or certificate number',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: FigmaColors.gray500,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: FigmaColors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: FigmaColors.gray300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: FigmaColors.gray300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse(tesdaRegistryUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text(
                                  'Open TESDA Registry of Certified Workers',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final f in [
                                'Pending',
                                'Approved',
                                'Rejected',
                                'All',
                              ])
                                ChoiceChip(
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _filter == f
                                        ? FigmaColors.green
                                        : FigmaColors.gray600,
                                  ),
                                  selectedColor: FigmaColors.tintGreen,
                                  backgroundColor: FigmaColors.white,
                                  side: BorderSide(
                                    color: _filter == f
                                        ? FigmaColors.green
                                        : FigmaColors.gray300,
                                  ),
                                  label: Text(
                                    '$f (${rows.where((r) => f == 'All' || r.$2.status.firestoreValue == f).length})',
                                  ),
                                  selected: _filter == f,
                                  onSelected: (_) =>
                                      setState(() => _filter = f),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (filtered.isEmpty)
                    AdminPanelCard(
                      title: '',
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No certificates in this filter.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: FigmaColors.gray500,
                          ),
                        ),
                      ),
                    ),
                  for (final (p, c, holder) in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AdminPanelCard(
                        title: '',
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    c.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: FigmaColors.gray900,
                                    ),
                                  ),
                                  AdminProviderVerificationChip(
                                    status: c.status.firestoreValue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                holder,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: FigmaColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c.provider} · ${c.certificationId}\n${c.issueDate} to ${c.expirationDate}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: FigmaColors.gray600,
                                  height: 1.5,
                                ),
                              ),
                              if (c.verificationNotes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Review: ${c.verificationNotes}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: FigmaColors.gray700,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              if (c.reviewedAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Reviewed by System Administrator · ${c.reviewedAt!.toDate()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: FigmaColors.gray500,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (c.url.isNotEmpty)
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      label: const Text('View certificate'),
                                      onPressed: () async {
                                        try {
                                          await launchUrl(
                                            Uri.parse(
                                              await StorageService()
                                                  .readableUrl(c.url),
                                            ),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not open certificate.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _review(p, c, holder),
                                    icon: const Icon(Icons.fact_check_outlined),
                                    label: const Text('Review through TESDA'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
