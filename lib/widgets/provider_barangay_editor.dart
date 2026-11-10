import '../ui/workflow_ui.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../data/panabo_barangays.dart';

/// No GPS, street address or household pin is collected by this editor.
class ProviderBarangayEditor extends StatelessWidget {
  const ProviderBarangayEditor({
    super.key,
    required this.baseId,
    required this.serviceIds,
    required this.onChanged,
  });
  final String? baseId;
  final Set<String> serviceIds;
  final void Function(String?, Set<String>) onChanged;
  @override
  Widget build(BuildContext context) => WorkflowTheme(
    child: WorkflowFields(
      children: [
        const Text(
          'Barangays in Panabo City',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Customers see an approximate barangay center. Your home address and GPS location are not requested. Distance is an estimate, not a travel route.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          itemHeight: math.max(
            48,
            MediaQuery.textScalerOf(context).scale(16) * 1.5,
          ),
          initialValue: baseId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Base barangay'),
          items: [
            for (final b in panaboBarangays)
              DropdownMenuItem(
                value: b['id'] as String,
                child: Text(
                  b['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: (v) => v == null ? 'Choose your base barangay.' : null,
          onChanged: (v) => onChanged(v, serviceIds),
        ),
        const SizedBox(height: 12),
        FormField<Set<String>>(
          initialValue: serviceIds,
          validator: (_) => serviceIds.isEmpty
              ? 'Choose at least one service barangay.'
              : null,
          builder: (state) => WorkflowFields(
            children: [
              Text('Service barangays (${serviceIds.length} selected)'),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Choose where you accept jobs'),
                onPressed: () async {
                  final result = await showDialog<Set<String>>(
                    context: context,
                    builder: (context) {
                      final chosen = {...serviceIds};
                      return StatefulBuilder(
                        builder: (context, update) => WorkflowDialog(
                          scrollable: true,
                          title: const Text('Service barangays'),
                          content: SizedBox(
                            width: 420,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final b in panaboBarangays)
                                    CheckboxListTile(
                                      title: Text(b['name'] as String),
                                      value: chosen.contains(b['id']),
                                      onChanged: (value) => update(() {
                                        if (value == true) {
                                          chosen.add(b['id'] as String);
                                        } else {
                                          chosen.remove(b['id']);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => Navigator.pop(context, chosen),
                              child: const Text('Use selection'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (result != null) {
                    state.didChange(result);
                    onChanged(baseId, result);
                  }
                },
              ),
              if (state.hasError)
                Text(
                  state.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
