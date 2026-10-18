import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ganpati_mandal/core/l10n/l10n.dart';
import 'package:ganpati_mandal/models/actor.dart';
import 'package:ganpati_mandal/models/app_enums.dart';
import 'package:ganpati_mandal/models/app_user.dart';
import 'package:ganpati_mandal/models/audit_entry.dart';
import 'package:ganpati_mandal/models/household.dart';
import 'package:ganpati_mandal/models/ledger_entry.dart';
import 'package:ganpati_mandal/models/mandal_settings.dart';
import 'package:ganpati_mandal/models/sponsor.dart';
import 'package:ganpati_mandal/models/visarjan_group.dart';
import 'package:ganpati_mandal/services/audit_repository.dart';
import 'package:ganpati_mandal/services/auth_repository.dart';
import 'package:ganpati_mandal/services/household_repository.dart';
import 'package:ganpati_mandal/services/ledger_repository.dart';
import 'package:ganpati_mandal/services/pdf_fonts.dart';
import 'package:ganpati_mandal/services/pdf_report_service.dart';
import 'package:ganpati_mandal/services/api_client.dart';
import 'package:ganpati_mandal/services/report_repository.dart';
import 'package:ganpati_mandal/services/session_controller.dart';
import 'package:ganpati_mandal/services/token_store.dart';
import 'package:ganpati_mandal/services/report_export_service.dart';
import 'package:ganpati_mandal/services/settings_repository.dart';
import 'package:ganpati_mandal/services/sponsor_repository.dart';
import 'package:ganpati_mandal/services/user_repository.dart';
import 'package:ganpati_mandal/services/visarjan_repository.dart';

// ----------------------------------------------------------- infrastructure
// The app has NO Firebase and NO direct database access: everything below talks
// to the Node.js API through [ApiClient] with the session's Bearer token.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // The server rejected the session (expired, revoked, user deactivated).
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  ),
);

final sessionProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider))..restore(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.read(sessionProvider.notifier)),
);

// Repositories are rebuilt whenever the signed-in user changes, so one user's
// cached data is never shown to the next.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  ref.watch(sessionUidProvider);
  return UserRepository(ref.watch(apiClientProvider));
});
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  ref.watch(sessionUidProvider);
  return SettingsRepository(ref.watch(apiClientProvider));
});
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  ref.watch(sessionUidProvider);
  return HouseholdRepository(ref.watch(apiClientProvider));
});
final visarjanRepositoryProvider = Provider<VisarjanRepository>((ref) {
  ref.watch(sessionUidProvider);
  return VisarjanRepository(ref.watch(apiClientProvider));
});
final sponsorRepositoryProvider = Provider<SponsorRepository>((ref) {
  ref.watch(sessionUidProvider);
  return SponsorRepository(ref.watch(apiClientProvider));
});
final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  ref.watch(sessionUidProvider);
  return LedgerRepository(ref.watch(apiClientProvider));
});
final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  ref.watch(sessionUidProvider);
  return AuditRepository(ref.watch(apiClientProvider));
});
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  ref.watch(sessionUidProvider);
  return ReportRepository(ref.watch(apiClientProvider));
});

final pdfServiceProvider = Provider<PdfReportService>((ref) => const PdfReportService());
final exportServiceProvider =
    Provider<ReportExportService>((ref) => const ReportExportService());
final pdfFontsProvider = FutureProvider<PdfFonts>((ref) => PdfFonts.loadFromAssets());

// ------------------------------------------------------------------ language
/// 'mr' (Marathi, default) or 'en'. Kept in memory only.
final languageProvider = StateProvider<String>((ref) => 'mr');
final l10nProvider = Provider<L10n>((ref) => L10n(ref.watch(languageProvider)));

// ---------------------------------------------------------------------- auth
/// Id of the signed-in member (null when signed out / still restoring).
final sessionUidProvider =
    Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.user?.uid)));

/// The signed-in member as last reported by the server (null otherwise).
final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(sessionProvider.select((s) => s.user)));

/// The signed-in, approved user. The server only issues sessions to approved,
/// active members, so a signed-in user is always approved.
final actorProvider = Provider<Actor?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isApproved) return null;
  return Actor(uid: user.uid, name: user.label, role: user.role);
});

final roleProvider =
    Provider<AppRole>((ref) => ref.watch(actorProvider)?.role ?? AppRole.pending);

// ---------------------------------------------------------------- navigation
final homeTabProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------- data
// All data streams are autoDispose polls keyed on the session uid, so signing
// out stops them and a different user never sees a previous user's cached state.
final settingsProvider = StreamProvider.autoDispose<MandalSettings>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(settingsRepositoryProvider).watch();
});

final householdsProvider = StreamProvider.autoDispose<List<Household>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(householdRepositoryProvider).watchAll();
});

final visarjanGroupsProvider = StreamProvider.autoDispose<List<VisarjanGroup>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(visarjanRepositoryProvider).watchAll();
});

final sponsorsProvider = StreamProvider.autoDispose<List<Sponsor>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(sponsorRepositoryProvider).watchAll();
});

/// Every transaction of every fund (including soft-deleted ones).
final allEntriesProvider = StreamProvider.autoDispose<List<LedgerEntry>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(ledgerRepositoryProvider).watchAll();
});

final usersProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(userRepositoryProvider).watchAll();
});

final auditProvider = StreamProvider.autoDispose<List<AuditEntry>>((ref) {
  ref.watch(sessionUidProvider);
  return ref.watch(auditRepositoryProvider).watchRecent();
});
