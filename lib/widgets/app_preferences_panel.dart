import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/crash_reporting.dart';

class AppPreferencesPanel extends StatefulWidget {
  const AppPreferencesPanel({super.key});
  @override
  State<AppPreferencesPanel> createState() => _AppPreferencesPanelState();
}

class _AppPreferencesPanelState extends State<AppPreferencesPanel> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('Language'))),
              const LanguageMenuButton(),
            ],
          ),
          if (CrashReporting.available)
            ValueListenableBuilder<bool>(
              valueListenable: CrashReporting.consent,
              builder: (context, allowed, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Share crash diagnostics from this device')),
                subtitle: Text(context.tr(
                  'Optional device and crash information helps investigate failures. App reports omit raw error messages, chats, addresses, certificate images and payment references. You can turn this off anytime.',
                )),
                value: allowed,
                onChanged: _busy
                    ? null
                    : (value) async {
                        setState(() => _busy = true);
                        try {
                          await CrashReporting.setConsent(value);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not change diagnostics preference. Retry.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ),
        ],
      ),
    ),
  );
}
