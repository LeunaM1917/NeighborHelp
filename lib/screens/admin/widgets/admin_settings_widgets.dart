import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import 'admin_dashboard_widgets.dart';

class AdminSettingsStatusPill extends StatelessWidget {
  const AdminSettingsStatusPill({
    super.key,
    required this.label,
    this.positive = true,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? FigmaColors.tintGreen : FigmaColors.gray100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: positive ? FigmaColors.green : FigmaColors.gray600,
        ),
      ),
    );
  }
}

class AdminSettingsField {
  const AdminSettingsField({required this.label, required this.value, this.pill});

  final String label;
  final String value;
  final Widget? pill;
}

class AdminSettingsSectionCard extends StatelessWidget {
  const AdminSettingsSectionCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.fields,
    this.trailingAction,
    this.footer,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<AdminSettingsField> fields;
  final Widget? trailingAction;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.4)),
                        ],
                      ),
                    ),
                    if (trailingAction != null) trailingAction!,
                    const Icon(Icons.chevron_right, color: FigmaColors.gray400),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 720 ? 4 : c.maxWidth >= 400 ? 2 : 1;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 16,
                      childAspectRatio: cols == 1 ? 3.2 : 2.4,
                      children: [
                        for (final f in fields)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                f.label,
                                style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              if (f.pill != null)
                                f.pill!
                              else
                                Text(
                                  f.value,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                                ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSettingsInsightsPanel extends StatelessWidget {
  const AdminSettingsInsightsPanel({
    super.key,
    required this.firestoreConnected,
  });

  final bool firestoreConnected;

  @override
  Widget build(BuildContext context) {
    final healthy = firestoreConnected;
    final pct = healthy ? 100.0 : 75.0;

    return AdminPanelCard(
      title: 'Settings Insights',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            SizedBox(
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: pct,
                          color: FigmaColors.green,
                          radius: 40,
                          showTitle: false,
                        ),
                        if (!healthy)
                          PieChartSectionData(
                            value: 100 - pct,
                            color: FigmaColors.gray300,
                            radius: 40,
                            showTitle: false,
                          ),
                      ],
                      sectionsSpace: 0,
                      centerSpaceRadius: 44,
                      startDegreeOffset: -90,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        healthy ? '100%' : '${pct.round()}%',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: FigmaColors.green),
                      ),
                      Text('All good', style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _legend('Secure', healthy, FigmaColors.green),
            _legend('Synced', healthy, FigmaColors.navy),
            _legend('Enabled', healthy, FigmaColors.purple600),
            _legend('Healthy', healthy, FigmaColors.orange600),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, bool ok, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600))),
          Text(ok ? '100%' : '—', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AdminSettingsUpdateItem {
  const AdminSettingsUpdateItem({
    required this.title,
    required this.date,
  });

  final String title;
  final DateTime date;
}

class AdminSettingsRecentUpdates extends StatelessWidget {
  const AdminSettingsRecentUpdates({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<AdminSettingsUpdateItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');

    return AdminPanelCard(
      title: 'Recent updates',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(color: FigmaColors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            dateFmt.format(items[i].date),
                            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all updates', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.green)),
                    const Icon(Icons.chevron_right, size: 18, color: FigmaColors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSettingsQuickActions extends StatelessWidget {
  const AdminSettingsQuickActions({
    super.key,
    this.onManageRoles,
    this.onReviewRules,
    this.onExportConfig,
    this.onViewLogs,
  });

  final VoidCallback? onManageRoles;
  final VoidCallback? onReviewRules;
  final VoidCallback? onExportConfig;
  final VoidCallback? onViewLogs;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Quick actions',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          children: [
            _SettingsActionRow(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Manage roles',
              subtitle: 'Create and manage admin roles',
              onTap: onManageRoles,
            ),
            _SettingsActionRow(
              icon: Icons.rule_folder_outlined,
              title: 'Review rules',
              subtitle: 'View Firestore rules reference',
              onTap: onReviewRules,
            ),
            _SettingsActionRow(
              icon: Icons.file_download_outlined,
              title: 'Export config',
              subtitle: 'Download platform configuration',
              onTap: onExportConfig,
            ),
            _SettingsActionRow(
              icon: Icons.receipt_long_outlined,
              title: 'View logs',
              subtitle: 'Access system and audit logs',
              onTap: onViewLogs,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: FigmaColors.gray100, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 20, color: FigmaColors.gray700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
