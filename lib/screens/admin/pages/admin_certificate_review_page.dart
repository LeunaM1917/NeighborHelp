import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/provider.dart';
import '../../../models/provider_certification.dart';
import '../../../models/app_user.dart';
import '../../../services/firestore_service.dart';
import '../../../services/marketplace_service.dart';
import '../../../services/storage_service.dart';

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
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('System Administrator certificate review'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<ServiceProviderProfile>>(
    stream: FirestoreService().serviceProvidersStream(),
    builder: (context, profiles) => StreamBuilder<List<AppUser>>(
      stream: FirestoreService().allUsersStream(),
      builder: (context, users) {
        if (profiles.hasError || users.hasError) {
          return const Center(
            child: Text(
              'Could not load certificates. Check administrator access and your connection.',
            ),
          );
        }
        if (!profiles.hasData || !users.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                  (_filter == 'All' || r.$2.status.firestoreValue == _filter) &&
                  '${r.$3} ${r.$2.name} ${r.$2.certificationId}'
                      .toLowerCase()
                      .contains(_search.toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Certificate verification',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'The System Administrator verifies TESDA certificates separately from Didit identity checks. PRC licence verification is not supported.',
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(tesdaRegistryUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open TESDA Registry of Certified Workers'),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search holder, qualification or certificate number',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ['Pending', 'Approved', 'Rejected', 'All'])
                  ChoiceChip(
                    label: Text(
                      '$f (${rows.where((r) => f == 'All' || r.$2.status.firestoreValue == f).length})',
                    ),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No certificates in this filter.'),
              ),
            for (final (p, c, holder) in filtered)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        c.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$holder · ${c.status.firestoreValue}\n${c.provider} · ${c.certificationId}\n${c.issueDate} to ${c.expirationDate}',
                      ),
                      if (c.verificationNotes.isNotEmpty)
                        Text('Review: ${c.verificationNotes}'),
                      if (c.reviewedAt != null)
                        Text(
                          'Reviewed by System Administrator · ${c.reviewedAt!.toDate()}',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (c.url.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('View certificate'),
                              onPressed: () async {
                                try {
                                  await launchUrl(
                                    Uri.parse(
                                      await StorageService().readableUrl(c.url),
                                    ),
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
          ],
        );
      },
    ),
  );
}
