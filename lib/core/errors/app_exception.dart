/// A user-presentable failure. [messageKey] is an L10n key (err_*); [detail]
/// carries a technical hint (error code) that is shown in small print.
///
/// API failures are mapped to these by `ApiClient.mapError`; anything else
/// that is thrown becomes a generic error here.
class AppException implements Exception {
  const AppException(this.messageKey, [this.detail]);

  final String messageKey;
  final String? detail;

  /// Maps any thrown object onto an [AppException].
  static AppException from(Object error) {
    if (error is AppException) return error;
    return AppException('err_generic', error.runtimeType.toString());
  }

  @override
  String toString() => 'AppException($messageKey${detail == null ? '' : ', $detail'})';
}
