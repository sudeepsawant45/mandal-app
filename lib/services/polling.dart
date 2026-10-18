import 'dart:async';

/// Turns a one-shot API call into a live-ish stream (the app no longer has
/// Firestore listeners). Emits once immediately, then every [every], and
/// again whenever [refreshes] fires (e.g. right after the user saved something).
///
/// - Calls never overlap (a slow request is not stacked up).
/// - If the FIRST load fails the error is delivered to the listener.
/// - If a LATER poll fails, the last good data stays on screen (e.g. a brief
///   network drop must not blank the dashboard).
/// - Polling stops when nobody listens (screen closed / signed out).
Stream<T> pollStream<T>({
  required Future<T> Function() load,
  required Duration every,
  Stream<void>? refreshes,
}) {
  late final StreamController<T> controller;
  Timer? timer;
  StreamSubscription<void>? refreshSub;
  var busy = false;
  var closed = false;
  var hasData = false;
  var rerun = false;

  Future<void> tick() async {
    if (closed) return;
    if (busy) {
      rerun = true; // a request is in flight: run once more when it ends (it may predate a save)
      return;
    }
    busy = true;
    try {
      final value = await load();
      if (!closed) {
        hasData = true;
        controller.add(value);
      }
    } catch (error, stack) {
      if (!closed && !hasData) controller.addError(error, stack);
    } finally {
      busy = false;
      if (rerun && !closed) {
        rerun = false;
        unawaited(tick());
      }
    }
  }

  controller = StreamController<T>(
    onListen: () {
      tick();
      timer = Timer.periodic(every, (_) => tick());
      refreshSub = refreshes?.listen((_) => tick());
    },
    onCancel: () async {
      closed = true;
      timer?.cancel();
      await refreshSub?.cancel();
    },
  );
  return controller.stream;
}
