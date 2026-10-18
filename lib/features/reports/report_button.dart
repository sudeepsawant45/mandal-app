import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/providers/app_providers.dart';
import 'package:ganpati_mandal/features/reports/report_screen.dart';
import 'package:ganpati_mandal/models/app_enums.dart';

/// Opens the report screen of one section (app-bar action).
class ReportButton extends ConsumerWidget {
  const ReportButton({super.key, required this.kind, this.groupId});

  final ReportKind kind;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return IconButton(
      tooltip: l.t('reports'),
      icon: const Icon(Icons.picture_as_pdf_outlined),
      onPressed: () => openReport(context, kind, groupId: groupId),
    );
  }
}

Future<void> openReport(BuildContext context, ReportKind kind, {String? groupId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ReportScreen(kind: kind, groupId: groupId)),
  );
}
