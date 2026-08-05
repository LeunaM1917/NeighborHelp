import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/provider_weekly_availability.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Weekly availability editor — matches Availability reference layout.
class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({
    super.key,
    required this.appUser,
    this.inDialog = false,
  });

  final AppUser appUser;
  final bool inDialog;

  static Future<bool?> open(BuildContext context, {required AppUser appUser}) {
    final inDialog = !MobileLayout.useMobileChrome(context);
    final body = ProviderAvailabilityScreen(appUser: appUser, inDialog: inDialog);

    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            Scaffold(
              backgroundColor: FigmaColors.gray50,
              body: SafeArea(child: body),
            ),
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 900),
            child: Material(
              color: FigmaColors.gray50,
              elevation: 8,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: FigmaColors.gray200),
              ),
              clipBehavior: Clip.antiAlias,
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderAvailabilityScreen> createState() => _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState extends State<ProviderAvailabilityScreen> {
  late ProviderWeeklyAvailability _schedule;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schedule = ProviderWeeklyAvailability.defaults;
    _load();
  }

  Future<void> _load() async {
    final data = await FirestoreService().providerAvailability(widget.appUser.userId);
    if (mounted) {
      setState(() {
        _schedule = ProviderWeeklyAvailability.fromFirestore(data);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService().updateProviderAvailability(
        providerId: widget.appUser.userId,
        weeklyAvailability: _schedule.toFirestore(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save availability.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyWeekdaysFromMonday() {
    final mon = _schedule.scheduleFor('Monday');
    setState(() {
      var next = _schedule;
      for (final day in ProviderWeeklyAvailability.weekdayNames.skip(1)) {
        next = next.updateDay(day, mon);
      }
      _schedule = next;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied Monday hours to Tue–Fri')),
    );
  }

  double _sidePadding(BuildContext context) =>
      widget.inDialog ? 28 : (MobileLayout.useMobileChrome(context) ? 20 : 28);

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final side = _sidePadding(context);

    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.inDialog ? 12 : 8, widget.inDialog ? 16 : 8, side, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(widget.inDialog ? Icons.close_rounded : Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: FigmaColors.white,
                      foregroundColor: FigmaColors.gray800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Availability',
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let customers see when you\'re available for bookings.',
                          style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: side),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: rc.tint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rc.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: rc.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These hours will be visible to customers when they book your service.',
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppScrollChrome(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          0,
                          side,
                          MobileLayout.pageBottomPadding(context),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: FigmaColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: FigmaColors.gray200, width: 1),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < ProviderWeeklyAvailability.dayOrder.length; i++) ...[
                                if (i > 0) const Divider(height: 1, color: FigmaColors.gray100),
                                _DayRow(
                                  day: ProviderWeeklyAvailability.dayOrder[i],
                                  schedule: _schedule.scheduleFor(ProviderWeeklyAvailability.dayOrder[i]),
                                  onChanged: (s) => setState(() {
                                    _schedule = _schedule.updateDay(ProviderWeeklyAvailability.dayOrder[i], s);
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 12, side, widget.inDialog ? 20 : 16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final stack = c.maxWidth < 480;
                  final applyBtn = OutlinedButton.icon(
                    onPressed: _saving ? null : _applyWeekdaysFromMonday,
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: Text('Apply to all weekdays', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FigmaColors.gray800,
                      side: const BorderSide(color: FigmaColors.gray300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  final saveBtn = FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text('Save availability', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: rc.primary,
                      foregroundColor: FigmaColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [applyBtn, const SizedBox(height: 10), saveBtn],
                    );
                  }
                  return Row(
                    children: [
                      applyBtn,
                      const SizedBox(width: 12),
                      Expanded(child: saveBtn),
                    ],
                  );
                },
              ),
            ),
          ],
        );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.schedule,
    required this.onChanged,
  });

  final String day;
  final ProviderDaySchedule schedule;
  final ValueChanged<ProviderDaySchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final enabled = schedule.enabled;
    final slots = ProviderWeeklyAvailability.timeSlotOptions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 520;
          final dayCol = Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rc.tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_available_outlined, size: 18, color: rc.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                    Text(
                      enabled ? 'Available' : 'Unavailable',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: enabled ? rc.primary : FigmaColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final times = enabled
              ? Row(
                  children: [
                    Expanded(child: _TimeDropdown(label: 'Start', value: schedule.start, options: slots, onChanged: (v) => onChanged(schedule.copyWith(start: v)))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray400)),
                    ),
                    Expanded(child: _TimeDropdown(label: 'End', value: schedule.end, options: slots, onChanged: (v) => onChanged(schedule.copyWith(end: v)))),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _DisabledTimeBox(label: 'Start')),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—', style: TextStyle(color: FigmaColors.gray300)),
                    ),
                    Expanded(child: _DisabledTimeBox(label: 'End')),
                  ],
                );

          final toggle = Switch(
            value: enabled,
            onChanged: (v) => onChanged(schedule.copyWith(enabled: v)),
            activeTrackColor: rc.primary.withValues(alpha: 0.5),
            activeThumbColor: rc.primary,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: dayCol), toggle]),
                const SizedBox(height: 12),
                times,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 150, child: dayCol),
              Expanded(child: times),
              toggle,
            ],
          );
        },
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : options.first;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
        prefixIcon: const Icon(Icons.schedule_outlined, size: 18, color: FigmaColors.gray500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FigmaColors.gray300),
        ),
      ),
      items: options.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 13)))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _DisabledTimeBox extends StatelessWidget {
  const _DisabledTimeBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray400),
        enabled: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FigmaColors.gray200),
        ),
        filled: true,
        fillColor: FigmaColors.gray50,
      ),
      child: Text('', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray400)),
    );
  }
}
