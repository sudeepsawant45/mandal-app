/// Trimmed text, or null when empty - optional fields are sent and stored as
/// null rather than empty strings.
String? cleanOrNull(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Lower-cased file-name fragment containing only a-z, 0-9 and underscores.
String safeFileFragment(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
