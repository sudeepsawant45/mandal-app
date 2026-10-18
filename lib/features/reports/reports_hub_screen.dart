import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/core/theme/app_theme.dart';
import 'package:ganpati_mandal/features/reports/report_button.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// Lists the five independent reports.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    Widget tile(ReportKind kind, Fund fund, String titleKey, String subtitleKey) {
      final color = FundColors.of(fund);
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(FundColors.iconOf(fund), color: color),
          ),
          title: Text(l.t(titleKey)),
          subtitle: Text(l.t(subtitleKey)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openReport(context, kind),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.t('reports'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          tile(ReportKind.household, Fund.householdDonation, 'report_household', 'report_household_desc'),
          tile(ReportKind.commonFund, Fund.commonMandal, 'report_common', 'report_common_desc'),
          tile(ReportKind.visarjanGroup, Fund.visarjan, 'report_visarjan_group', 'report_visarjan_group_desc'),
          tile(ReportKind.visarjanCombined, Fund.visarjan, 'report_visarjan_combined', 'report_visarjan_combined_desc'),
          tile(ReportKind.tshirt, Fund.tshirtSponsorship, 'report_tshirt', 'report_tshirt_desc'),
        ],
      ),
    );
  }
}
