import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../../../services/export_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_widgets.dart';

class AdminActivityPage extends StatefulWidget {
  const AdminActivityPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });
  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;
  @override
  State<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends State<AdminActivityPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) => AdminPageFrame(
    auth: widget.auth,
    useDashboardChrome: true,
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.auth.isLocalAdminOnly
          ? null
          : FirebaseFirestore.instance
                .collection('auditLogs')
                .orderBy('createdAt', descending: true)
                .limit(500)
                .snapshots(),
      builder: (context, snap) {
        final entries = (snap.data?.docs ?? [])
            .where(
              (d) =>
                  '${d.data()['action']} ${d.data()['actorId']} ${d.data()['referenceId']} ${d.data()['collection']}'
                      .toLowerCase()
                      .contains(_search.toLowerCase()),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDashboardHeader(
              title: 'Activity Logs',
              subtitle:
                  'Recorded actions with actor, time and affected record. Showing the latest 500 events.',
              onExport: () => ExportService.exportCollection(
                context,
                'auditLogs',
                rows: entries
                    .map((d) => <String, Object?>{'id': d.id, ...d.data()})
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search actions, user IDs or record IDs',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            if (widget.auth.isLocalAdminOnly)
              const AdminErrorBox(
                message: 'Firebase administrator sign-in is required.',
              )
            else if (snap.hasError)
              const AdminErrorBox(
                message:
                    'Could not load audit records. Check access and connection.',
              )
            else if (!snap.hasData)
              const AdminLoadingBox(message: 'Loading activity?')
            else if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recorded actions match this search. Audit history starts when backend logging is deployed.',
                ),
              ),
            for (final entry in entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.data()['action']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'Actor: ${entry.data()['actorId']} (${entry.data()['actorRole'] ?? 'System'})',
                      ),
                      Text(
                        entry.data()['createdAt'] is Timestamp
                            ? DateFormat('MMM d, yyyy h:mm:ss a').format(
                                (entry.data()['createdAt'] as Timestamp)
                                    .toDate(),
                              )
                            : 'Time unavailable',
                      ),
                      SelectableText(
                        'Record: ${entry.data()['collection']}/${entry.data()['referenceId'] ?? entry.data()['referenceIds'] ?? ''}',
                      ),
                      if (entry.data()['beforeStatus'] != null)
                        Text(
                          'Status: ${entry.data()['beforeStatus']} ? ${entry.data()['afterStatus']}',
                        ),
                      if (entry.data()['changedFields'] != null)
                        Text(
                          'Changed: ${(entry.data()['changedFields'] as List).join(', ')}',
                        ),
                      if (entry.data()['reason'] != null)
                        Text('Reason: ${entry.data()['reason']}'),
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
